import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_canvas.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/models/video_archive_entry.dart';

class VideoPlayerPage extends StatelessWidget {
  const VideoPlayerPage({super.key, required this.entry});

  final VideoArchiveEntry entry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.displayTitle),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ChatMockupTheme.canvasMaxWidth),
          child: ChatMockupCanvas(
            initialPayload: entry.decodedPayload,
            readOnly: true,
            browseMode: true,
            autoStartPlayback: true,
            lockAiMode: true,
          ),
        ),
      ),
    );
  }
}
