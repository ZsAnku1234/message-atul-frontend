import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../widgets/app_avatar.dart';

class ConversationTile extends StatelessWidget {
  ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    this.currentUserId,
  });

  final ConversationSummary conversation;
  final VoidCallback onTap;
  final String? currentUserId;
  final DateFormat _timeFormat = DateFormat('h:mm a');

  @override
  Widget build(BuildContext context) {
    final lastMessage = conversation.lastMessage;
    final subtitle = _buildSubtitle(lastMessage);
    final time = lastMessage != null
        ? _timeFormat.format(lastMessage.createdAtIndian)
        : '';
    final primaryParticipant =
        conversation.participantForDisplay(currentUserId);
    final displayTitle = conversation.titleFor(currentUserId);
    final fallbackInitial = displayTitle.isNotEmpty ? displayTitle[0] : '?';
    final hasUnread = conversation.unreadCount > 0;

    return ListTile(
      onTap: onTap,
      leading: AppAvatar(
        imageUrl: primaryParticipant?.avatarUrl,
        initials: primaryParticipant != null
            ? (primaryParticipant.displayName.isNotEmpty
                ? primaryParticipant.displayName[0]
                : '?')
            : fallbackInitial,
      ),
      title: Text(
        displayTitle,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (conversation.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                conversation.unreadCount.toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  String _buildSubtitle(Message? message) {
    if (message == null) {
      return 'Start a conversation';
    }

    final text = message.body.trim();
    if (text.isNotEmpty) {
      return text;
    }

    final attachments = message.attachments;
    if (attachments.isEmpty) {
      return 'New message';
    }

    final kind = _detectAttachmentKind(attachments.first);
    final baseLabel = switch (kind) {
      _AttachmentPreviewKind.image => 'Photo',
      _AttachmentPreviewKind.video => 'Video',
      _AttachmentPreviewKind.other => 'Attachment',
    };

    if (attachments.length > 1) {
      final remaining = attachments.length - 1;
      return '$baseLabel + $remaining more';
    }

    return baseLabel;
  }

  _AttachmentPreviewKind _detectAttachmentKind(String url) {
    final lower = url.toLowerCase();
    const imageExt = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'];
    const videoExt = ['.mp4', '.mov', '.m4v', '.avi', '.webm', '.mkv'];

    if (lower.contains('/image/') || imageExt.any(lower.endsWith)) {
      return _AttachmentPreviewKind.image;
    }
    if (lower.contains('/video/') || videoExt.any(lower.endsWith)) {
      return _AttachmentPreviewKind.video;
    }
    return _AttachmentPreviewKind.other;
  }
}

enum _AttachmentPreviewKind { image, video, other }
