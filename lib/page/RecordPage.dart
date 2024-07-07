
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<StatefulWidget> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  List<CameraDescription>? _cameras;
  CameraController? _controller;

  XFile? videoFile;

  late Directory appDirectory;
  late String videoDirectory;

  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _setupDirectory();
    _initializeCameras();
  }

  @override
  void dispose() {
    if(_controller != null) {
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if(_controller == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
        body: Stack(
          children: <Widget>[
            _cameraPreviewWidget(),
            _captureControlRowWidget()
          ],
        )
    );
  }

  Widget _cameraPreviewWidget() {
    // credits to Adam Vidarsson on Medium
    // link: https://medium.com/lightsnap/making-a-full-screen-camera-application-in-flutter-65db7f5d717b
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    final xScale = _controller!.value.aspectRatio / deviceRatio;
    // Modify the yScale if you are in Landscape
    final yScale = 1.0;

    return Container(
      child: AspectRatio(
        aspectRatio: deviceRatio,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(xScale, yScale, 1),
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _captureControlRowWidget() {
    return Positioned(
      bottom: 16.0,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.videocam),
            iconSize: 48.0,
            color: (_controller!.value.isRecordingVideo) ? Colors.red : Colors.blue,
            onPressed: _onVideoRecordButtonPressed,
          ),
        ],
      ),
    );
  }

  void _onVideoRecordButtonPressed() {
    if(!_controller!.value.isRecordingVideo) {
      print("SKIBIDI");
      _startVideoRecording().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      print("TOILET");
      _stopVideoRecording().then((XFile? file) {
        if (mounted) {
          setState(() {});
        }
        if (file != null) {
          print('Video recorded to ${file.path}');
          videoFile = file;
          // _startVideoPlayer();
        } else {
          print("WHY IT AINT HAVING FILE???!!!!");
        }
      });
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller!.value.isRecordingVideo) {
      print("SUCKS TO BE YOU");
      // A recording is already started, do nothing.
      return;
    }

    try {
      final String currentTime = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath = '$videoDirectory/VID_$currentTime.mp4';
      await _controller!.startVideoRecording();
    } on CameraException catch (e) {
      print("SUCKS TO BE YOU TOO");
      return;
    }
  }

  Future<XFile?> _stopVideoRecording() async {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return null;
    }

    try {
      return cameraController.stopVideoRecording();
    } on CameraException catch (e) {
      print(e);
      return null;
    }
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
      _controller = CameraController(_cameras![1], ResolutionPreset.max,
        fps: 1,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (!mounted) {
        return;
      }
      setState(() {});
    } on CameraException catch (e) {
      // Handle the error here
      print('Error fetching cameras: $e');
    }
  }

  Future<void> _setupDirectory() async {
    try {
      appDirectory = await getApplicationDocumentsDirectory();
      videoDirectory = '${appDirectory.path}/records';
      await Directory(videoDirectory).create(recursive: true);

    } catch (e) {
      print('Error setting up directory: $e');
    }
  }
}