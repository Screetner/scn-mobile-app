import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tus_client_dart/tus_client_dart.dart';
import 'package:workmanager/workmanager.dart';

class FileUploadManager {
  bool _isInitialized = false;
  String? _tusdServerUrl;
  String? _notificationChannelKey;
  String? _notificationChannelGroupKey;
  String? _notificationChannelName;
  Directory? _tusStoreDirectory;

  final Map<String, int> _notificationIdMap = {};

  // This is a singleton class.

  FileUploadManager._privateConstructor();

  static final FileUploadManager _instance = FileUploadManager._privateConstructor();

  factory FileUploadManager() {
    return _instance;
  }

  Future<bool> initialize({
    required String tusdServerUrl,
    required String notificationChannelKey,
    required String notificationChannelGroupKey,
    Directory? tusStoreDirectory,
    String? notificationChannelName
  }) async {
    if(_isInitialized) {
      return false;
    }

    print("INITIALIZING FILE UPLOAD MANAGER");

    _tusdServerUrl = tusdServerUrl;
    _notificationChannelKey = notificationChannelKey;
    _notificationChannelGroupKey = notificationChannelGroupKey;
    _tusStoreDirectory = tusStoreDirectory ?? await getApplicationDocumentsDirectory();
    _notificationChannelName = notificationChannelName ?? notificationChannelKey;

    bool notificationsInitialized = await _initializeAwesomeNotifications();
    _isInitialized = notificationsInitialized;
    await _initializeWorkManager();
    return notificationsInitialized;
  }

  Future<void> uploadFile(String filePath) async {
    print("SETTING WORK MANAGER");
    print("FILE PATH: $filePath");
    print("TUS STORE DIRECTORY: ${_tusStoreDirectory!.path}");
    print("TUSD URL: $_tusdServerUrl");
    print("NOTIFICATION CHANNEL KEY: $_notificationChannelKey");
    print("TASK UNIQUE NAME: ${getTaskUniqueName(filePath)}");
    Workmanager().registerOneOffTask(getTaskUniqueName(filePath),'_',
        constraints: Constraints(networkType: NetworkType.connected),
        inputData: <String, dynamic> {
          'file_path': filePath,
          'tus_store_directory': _tusStoreDirectory!.path,
          'tusd_url': _tusdServerUrl,
          'notification_channel_key': _notificationChannelKey,
          'notification_group_key': _notificationChannelGroupKey
        },
        existingWorkPolicy: ExistingWorkPolicy.keep);
  }

  Future<void> _initializeWorkManager() async {
    print("INITIALIZING WORK MANAGER");
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
  }

  Future<bool> _initializeAwesomeNotifications() {
    print("INITIALIZING AWESOME NOTIFICATIONS");
    return AwesomeNotifications().initialize(
      null, // default icon
      [
        NotificationChannel(
          channelGroupKey: _notificationChannelGroupKey,
          channelKey: _notificationChannelKey,
          channelName: _notificationChannelName ?? _notificationChannelKey,
          channelDescription:
          'Notification channel that show uploading files.',
          defaultColor: const Color(0xFF9D50DD),
          ledColor: Colors.white,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: _notificationChannelGroupKey!,
          channelGroupName: 'File Upload Group',
        ),
      ],
    );
  }

  // credits to awesome-notification documentation
  // link: https://awesome-notification-docs.vercel.app/
  void _updateCurrentProgressBar({
    required int id,
    required double progressPercentage,
    required String notificationChannelKey,
    String? notificationGroupKey,
    String? fileName
  }) {
    const double maxPercentage = 100;
    print("UPDATE PROGRESS BAR");
    print("PROGRESS PERCENTAGE: $progressPercentage");
    if (progressPercentage < maxPercentage) {
      double progress = min(progressPercentage, maxPercentage);
      int progressInt = progress.toInt();
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: notificationChannelKey,
          title: 'Uploading ${fileName ?? "file"} $progressInt%',
          // body: 'filename.txt',
          category: NotificationCategory.Progress,
          // payload: {
          //   'file': 'filename.txt',
          //   'path': '-rmdir c://ruwindows/system32/huehuehue'
          // },
          notificationLayout: NotificationLayout.ProgressBar,
          progress: progress,
          locked: true,
        ),
      );
    } else {
      print("CREATING ALERT NOTIFICATION");
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: notificationChannelKey,
          groupKey: notificationGroupKey,
          title: 'Upload ${fileName ?? "file"} finished',
          // body: 'filename.txt',
          category: NotificationCategory.Progress,
          // payload: {
          //   'file': 'filename.txt',
          //   'path': '-rmdir c://ruwindows/system32/huehuehue'
          // },
          locked: false,
        ),
      );
    }
  }

  String getTaskUniqueName(String str) {
    return str.replaceAll(RegExp(r"\W+"), '.');
  }

  int getNotificationIdFor(String key) {
    if (_notificationIdMap.containsKey(key)) {
      return _notificationIdMap[key]!;
    }

    int hashCode = key.hashCode;
    while(_notificationIdMap.containsValue(hashCode)) { hashCode++; }
    _notificationIdMap[key] = hashCode;

    return hashCode;
  }

  int? removeNotificationIdFor(String key) {
    return _notificationIdMap.remove(key);
  }

  // Throttles updates to ensure the progress notification is not updated more frequently than the input duration.
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
}

@pragma('vm:entry-point') // Mandatory if the App is obfuscated or using Flutter 3.1+
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final FileUploadManager fum = FileUploadManager();
    print("INSIDE TASK");
    final filePath = inputData!['file_path']!;
    final tusStoreDirectoryPath = inputData['tus_store_directory']!;
    final tusdUrl = inputData['tusd_url']!;
    final notificationChannelKey = inputData['notification_channel_key']!;
    final notificationGroupKey = inputData['notification_group_key'];

    print("CONSTRUCTING XFILE");
    final file = XFile(filePath);

    print("CONSTRUCTING TUSD STORAGE DIRECTORY");
    final tempDirectory = Directory(
        '$tusStoreDirectoryPath/${file.name}_uploads');
    if (!tempDirectory.existsSync()) {
      tempDirectory.createSync(recursive: true);
    }

    final fileName = file.path.split('/').last;

    print("CONSTRUCTING TusClient");
    final client = TusClient(
      file,
      store: TusFileStore(tempDirectory),
      maxChunkSize: 512 * 1024 * 2, // 1024 kB
    );

    int notificationId = fum.getNotificationIdFor(filePath);

    print("Starting upload");
    await client.upload(

      onStart: (client,estimate) => {
        fum._updateCurrentProgressBar(
            id: notificationId,
            progressPercentage: 0,
            notificationChannelKey: notificationChannelKey,
            notificationGroupKey: notificationGroupKey,
            fileName: fileName
        )},

      onProgress: fum.throttle((progress, _) {
        fum._updateCurrentProgressBar(
            id: notificationId,
            progressPercentage: progress,
            notificationChannelKey: notificationChannelKey,
            notificationGroupKey: notificationGroupKey,
            fileName: fileName
        );
      }, const Duration(seconds: 1)), // Ensure that the progressBar won't be called more than once per second.

      onComplete: () async {
        print("Completed!");
        fum.removeNotificationIdFor(filePath);
        tempDirectory.deleteSync(recursive: true);
        // setState(() => _fileUrl = _client.uploadUrl);
      },

      uri: Uri.parse(tusdUrl),
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
