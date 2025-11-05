import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/auth/auth_controller.dart';
import '../application/chat/chat_controller.dart';
import '../application/chat/chat_state.dart';
import '../models/user.dart';
import '../theme/color_tokens.dart';
import '../theme/text_styles.dart';
import '../widgets/app_avatar.dart';
import '../widgets/conversation_tile.dart';

class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final chatNotifier = ref.read(chatControllerProvider.notifier);
    final highlightProfiles = <String, UserProfile>{};

    for (final conversation in chatState.conversations) {
      for (final participant in conversation.participants) {
        if (participant.id == authState.user?.id) {
          continue;
        }
        highlightProfiles[participant.id] = participant;
      }
    }
    final highlightList = highlightProfiles.values.toList();
    final highlightItemCount = highlightList.length > 6 ? 6 : highlightList.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Conversations',
          style: AppTextStyles.lightTextTheme.titleMedium,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: AppAvatar(
                imageUrl: authState.user?.avatarUrl,
                initials: authState.user?.displayName.substring(0, 1) ?? '?',
              ),
            ),
          ),
        ],
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await chatNotifier.loadConversations();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.subtleGradient,
                ),
                padding: const EdgeInsets.fromLTRB(24, 110, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: AppTextStyles.lightTextTheme.bodyLarge,
                    ),
                    Text(
                      authState.user?.displayName ?? 'Guest',
                      style: AppTextStyles.lightTextTheme.titleLarge,
                    ),
                    const SizedBox(height: 26),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search people, channels, or messages',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.tune_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final participant = highlightList[index];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppAvatar(
                                imageUrl: participant.avatarUrl,
                                initials: participant.displayName.isNotEmpty
                                    ? participant.displayName[0]
                                    : '?',
                                size: 58,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                participant.displayName,
                                style: AppTextStyles.lightTextTheme.bodyMedium,
                              ),
                            ],
                          );
                        },
                        separatorBuilder: (context, index) => const SizedBox(width: 16),
                        itemCount: highlightItemCount,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (chatState.isLoading && chatState.conversations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (chatState.errorMessage != null &&
                chatState.conversations.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    chatState.errorMessage!,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final conversation = chatState.conversations[index];
                    return Column(
                      children: [
                        ConversationTile(
                          conversation: conversation,
                          onTap: () async {
                            await chatNotifier.selectConversation(conversation.id);
                            if (context.mounted) {
                              context.push('/conversations/${conversation.id}');
                            }
                          },
                        ),
                        if (index != chatState.conversations.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Divider(),
                          ),
                      ],
                    );
                  },
                  childCount: chatState.conversations.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('New chat'),
      ),
    );
  }
}
