import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message.dart';
import '../screens/media_viewer_screen.dart';
import '../theme/color_tokens.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final hasText = message.body.trim().isNotEmpty;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: Radius.circular(isMine ? 22 : 8),
      bottomRight: Radius.circular(isMine ? 8 : 22),
    );
    final gradient = isMine
        ? AppColors.linearGradient
        : const LinearGradient(
            colors: [Color(0xFFFDFDFE), Color(0xFFEFF3FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final bubbleDecoration = BoxDecoration(
      gradient: gradient,
      borderRadius: radius,
      border: Border.all(
        color: isMine ? Colors.white.withOpacity(0.1) : const Color(0xFFD6DBF5),
        width: (!hasText && message.attachments.isNotEmpty) ? 0.5 : 1.0,
      ),
      boxShadow: [
        BoxShadow(
          blurRadius: 24,
          spreadRadius: 0,
          color: isMine
              ? const Color(0x3323358D)
              : Colors.black.withOpacity(0.08),
          offset: const Offset(0, 10),
        ),
      ],
    );
    final textColor = isMine ? Colors.white : const Color(0xFF0F172A);
    final metaColor =
        isMine ? Colors.white70 : const Color(0xFF4F5D7A);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: EdgeInsets.only(
          left: isMine ? 60 : 12,
          right: isMine ? 12 : 60,
          top: 4,
          bottom: 4,
        ),
        child: DecoratedBox(
          decoration: bubbleDecoration,
          child: Padding(
            padding: (!hasText && message.attachments.isNotEmpty)
                ? const EdgeInsets.all(4)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.attachments.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: hasText ? 10 : 2),
                    child: _AttachmentGrid(
                      attachments: message.attachments,
                      onTap: (url, kind) =>
                          _handleAttachmentTap(context, url, kind),
                    ),
                  ),
                if (hasText)
                  Text(
                    message.body,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: isMine
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: metaColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      message.formattedTime,
                      style: TextStyle(
                        color: metaColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAttachmentTap(
    BuildContext context,
    String url,
    _AttachmentKind kind,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (kind == _AttachmentKind.image) {
      // Collect all image URLs from attachments
      final imageUrls = message.attachments
          .where((attachment) => _detectKind(attachment) == _AttachmentKind.image)
          .toList();
      
      // Find the index of the tapped image
      final initialIndex = imageUrls.indexOf(url);
      
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => MediaViewerScreen(
            url: url,
            type: MediaViewerType.image,
            imageUrls: imageUrls.length > 1 ? imageUrls : null,
            initialIndex: initialIndex >= 0 ? initialIndex : 0,
          ),
        ),
      );
      return;
    }

    if (kind == _AttachmentKind.video) {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => MediaViewerScreen(
            url: url,
            type: MediaViewerType.video,
          ),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    messenger?.showSnackBar(
      const SnackBar(content: Text('Unable to open this attachment.')),
    );
  }
}

class _AttachmentGrid extends StatelessWidget {
  const _AttachmentGrid({
    required this.attachments,
    required this.onTap,
  });

  final List<String> attachments;
  final void Function(String url, _AttachmentKind kind) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final spacing = 8.0;
        final mediaWidth = (maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: attachments.map((url) {
            final kind = _detectKind(url);
            final isDocument = kind == _AttachmentKind.other;
            final width = isDocument ? maxWidth : mediaWidth;
            final height = isDocument ? 72.0 : mediaWidth * 0.75;
            return SizedBox(
              width: width,
              child: GestureDetector(
                onTap: () => onTap(url, kind),
                child: _AttachmentTile(
                  url: url,
                  kind: kind,
                  height: height,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.url,
    required this.kind,
    required this.height,
  });

  final String url;
  final _AttachmentKind kind;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kind == _AttachmentKind.other ? 14 : 18),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xFFE9EEF5),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    switch (kind) {
      case _AttachmentKind.image:
        return Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image_outlined)),
        );
      case _AttachmentKind.video:
        return const Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B2A3B), Color(0xFF0F1317)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 42,
              ),
            ),
          ],
        );
      case _AttachmentKind.other:
        final label = url.split('/').last;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file_outlined,
                  color: Colors.black54),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
        );
    }
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
