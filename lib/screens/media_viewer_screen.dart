import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

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

  void _videoListener() {
    final controller = _currentVideoController;
    if (controller != null && controller.value.hasError && !_videoError) {
      debugPrint('Video player error: ${controller.value.errorDescription}');
      if (mounted) setState(() => _videoError = true);
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
    controller.addListener(_videoListener);

    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Video initialization error: $e');
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
      extendBodyBehindAppBar: true, // Allow content to go behind app bar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent background
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light, // White icons
          statusBarBrightness: Brightness.dark, // iOS
        ),
        title: Text(
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
            if (index == _currentPage) {
               return _buildVideo();
            } else {
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'Cannot play video',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                final item = widget.galleryItems[_currentPage];
                launchUrl(Uri.parse(item.url), mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in external player'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
              ),
            ),
          ],
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
