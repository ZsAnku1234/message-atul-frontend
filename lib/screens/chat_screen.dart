import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/chat/chat_controller.dart';
import '../application/chat/chat_state.dart';
import '../theme/color_tokens.dart';
import '../widgets/app_avatar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(chatControllerProvider.notifier).selectConversation(widget.conversationId),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    await ref.read(chatControllerProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final conversation = chatState.activeConversation;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final primaryParticipant =
        conversation?.participants.isNotEmpty == true ? conversation!.participants.first : null;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: conversation == null
            ? const SizedBox.shrink()
            : Row(
                children: [
                  AppAvatar(
                    imageUrl: primaryParticipant?.avatarUrl,
                    initials: primaryParticipant != null
                        ? (primaryParticipant.displayName.isNotEmpty
                            ? primaryParticipant.displayName[0]
                            : '?')
                        : '?',
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.displayTitle,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
                      ),
                      Text(
                        '${conversation.participants.length} participants',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.subtleGradient,
              ),
              child: chatState.isLoading && chatState.messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      itemCount: chatState.messages.length,
                      itemBuilder: (context, index) {
                        final message = chatState.messages[index];
                        return MessageBubble(message: message);
                      },
                    ),
            ),
          ),
          if (chatState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                chatState.errorMessage!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          MessageInputBar(
            onSend: _send,
            isSending: chatState.isSending,
          ),
        ],
      ),
    );
  }
}
