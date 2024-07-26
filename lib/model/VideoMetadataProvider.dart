import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/media_information.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../context/ImmutableVideoRecordManagerContext.dart';

class VideoMetadataProvider {
  bool _isInitialized = false;

  late Directory _videoDirectory;

  VideoMetadataProvider._privateConstructor();

  static final VideoMetadataProvider _instance = VideoMetadataProvider._privateConstructor();

  factory VideoMetadataProvider() {
    return _instance;
  }

  Future<void> initialize(RecordContext context) async {
    if (_isInitialized) {
      return;
    }

    _videoDirectory = context.recordDirectory;
    _isInitialized = true;
  }

  Future<List<VideoInfo>> getVideoInfo() async {
    final List<File> videoFiles = await getVideoFiles();

    final filesCount = videoFiles.length;
    final batchSize = 10;

    // NOTE: We cannot run more than 10 ffprobe executions at a time.
    List<VideoInfo> videoInfoList = [];
    for(int i = 0; i < filesCount; i += batchSize) {
      final batch = videoFiles.sublist(i, min(i + batchSize, filesCount));

      List<Future<VideoInfo>> batchFutures = batch.map((File file) async {
        final metadata = await _getVideoMetadata(file.path);

        final durationMicroseconds = (double.parse(metadata!.getDuration()!) * 1000000).toInt();
        final fileName = file.path.split('/').last.split('.').first;
        final videoTitle = parseAndFormatUnixTimestamp(fileName) ?? fileName;

        return VideoInfo(
          thumbnail: await getThumbnail(file.path),
          videoLength: Duration(microseconds: durationMicroseconds),
          videoTitle: videoTitle,
        );
      }).toList();

      List<VideoInfo> batchResults = await Future.wait(batchFutures);
      videoInfoList.addAll(batchResults);
    }

    return videoInfoList;
  }

  Future<List<File>> getVideoFiles() async {
    return _videoDirectory
        .listSync()
        .where((item) => item.path.endsWith(".mp4"))
        .map((item) => File(item.path))
        .toList();
  }

  Future<Uint8List?> getThumbnail(String filePath) async {
    return VideoThumbnail.thumbnailData(
      video: filePath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 128,
      quality: 75,
    );
  }

  String? parseAndFormatUnixTimestamp(String input) {
    const weekdayArray = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const monthArray = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    final timestamp = int.tryParse(input);
    if (timestamp == null) {
      return null;
    }


    // Convert the timestamp to DateTime
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

    final hour = dateTime.hour.toString();
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final weekday = weekdayArray[dateTime.weekday];
    final date = dateTime.day.toString();
    final month = monthArray[dateTime.month];
    final year = dateTime.year.toString();
    return '$hour:$minute $weekday $date $month $year';
  }

  Future<MediaInformation?> _getVideoMetadata(String filePath) async {
    try {
      return FFprobeKit.getMediaInformation(filePath).then((session) async {
        final information = await session.getMediaInformation();

        if (information == null) {
          final state = FFmpegKitConfig.sessionStateToString(
              await session.getState());
          final returnCode = await session.getReturnCode();
          final failStackTrace = await session.getFailStackTrace();
          final duration = await session.getDuration();
          final output = await session.getOutput();
        }

        return information;
      });
    } catch (e) {
      return null;
    }
  }
}

class ImmutableVideoInformation {
  final Uint8List? thumbnail;
  final Duration? videoLength;
  final String? videoTitle;

  ImmutableVideoInformation({
    Uint8List? this.thumbnail,
    Duration? this.videoLength,
    String? this.videoTitle
  }) {}
}

typedef VideoInfo = ImmutableVideoInformation;