import 'dart:io';
import 'dart:math';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as path;
import 'package:tus_client_background_demo/model/DirectoryUploadStore.dart';
import 'package:http/http.dart' as http;
import 'package:speed_test_dart/classes/server.dart';
import 'package:tus_client_dart/tus_client_dart.dart';

class DirectoryUploadClient{

  DirectoryUploadClient(
      this.directory, {
        required this.store,
        this.maxChunkSize = 512 * 1024,
        this.retries = 0,
        this.retryScale = RetryScale.constant,
        this.retryInterval = 0,
      }) {
    _fingerprint = generateFingerprint() ?? "";
  }

  Future<void> dispose() async {
    await cancelUpload();
  }

  Future<void> upload({
    Function(TusClient, Duration?)? onStart,
    Function(double, Duration)? onProgress,
    Function()? onComplete,
    required Uri uri,
    Map<String, String>? metadata = const {},
    Map<String, String>? headers = const {},
    bool measureUploadSpeed = false,
  }) async {
    // reading directory
    await upsertUploadUrl();

    // fetch upload progress
    await fetchUploadProgress();

    // creating tus clients
    await createTusClients();

    // upload
    setUploadData(uri, headers, metadata);

    final directoryUploadFutures = _tusClientList.map((tusClient) async {
      Map<String, String> localMetadata = {};
      if(metadata != null)
        localMetadata.addAll(metadata);

      String relativePath = './' + path.relative(tusClient.file.path, from: directory.path);
      localMetadata['device_relative_path'] = relativePath;

      tusClient.upload(
        uri: uri,
        metadata: localMetadata,
        headers: headers,
        measureUploadSpeed: measureUploadSpeed,
        onStart: (client, estimate) {
          onStart?.call(client, estimate);
        },
        onProgress: (individualProgressPercentage, estimate) {
          final filePath = tusClient.file.path;
          updateUploadProgress(filePath)(individualProgressPercentage);
          final totalProgressPercentage = getTotalUploadProgressPercentage();
          final maxEstimation = measureUploadSpeed ? Duration(seconds: getMaxEstimationSecond()) : Duration(seconds: maxInt);
          onProgress?.call(totalProgressPercentage, maxEstimation);
        },
        onComplete: () {
          _tusClientList.remove(tusClient);
          onComplete?.call();
        }
      );
    }).toList();

    await Future.wait(directoryUploadFutures);

    if(await getTotalUploadProgress() == _totalDirectorySize)
      await onCompleteUpload();
  }


  Future<bool> pauseUpload() async {
    try {
      final pauseUploadFutures = _tusClientList.map((client) async => client.pauseUpload()).toList();
      await Future.wait(pauseUploadFutures);
      return true;
    } catch (e) {
      throw Exception("Error pausing upload: $e");
    }
  }

  Future<bool> cancelUpload() async {
    try {
      await pauseUpload();
      await store.remove(_fingerprint);
    return true;
    } catch (_) {
    throw Exception("Error cancelling upload");
    }
  }
  
  Future<void> onCompleteUpload() async {
    await store.remove(_fingerprint);
  }

  // Methods for set/get up upload metadata

  Function(double) updateUploadProgress(String filepath) {
    return (double progressPercentage) {
      double progressRatio = progressPercentage / 100;
      _progressRatio[filepath] = progressRatio;
      // Note: I use round() here to avoid floating point error
      final fileSize = _fileSize[filepath]!;
      _progress[filepath] = max((progressRatio * fileSize).round(), fileSize);
    };
  }

  void setUploadData(
      Uri url,
      Map<String, String>? headers,
      Map<String, String>? metadata,
      ) {
    this.url = url;
    this.headers = headers;
    this.metadata = metadata;
  }

  int? _parseOffset(String? offset) {
    if (offset == null || offset.isEmpty) {
      return null;
    }
    if (offset.contains(",")) {
      offset = offset.substring(0, offset.indexOf(","));
    }
    return int.tryParse(offset);
  }

  // Methods for setting up tus clients

  Future<void> createTusClients() async {
    try {
      final uploads = await getOngoingUploadsMap();

      final tusClients = uploads.entries.map((entry) {
        return new TusClient(
          XFile(entry.key),
          store: TusFileStore(directory),
          maxChunkSize: maxChunkSize,
          retries: retries,
          retryScale: retryScale,
          retryInterval: retryInterval,
        );
      }).toList();

      _tusClientList = tusClients;
    } catch (e) {
      // TODO: implement error handling
      throw e;
    }
  }

  Future<Map<String, Uri>> getOngoingUploadsMap() async {
    final uploadUrlMaps = await store.get(_fingerprint);

    Map<String, Uri> filteredMap = {};
    filteredMap.addAll(uploadUrlMaps);

    filteredMap.removeWhere((filePath, _) => _progress[filePath]! >= _fileSize[filePath]!);

    return filteredMap;
  }


  // Methods for reading upload progress from server

