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

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: EdgeInsets.only(
          left: isMine ? 60 : 12,
          right: isMine ? 12 : 60,
          top: 4,
          bottom: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMine ? null : Colors.white,
          gradient: isMine ? AppColors.linearGradient : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMine ? 20 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 20),
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 14,
              offset: Offset(0, 6),
              color: Color(0x14000000),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.attachments.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: hasText ? 8 : 0),
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
                  color: isMine ? Colors.white : Colors.black87,
                  fontSize: 15,
                  height: 1.42,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              message.formattedTime,
              style: TextStyle(
                color: isMine ? Colors.white70 : Colors.grey.shade500,
                fontSize: 11,
              ),
            ),
          ],
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
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => MediaViewerScreen(
            url: url,
            type: MediaViewerType.image,
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments.map((url) {
        final kind = _detectKind(url);
        return GestureDetector(
          onTap: () => onTap(url, kind),
          child: _AttachmentTile(url: url, kind: kind),
        );
      }).toList(),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.url, required this.kind});

  final String url;
  final _AttachmentKind kind;

  @override
  Widget build(BuildContext context) {
    final size = kind == _AttachmentKind.other
        ? const Size(180, 64)
        : const Size(160, 160);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: size.width,
        height: size.height,
        color: Colors.black12,
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
