import 'package:flutter/material.dart';

class ClipPreviewPlayer extends StatelessWidget {
  final String videoPath;
  final Duration startTime;
  final Duration endTime;

  const ClipPreviewPlayer({
    super.key,
    required this.videoPath,
    required this.startTime,
    required this.endTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text('Video Player Stub', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
