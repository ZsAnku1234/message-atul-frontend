import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

enum MediaViewerType { image, video }

class MediaItem {
  const MediaItem({
    required this.url,
    required this.type,
  });

  final String url;
  final MediaViewerType type;
}

class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    required this.galleryItems,
    this.initialIndex = 0,
  });

  final List<MediaItem> galleryItems;
  final int initialIndex;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late PageController _pageController;
  late int _currentPage;
  VideoPlayerController? _currentVideoController;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initializeCurrentMedia();
  }

  @override
  void dispose() {
    _currentVideoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _initializeCurrentMedia() {
    _currentVideoController?.dispose();
    _currentVideoController = null;
    _videoError = false;

    if (_currentPage < 0 || _currentPage >= widget.galleryItems.length) return;

    final item = widget.galleryItems[_currentPage];
    if (item.type == MediaViewerType.video) {
      _initializeVideo(item.url);
    }
  }

  Future<void> _initializeVideo(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) setState(() => _videoError = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _currentVideoController = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _videoError = true);
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _initializeCurrentMedia();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title:  Text(
          '${_currentPage + 1} / ${widget.galleryItems.length}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: widget.galleryItems.length,
        itemBuilder: (context, index) {
          final item = widget.galleryItems[index];
          if (item.type == MediaViewerType.image) {
            return _buildImage(item.url);
          } else {
            // We only show the video player if it matches the current page's controller
            // to avoid initializing multiple video controllers at once (simple approach)
            // or we could use the instantiated controller if index == _currentPage
            if (index == _currentPage) {
               return _buildVideo();
            } else {
               // Placeholder for video while swiping
               return const Center(child: CircularProgressIndicator(color: Colors.white24));
            }
          }
        },
      ),
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
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        },
      ),
    );
  }

  Widget _buildVideo() {
    final controller = _currentVideoController;
    if (_videoError) {
      return const Center(
        child: Text(
          'Unable to play video',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
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
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, VideoPlayerValue value, child) {
                      final position = value.position;
                      return Text(
                        _formatDuration(position),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: controller,
                      builder: (context, VideoPlayerValue value, child) {
                        final duration = value.duration.inMilliseconds.toDouble();
                        final position = value.position.inMilliseconds.toDouble();
                        return Slider(
                          value: position.clamp(0.0, duration),
                          min: 0.0,
                          max: duration,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white24,
                          onChanged: (newValue) {
                            controller.seekTo(Duration(milliseconds: newValue.toInt()));
                          },
                        );
                      },
                    ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, VideoPlayerValue value, child) {
                      final duration = value.duration;
                      return Text(
                        _formatDuration(duration),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