  Future<Map<String, int>> fetchUploadProgress() async {
    final uploadUrlMaps = await store.get(_fingerprint);
    final keys = uploadUrlMaps.keys.toList();
    Map<String, int> estimateUploadMap = {};
    Map<String, int> uploadProgressMap = {};
    Map<String, int> fileSizeMap = {};
    Map<String, double> uploadProgressRatioMap = {};

    final uploadProgressFuture = keys.map((url) async {
      final progress = await fetchIndividualUploadProgress(url);
      return MapEntry(url, progress);
    }).toList();

    final uploadProgress = await Future.wait(uploadProgressFuture);

    for (final entry in uploadProgress) {
      final key = entry.key;
      final value = entry.value;

      uploadProgressMap[key] = value;
      fileSizeMap[key] = await XFile(key).length();
      uploadProgressRatioMap[key] = uploadProgressMap[key]! / fileSizeMap[key]!;
      estimateUploadMap[key] = maxInt;
    }

    _estimateUploadProgressSecond = estimateUploadMap;
    _progress = uploadProgressMap;
    _fileSize = fileSizeMap;
    _progressRatio = uploadProgressRatioMap;
    _totalDirectorySize = fileSizeMap.values.reduce((sum, size) => sum + size);
    return uploadProgressMap;
  }

  Future<int> fetchIndividualUploadProgress(filePath) async {
    final uploadUrl = (await store.get(_fingerprint))[filePath];
    final client = http.Client();

    final offsetHeaders = {"Tus-Resumable": tusVersion};
    final response = await client.head(uploadUrl as Uri, headers: offsetHeaders);

    if (!(response.statusCode >= 200 && response.statusCode < 300)) {
      throw ProtocolException(
        "Unexpected error while resuming upload",
        response.statusCode,
      );
    }

    client.close();

    int? serverOffset = _parseOffset(response.headers["upload-offset"]);
    if (serverOffset == null) {
      throw ProtocolException(
          "missing upload offset in response for resuming upload");
    }

    return serverOffset;
  }

  double getTotalUploadProgressPercentage() {
    final progressValues = _progress.values;

    if (progressValues.isEmpty) {
      return 1;
    }

    final totalProgress = progressValues.fold<int>(0, (sum, value) => sum + value);

    return (totalProgress / _totalDirectorySize!) * 100;
  }

  int getMaxEstimationSecond() {
    if(_estimateUploadProgressSecond.isEmpty) {
      return 0;
    }

    return _estimateUploadProgressSecond.values.reduce(max);
  }

  Future<int> getTotalUploadProgress() async {
    return _progress.values.reduce((sum, size) => sum + size);
  }

  // Methods for reading directory

  Future<Map<String, Uri>> upsertUploadUrl() async {
    try {
      final uploadUrlMaps = await store.get(_fingerprint);
      final existingFileUploadsPath = uploadUrlMaps.keys.toSet();

      _uploadFilesPath = await getAllFileInDirectory(directory.path);

      final fileSizeFutures = _uploadFilesPath.map((filePath) async {
        final file = File(filePath);
        return await file.length();
      }).toList();

      // Create new upload for new files
      final createUploadFutures = _uploadFilesPath
          .where((filePath) => !existingFileUploadsPath.contains(filePath))
          .map((filePath) async {
        final tusClient = TusClient(XFile(filePath), store: TusFileStore(directory));
        await tusClient.createUpload();
        return {filePath: tusClient.uploadUrl!};
      }).toList();

      final newUploadUrlMapsList = await Future.wait(createUploadFutures);

      for (Map<String, Uri> map in newUploadUrlMapsList) {
        uploadUrlMaps.addAll(map);
      }

      final fileSizeList = await Future.wait(fileSizeFutures);
      _totalDirectorySize = fileSizeList.fold<int>(0, (sum, size) => sum + size);

      store.set(_fingerprint, uploadUrlMaps);
      return uploadUrlMaps;

    } catch(e) {
      // TODO: implement error handling
      throw(e);
    }
  }

  Future<Set<String>> getAllFileInDirectory(String directoryPath, {bool followLinks = false}) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw Exception('Directory does not exist');
    }

    Set<String> filePaths = {};

    await for (FileSystemEntity entity in directory.list(recursive: true, followLinks: followLinks)) {
      if (entity is File) {
        filePaths.add(entity.path);
      }
    }

    return filePaths;
  }


  // Miscellaneous methods

  String? generateFingerprint() {
    return directory.path.replaceAll(RegExp(r"\W+"), '.');
  }


  // file upload data

  final tusVersion = "1.0.0";
  Uri? url;
  Map<String, String>? metadata;
  Map<String, String>? headers;
  double? uploadSpeed;
  List<Server>? bestServers;

  int maxChunkSize;
  int retries;
  RetryScale retryScale;
  int retryInterval;


  // object data

  DirectoryUploadStoreI store;

  Directory directory;

  List<TusClient> _tusClientList = [];

  Map<String, double> _progressRatio = {};
  Map<String, int> _progress = {};
  Map<String, int> _fileSize = {};
  Map<String, int> _estimateUploadProgressSecond = {};

  int? _totalDirectorySize;

  String _fingerprint = "";

  String? _uploadMetadata;

  Set<String> _uploadFilesPath = {};

  static const int maxInt = 0x7FFFFFFFFFFFFFFF;

  // object data getters

  /// The URI on the server for the file
  Set<String> get uploadFilesPath => _uploadFilesPath;

  /// The fingerprint of the file being uploaded
  String get fingerprint => _fingerprint;

  /// The 'Upload-Metadata' header sent to server
  String get uploadMetadata => _uploadMetadata ?? "";

  /// Get the total upload size
  String get totalDirectorySize => totalDirectorySize;

}