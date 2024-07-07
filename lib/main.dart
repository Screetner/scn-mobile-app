import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
// import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'model/FileUploadManager.dart';
import 'presentation/ScreetnerMainApp.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  UploadContext fumc = await getEnvContext();
  List<CameraDescription> _cameras = await availableCameras();

  await FileUploadManager().initialize(fumc);
  runApp(ScreetnerMainApp());
}

Future<UploadContext> getEnvContext() async {
  return new UploadContext(
      tusdServerUrl: dotenv.env['TUSD_SERVER_URL']!,
      tusStoreDirectory: Directory(dotenv.env['TUS_STORE_DIRECTORY'] ?? (await getApplicationDocumentsDirectory()).path),
  notificationChannelKey: dotenv.env['NOTIFICATION_CHANNEL_KEY'] ?? 'scn-mobile-app-progress-notification',
  notificationChannelGroupKey: dotenv.env['NOTIFICATION_CHANNEL_GROUP_KEY'] ?? 'scn-mobile-app',
  notificationChannelName: dotenv.env['NOTIFICATION_CHANNEL_NAME'],
  notificationChannelGroupName: dotenv.env['NOTIFICATION_CHANNEL_GROUP_NAME'],
  notificationChannelDescription: dotenv.env['NOTIFICATION_CHANNEL_DESCRIPTION'],
  notificationSoundSource: dotenv.env['NOTIFICATION_SOUND_SOURCE'],
  notificationDefaultColor: dotenv.env['NOTIFICATION_DEFAULT_COLOR'] != null
  ? Color(int.parse(dotenv.env['NOTIFICATION_DEFAULT_COLOR']!, radix: 16))
      : null,
  notificationVibrationPattern: dotenv.env['NOTIFICATION_VIBRATION_PATTERN'] != null
  ? Int64List.fromList(dotenv.env['NOTIFICATION_VIBRATION_PATTERN']!.split(',').map(int.parse).toList())
      : null,
  );
}

Future<void> requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}