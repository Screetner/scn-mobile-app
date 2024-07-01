import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'model/FileUploadManager.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("MAIN FUNCTION");

  await dotenv.load(fileName: ".env");

  UploadContext fumc = await getEnvContext();

  await FileUploadManager().initialize(fumc);
  runApp(MyApp());
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

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TUS Client Upload Demo',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: UploadPage(),
    );
  }
}

class UploadPage extends StatefulWidget {

  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  double _progress = 0;
  Duration _estimate = Duration();
  FilePickerResult? _filePickerResult;
  Uri? _fileUrl;

  void showInSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('TUS Client Upload Demo'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                "This demo uses TUS client to upload a file",
                style: TextStyle(fontSize: 18),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Card(
                color: Colors.teal,
                child: InkWell(
                  onTap: () async {
                    _filePickerResult=await FilePicker.platform.pickFiles();
                    setState(() {
                      _progress = 0;
                      _fileUrl = null;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.cloud_upload, color: Colors.white, size: 60),
                        Text(
                          "Upload a file",
                          style: TextStyle(fontSize: 25, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _filePickerResult == null
                          ? null
                          : _startUpload,
                      child: Text("Upload"),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _progress == 0
                          ? null
                          : _pauseUpload,
                      child: Text("Pause"),
                    ),
                  ),
                ],
              ),
            ),
            Stack(
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(1),
                  color: Colors.grey,
                  width: double.infinity,
                  child: Text(" "),
                ),
                FractionallySizedBox(
                  widthFactor: _progress / 100,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(1),
                    color: Colors.green,
                    child: Text(" "),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(1),
                  width: double.infinity,
                  child: Text(
                      "Progress: ${_progress.toStringAsFixed(1)}%, estimated time: ${_printDuration(_estimate)}"),
                ),
              ],
            ),
            if (_progress > 0)
              ElevatedButton(
                onPressed: _cancelUpload,
                child: Text("Cancel"),
              ),
            GestureDetector(
              onTap: _progress != 100
                  ? null
                  : () async {
                await launchUrl(_fileUrl!);
              },
              child: Container(
                color: _progress == 100 ? Colors.green : Colors.grey,
                padding: const EdgeInsets.all(8.0),
                margin: const EdgeInsets.all(8.0),
                child:
                Text(_progress == 100 ? "Link to view:\n $_fileUrl" : "-"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startUpload() async {
    await requestNotificationPermission();
    print('OUTSIDE TASK');
    FileUploadManager().uploadFile(_filePickerResult!.files.first.path!);
  }

  Future<void> _cancelUpload() async {
    final fingerPrint = _filePickerResult!.files.first.path!.replaceAll(RegExp(r"\W+"), '.');
    // await Workmanager().cancelByUniqueName(fingerPrint);

    // if (result) {
    //   setState(() {
    //     _progress = 0;
    //     _estimate = Duration();
    //   });
    // }
  }

  Future<void> _pauseUpload() async {
    FileUploadManager().pauseUpload(_filePickerResult!.files.first.path!);
  }

  String _printDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}

Future<void> requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}