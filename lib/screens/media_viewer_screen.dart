import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

enum MediaViewerType { image, video }

class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.url,
    required this.type,
  });

  final String url;
  final MediaViewerType type;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _videoController;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == MediaViewerType.video) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      setState(() {
        _videoError = true;
      });
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _videoController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _videoError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: widget.type == MediaViewerType.image
            ? _buildImage()
            : _buildVideo(),
      ),
    );
  }

  Widget _buildImage() {
    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 4,
      child: Image.network(
        widget.url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Text(
          'Unable to load image',
          style: TextStyle(color: Colors.white70),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const CircularProgressIndicator(color: Colors.white);
        },
      ),
    );
  }

  Widget _buildVideo() {
    final controller = _videoController;
    if (_videoError) {
      return const Text(
        'Unable to play video',
        style: TextStyle(color: Colors.white70),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (controller.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          if (!controller.value.isPlaying)
            const Icon(
              Icons.play_circle_outline,
              size: 72,
              color: Colors.white70,
            ),
        ],
      ),
    );
  }
}
