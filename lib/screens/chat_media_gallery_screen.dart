import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../providers/app_providers.dart';
import '../theme/color_tokens.dart';
import 'media_viewer_screen.dart';

class ChatMediaGalleryScreen extends ConsumerStatefulWidget {
  const ChatMediaGalleryScreen({
    super.key,
    required this.conversationId,
    required this.title,
  });

  final String conversationId;
  final String title;

  @override
  ConsumerState<ChatMediaGalleryScreen> createState() => _ChatMediaGalleryScreenState();
}

class _ChatMediaGalleryScreenState extends ConsumerState<ChatMediaGalleryScreen> {
  final _scrollController = ScrollController();
  final List<Message> _messages = [];
  final List<MediaItem> _galleryItems = []; // Cache derived items
  bool _isLoading = true;
  bool _hasMore = true;
  int _offset = 0;
  static const _limit = 50;

  @override
  void initState() {
    super.initState();
    _loadMedia();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.7) { // Trigger earlier
      _loadMedia();
    }
  }

  Future<void> _loadMedia() async {
    if (!_hasMore || (_isLoading && _messages.isNotEmpty)) return;

    if (_messages.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final repo = ref.read(chatRepositoryProvider);
      final newMessages = await repo.fetchMedia(
        conversationId: widget.conversationId,
        limit: _limit,
        offset: _offset,
      );

      if (!mounted) return;

      // Calculate new items only
      final newItems = <MediaItem>[];
      for (final msg in newMessages) {
        for (final url in msg.attachments) {
          final kind = _detectKind(url);
          if (kind == _AttachmentKind.image) {
            newItems.add(MediaItem(url: url, type: MediaViewerType.image));
          } else if (kind == _AttachmentKind.video) {
            newItems.add(MediaItem(url: url, type: MediaViewerType.video));
          }
        }
      }

      setState(() {
        _messages.addAll(newMessages);
        _galleryItems.addAll(newItems); // Append directly
        _offset += newMessages.length;
        _hasMore = newMessages.length >= _limit;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load media: $e')),
      );
    }
  }

  void _openMedia(String url) {
    final index = _galleryItems.indexWhere((item) => item.url == url);
    if (index == -1) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          galleryItems: _galleryItems,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0, // Fixes "whitish blur" tint on scroll
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            Text(
              'Media',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
      body: _messages.isEmpty && !_isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.perm_media_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                   const SizedBox(height: 16),
                   const Text(
                    'No media shared yet',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                   ),
                ],
              ),
            )
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: _galleryItems.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _galleryItems.length) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                final item = _galleryItems[index];
                return GestureDetector(
                  onTap: () => _openMedia(item.url),
                  child: _MediaGridTile(item: item),
                );
              },
            ),
    );
  }
}

class _MediaGridTile extends StatelessWidget {
  const _MediaGridTile({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: item.type == MediaViewerType.video 
             ? _getThumbnail(item.url) 
             : item.url,
          fit: BoxFit.cover,
          memCacheWidth: 400, // Optimize memory usage for grid
          placeholder: (context, url) => Container(color: Colors.grey.shade200),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
        if (item.type == MediaViewerType.video)
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
          ),
      ],
    );
  }

  String _getThumbnail(String url) {
    final extension = url.split('.').last;
    if (url.endsWith('.$extension')) {
       return url.replaceFirst('.$extension', '_thumb.jpg');
    }
    return '$url.jpg';
  }
}

enum _AttachmentKind { image, video, other }

_AttachmentKind _detectKind(String url) {
  final lower = url.toLowerCase();
  const imageExt = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'];
  const videoExt = ['.mp4', '.mov', '.m4v', '.avi', '.webm', '.mkv'];

  if (lower.contains('/image/') || imageExt.any(lower.endsWith)) {
    return _AttachmentKind.image;
  }
  if (lower.contains('/video/') || videoExt.any(lower.endsWith)) {
    return _AttachmentKind.video;
  }
  return _AttachmentKind.other;
}
