import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cross_file/cross_file.dart';
import 'package:tus_client_background_demo/model/NotificationManager.dart';
import 'package:tus_client_dart/tus_client_dart.dart';
import 'package:workmanager/workmanager.dart';

class FileUploadManager {
  bool _isInitialized = false;

  late final String _tusdServerUrl;
  late final Directory _tusStoreDirectory;
  late final UploadContext _context;

  FileUploadManager._privateConstructor();

  static final FileUploadManager _instance = FileUploadManager._privateConstructor();

  factory FileUploadManager() {
    return _instance;
  }

  // NOTE: THIS CLASS MUST BE INITIALIZED AFTER NOTIFICATION MANAGER
  Future<bool> initialize(UploadContext context) async {
    if (_isInitialized) {
      return false;
    }

    _context = context;
    _tusdServerUrl = context.tusdServerUrl;
    _tusStoreDirectory = context.tusStoreDirectory;
    print("INITIALIZING FILE UPLOAD MANAGER");
    print("_tusdServerUrl: $_tusdServerUrl");
    print("_tusStoreDirectory: $_tusStoreDirectory");

    bool notificationsInitialized = await NotificationManager().initialize(context);
    await _initializeWorkmanager();

    _isInitialized = notificationsInitialized;
    return notificationsInitialized;
  }

  Future<void> uploadFile(String filePath) async {
    Map<String, dynamic> contextStr = _context.getAsMap();
    contextStr['file_path'] = filePath;
    // inputData['chunk_size'] = (512 * 1024 * 2);

    Workmanager().registerOneOffTask(getTaskUniqueName(filePath),'_',
        constraints: Constraints(networkType: NetworkType.connected),
        inputData: contextStr,
        existingWorkPolicy: ExistingWorkPolicy.keep);
  }

  // Future<void> cancelUpload(String filePath) async {
  //   Workmanager().cancelByUniqueName(getTaskUniqueName(filePath));
  // }

  Future<void> pauseUpload(String filePath) async {
    Workmanager().cancelByUniqueName(getTaskUniqueName(filePath));
    NotificationManager().removeNotificationIdFor(filePath);
  }

  Future<void> _initializeWorkmanager() async {
    print("INITIALIZING WORK MANAGER");
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
  }

  String getTaskUniqueName(String str) {
    return str.replaceAll(RegExp(r"\W+"), '.');
  }

  UploadContext getContext() {
    return _context;
  }
}

dynamic Function(double, Duration) throttle(dynamic Function(double, Duration) callback, Duration duration) {
  DateTime lastExecution = DateTime.fromMillisecondsSinceEpoch(0);
  return (double progress, Duration estimate) {
    var now = DateTime.now();
    if (now.difference(lastExecution) >= duration) {
      lastExecution = now;
      callback(progress, estimate);
    }
  };
}

@pragma('vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final UploadContext context = UploadContext.getAsContext(inputData!);
    final NotificationManager nm = NotificationManager();

    final filePath = inputData['file_path']!;
    final chunkSize = inputData['chunk_size'] ?? (512 * 1024 * 2); // 1024 kB by default

    print("CONSTRUCTING XFILE");
    final file = XFile(filePath);

    print("CONSTRUCTING TUSD STORAGE DIRECTORY");
    final tempDirectory = Directory(
        '${context.tusStoreDirectory.path}/${file.name}_uploads');
    if (!tempDirectory.existsSync()) {
      print("CREATING NEW DIRECTORY FOR ${tempDirectory.path}");
      tempDirectory.createSync(recursive: true);
    }

    print("CONSTRUCTING TusClient");
    final client = TusClient(
      file,
      store: TusFileStore(tempDirectory),
      maxChunkSize: chunkSize,
    );

    print("Starting upload");
    await client.upload(
      onStart: (client,estimate) => nm.updateProgressBarFor(filePath, 0, context),

      onProgress: throttle((progress, _) {
        nm.updateProgressBarFor(filePath, progress, context);
      }, const Duration(seconds: 1)), // Ensure that the progressBar won't be called more than once per second.

      onComplete: () async {
        print("Completed!");
        nm.removeNotificationIdFor(filePath);
        tempDirectory.deleteSync(recursive: true);
        // setState(() => _fileUrl = _client.uploadUrl);
      },

      uri: Uri.parse(context.tusdServerUrl),
      metadata: {
        'testMetaData': 'testMetaData',
        'testMetaData2': 'testMetaData2',
      },
      headers: {
        'testHeaders': 'testHeaders',
        'testHeaders2': 'testHeaders2',
      },
      measureUploadSpeed: false,
    );
    return Future.value(true);
  });
}

class ImmutableFileUploadManagerContext {
  final String tusdServerUrl;
  final Directory tusStoreDirectory;
  final String notificationChannelKey;
  late final String notificationChannelKeySilent;
  late final String notificationChannelKeyAudible;
  final String notificationChannelGroupKey;
  final String? notificationChannelName;
  final String? notificationChannelGroupName;
  final String? notificationChannelDescription;
  final String? notificationSoundSource;
  final Color? notificationDefaultColor;
  final Int64List? notificationVibrationPattern;

  ImmutableFileUploadManagerContext({
    required this.tusdServerUrl,
    required this.tusStoreDirectory,
    required this.notificationChannelKey,
    required this.notificationChannelGroupKey,
    String? this.notificationChannelName,
    String? this.notificationChannelGroupName,
    String? this.notificationChannelDescription,
    String? this.notificationSoundSource,
    Color? this.notificationDefaultColor,
    Int64List? this.notificationVibrationPattern,
  }) {
    notificationChannelKeySilent = notificationChannelKey + '-silent';
    notificationChannelKeyAudible = notificationChannelKey + '-audible';
  }

  Map<String, dynamic> getAsMap() {
    Map<String,dynamic> map = {
      'tusd_server_url': tusdServerUrl,
      'tus_store_directory': tusStoreDirectory.path,
      'notification_channel_key': notificationChannelKey,
      'notification_channel_group_key': notificationChannelGroupKey,
      'notification_channel_name': notificationChannelName,
      'notification_channel_group_name': notificationChannelGroupName,
      'notification_channel_description': notificationChannelDescription,
      'notification_sound_source': notificationSoundSource,
      'notification_default_color': notificationDefaultColor?.value,
      'notification_vibration_pattern': notificationVibrationPattern?.toList(),
    };

    // Remove keys with null values
    map.removeWhere((key, value) => value == null);
    return map;
  }

  static ImmutableFileUploadManagerContext getAsContext(Map<String, dynamic> input) {
    return new ImmutableFileUploadManagerContext(
      tusdServerUrl: input['tusd_server_url']!,
      tusStoreDirectory: Directory(input['tus_store_directory']!),
      notificationChannelKey: input['notification_channel_key']!,
      notificationChannelGroupKey: input['notification_channel_group_key']!,
      notificationChannelName: input['notification_channel_name'],
      notificationChannelGroupName: input['notification_channel_group_name'],
      notificationChannelDescription: input['notification_channel_description'],
      notificationSoundSource: input['notification_sound_source'],
      notificationDefaultColor: input['notification_default_color'] != null ? Color(input['notification_default_color']) : null,
      notificationVibrationPattern: input['notification_vibration_pattern'] != null ? Int64List.fromList(List<int>.from(input['notification_vibration_pattern'])) : null,
    );
  }
}

typedef UploadContext = ImmutableFileUploadManagerContext;
