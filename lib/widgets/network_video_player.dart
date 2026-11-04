// บทบาทไฟล์: คอมโพเนนต์ Widget ที่นำกลับมาใช้ซ้ำ (lib/widgets/network_video_player.dart).

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '/core/theme/app_theme.dart';

/// วิดเจ็ตวิดีโอแบบ inline พร้อมสถานะโหลด ข้อผิดพลาด และปุ่มเล่น/หยุด.
class NetworkVideoPlayer extends StatefulWidget {
  final String url;
  final double? height;

  const NetworkVideoPlayer({super.key, required this.url, this.height});

  @override
  State<NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<NetworkVideoPlayer> {
  late VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant NetworkVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller.dispose();
      _failed = false;
      _initialize();
    }
  }

  void _initialize() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const SizedBox(
        height: 180,
        child: Center(child: Icon(Icons.error_outline, color: AppColors.textMuted)),
      );
    }
    if (!_controller.value.isInitialized) {
      return SizedBox(
        height: widget.height ?? 200,
        child: const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary)),
      );
    }
    return SizedBox(
      height: widget.height,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            IconButton.filled(
              onPressed: () => setState(() {
                _controller.value.isPlaying ? _controller.pause() : _controller.play();
              }),
              icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 4,
              child: VideoProgressIndicator(_controller, allowScrubbing: true),
            ),
          ],
        ),
      ),
    );
  }
}
