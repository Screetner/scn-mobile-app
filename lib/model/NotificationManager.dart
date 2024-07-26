import 'dart:math';

import 'package:awesome_notifications/awesome_notifications.dart';

import '../context/ImmutableFileUploadManagerContext.dart';

class NotificationManager {
  bool _isInitialized = false;

  final Map<String, int> _notificationIdMap = {};

  NotificationManager._privateConstructor();

  static final NotificationManager _instance = NotificationManager._privateConstructor();

  factory NotificationManager() {
    return _instance;
  }

  Future<bool> initialize(UploadContext context) async {
    if(_isInitialized) {
      return false;
    }

    final String notificationChannelName = context.notificationChannelName ?? context.notificationChannelKey;
    final String notificationChannelGroupName = context.notificationChannelGroupName ?? context.notificationChannelGroupKey;
    final String notificationChannelDescription = context.notificationChannelDescription ??
        "NotificationPage.dart channel for reporting file upload progress";

    bool notificationsInitialized = await AwesomeNotifications().initialize(
      null, // default icon
      [
        NotificationChannel(
          channelGroupKey: context.notificationChannelGroupKey,
          channelKey: context.notificationChannelKeySilent,
          channelName: notificationChannelName,
          channelDescription: notificationChannelDescription,
          defaultColor: context.notificationDefaultColor,
          soundSource: context.notificationSoundSource,
          playSound: false,
          enableVibration: false,
          vibrationPattern: context.notificationVibrationPattern,
        ),
        NotificationChannel(
          channelGroupKey: context.notificationChannelGroupKey,
          channelKey: context.notificationChannelKeyAudible,
          channelName: notificationChannelName,
          channelDescription: notificationChannelDescription,
          defaultColor: context.notificationDefaultColor,
          soundSource: context.notificationSoundSource,
          playSound: true,
          enableVibration: true,
          vibrationPattern: context.notificationVibrationPattern,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: context.notificationChannelGroupKey,
          channelGroupName: notificationChannelGroupName,
        ),
      ],
    );

    _isInitialized = notificationsInitialized;
    return notificationsInitialized;
  }

  // credits to awesome-notification documentation
  // link: https://awesome-notification-docs.vercel.app/
  void updateProgressBarFor(String filePath, double progressPercentage, UploadContext context) {
    const double maxPercentage = 100;

    final id = getNotificationIdFor(filePath);
    final fileName = filePath.split('/').last;

    print("UPDATE PROGRESS BAR");
    print("PROGRESS PERCENTAGE: $progressPercentage");

    if (progressPercentage < maxPercentage) {
      double progress = min(progressPercentage, maxPercentage);
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: context.notificationChannelKeySilent,
          groupKey: context.notificationChannelGroupKey,
          title: 'Uploading ${fileName} ${progress.toInt()}%',
          body: 'fanum tax',
          category: NotificationCategory.Progress,
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
          channelKey: context.notificationChannelKeyAudible,
          groupKey: context.notificationChannelGroupKey,
          title: 'Upload ${fileName} finished',
          body: 'skibidi',
          category: NotificationCategory.Progress,
          notificationLayout: NotificationLayout.ProgressBar,
          locked: false,
        ),
      );
    }
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
}