import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

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
