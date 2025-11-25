import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

enum MediaViewerType { image, video }

class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.url,
    required this.type,
    this.imageUrls,
    this.initialIndex = 0,
  });

  final String url;
  final MediaViewerType type;
  final List<String>? imageUrls;
  final int initialIndex;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _videoController;
  bool _videoError = false;
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
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
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGalleryMode = widget.imageUrls != null && widget.imageUrls!.length > 1;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: isGalleryMode
            ? Text(
                '${_currentPage + 1} / ${widget.imageUrls!.length}',
                style: const TextStyle(fontSize: 16),
              )
            : null,
      ),
      body: Center(
        child: widget.type == MediaViewerType.image
            ? (isGalleryMode ? _buildImageGallery() : _buildImage(widget.url))
            : _buildVideo(),
      ),
    );
  }

  Widget _buildImageGallery() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
      },
      itemCount: widget.imageUrls!.length,
      itemBuilder: (context, index) {
        return _buildImage(widget.imageUrls![index]);
      },
    );
  }

  Widget _buildImage(String url) {
    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 4,
      child: Image.network(
        url,
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
