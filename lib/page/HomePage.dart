import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tus_client_background_demo/model/VideoMetadataProvider.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<VideoInfo>> _videoInfoList;

  @override
  void initState() {
    super.initState();
    _videoInfoList = VideoMetadataProvider().getVideoInfo();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder<List<VideoInfo>>(
        future: _videoInfoList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No files found'));
          }

          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildVideoCard(context, items[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, VideoInfo videoInfo) {
    Widget subtitle = Text(videoInfo.videoLength != null ?
        videoInfo.videoLength!.toString().split('.').first :
        "N/A");

    return Card(
      child: ListTile(
        leading: _buildThumbnail(videoInfo.thumbnail),
        title: Text(videoInfo.videoTitle ?? "untitled"), // Replace with actual video title
        subtitle: subtitle,
        onTap: () {
          // Handle tap event
        },
      ),
    );
  }


  Widget _buildThumbnail(Uint8List? thumbnailData) {
    if (thumbnailData != null) {
      return Image.memory(
        thumbnailData,
        width: 100, // Adjust as needed
        height: 100, // Adjust as needed
        fit: BoxFit.cover,
      );
    } else {
      // Placeholder or default image when thumbnailData is null
      return Container(
        width: 100, // Adjust as needed
        height: 100, // Adjust as needed
        color: Colors.grey, // Placeholder color
        child: Icon(Icons.video_library, size: 50, color: Colors.greenAccent),
      );
    }
  }

  String _formatDuration(Duration duration) {
    return duration.toString();

    // String twoDigits(int n) => n.toString().padLeft(2, '0');
    //
    // String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    // String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    //
    // return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }
}