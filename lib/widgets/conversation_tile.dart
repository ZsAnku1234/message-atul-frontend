import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/conversation.dart';
import '../widgets/app_avatar.dart';

class ConversationTile extends StatelessWidget {
  ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final VoidCallback onTap;
  final DateFormat _timeFormat = DateFormat('h:mm a');

  @override
  Widget build(BuildContext context) {
    final lastMessage = conversation.lastMessage;
    final subtitle = lastMessage?.body ?? 'Start a conversation';
    final time = lastMessage != null ? _timeFormat.format(lastMessage.createdAt) : '';
    final primaryParticipant =
        conversation.participants.isNotEmpty ? conversation.participants.first : null;
    final fallbackInitial =
        conversation.displayTitle.isNotEmpty ? conversation.displayTitle[0] : '?';

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
        conversation.displayTitle,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                conversation.unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
