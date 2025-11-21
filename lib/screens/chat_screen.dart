import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../features/auth/auth_controller.dart';
import '../features/chat/chat_controller.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../providers/app_providers.dart';
import '../theme/color_tokens.dart';
import '../widgets/app_avatar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';
import '../widgets/primary_button.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(chatControllerProvider.notifier)
          .selectConversation(widget.conversationId),
    );
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      Future.microtask(
        () => ref
            .read(chatControllerProvider.notifier)
            .selectConversation(widget.conversationId),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text, List<String> attachments) async {
    try {
      await ref.read(chatControllerProvider.notifier).sendMessage(
            text,
            attachments: attachments,
          );
    } finally {
      _scrollToBottom();
    }
  }

  Future<void> _openGroupManagement() async {
    final conversation = ref.read(chatControllerProvider).activeConversation;
    final auth = ref.read(authControllerProvider);
    final currentUserId = auth.user?.id;

    if (conversation == null || currentUserId == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _GroupManagementSheet(
            conversation: conversation,
            currentUserId: currentUserId,
          ),
        );
      },
    );
  }

  Future<void> _confirmLeaveGroup() async {
    final conversation = ref.read(chatControllerProvider).activeConversation;
    if (conversation == null) {
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text(
            'You will stop receiving messages from this group unless re-added.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave != true) {
      return;
    }

    setState(() {
      _isLeaving = true;
    });

    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      await ref.read(chatControllerProvider.notifier).leaveConversation();
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/conversations');
      }
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Unable to leave the group right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLeaving = false;
        });
      }
    }
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
    final authState = ref.watch(authControllerProvider);
    final conversation = chatState.activeConversation;
    final currentUserId = authState.user?.id;

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final displayTitle = conversation?.titleFor(currentUserId) ?? '';
    final primaryParticipant =
        conversation?.participantForDisplay(currentUserId);
    final isGroup = conversation?.isGroup == true;
    final isAdmin = conversation != null &&
        currentUserId != null &&
        (conversation.createdBy == currentUserId ||
            conversation.adminIds.contains(currentUserId));
    final adminOnlyMessaging = conversation?.adminOnlyMessaging ?? false;
    final canSend = conversation == null || !adminOnlyMessaging || isAdmin;
    final messageItems = _buildMessageTimeline(chatState.messages);

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
                        displayTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 18),
                      ),
                      Text(
                        '${conversation.participants.length} participants',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
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
          if (conversation != null && isGroup)
            PopupMenuButton<String>(
              enabled: !_isLeaving,
              icon: _isLeaving
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'manage') {
                  _openGroupManagement();
                } else if (value == 'leave') {
                  _confirmLeaveGroup();
                }
              },
              itemBuilder: (context) {
                final entries = <PopupMenuEntry<String>>[];
                if (isAdmin) {
                  entries.add(const PopupMenuItem(
                    value: 'manage',
                    child: Text('Manage group'),
                  ));
                }
                entries.add(const PopupMenuItem(
                  value: 'leave',
                  child: Text('Leave group'),
                ));
                return entries;
              },
            )
          else
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      itemCount: messageItems.length,
                      itemBuilder: (context, index) {
                        final item = messageItems[index];
                        if (item.isHeader) {
                          return _DateDivider(label: item.label!);
                        }
                        return MessageBubble(message: item.message!);
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
          if (conversation != null && adminOnlyMessaging && !isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Only admins can send messages in this conversation right now.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          MessageInputBar(
            onSend: _send,
            isSending: chatState.isSending,
            isEnabled: canSend,
          ),
        ],
      ),
    );
  }

  List<_MessageListItem> _buildMessageTimeline(List<Message> messages) {
    final items = <_MessageListItem>[];
    DateTime? lastDate;

    for (final message in messages) {
      final messageDate = DateUtils.dateOnly(message.createdAt);
      if (lastDate == null || !DateUtils.isSameDay(lastDate, messageDate)) {
        items.add(_MessageListItem.header(_formatDateLabel(message.createdAt)));
        lastDate = messageDate;
      }
      items.add(_MessageListItem.message(message));
    }

    return items;
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(now, date)) {
      return 'Today';
    }
    if (DateUtils.isSameDay(now.subtract(const Duration(days: 1)), date)) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, yyyy').format(date);
  }
}

class _MessageListItem {
  const _MessageListItem.header(this.label)
      : message = null,
        isHeader = true;
  const _MessageListItem.message(this.message)
      : label = null,
        isHeader = false;

  final String? label;
  final Message? message;
  final bool isHeader;
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.grey.shade400,
              thickness: 0.6,
              endIndent: 12,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.grey.shade400,
              thickness: 0.6,
              indent: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupManagementSheet extends ConsumerStatefulWidget {
  const _GroupManagementSheet({
    required this.conversation,
    required this.currentUserId,
  });

  final ConversationSummary conversation;
  final String currentUserId;

  @override
  ConsumerState<_GroupManagementSheet> createState() =>
      _GroupManagementSheetState();
}

class _GroupManagementSheetState extends ConsumerState<_GroupManagementSheet> {
  late final Set<String> _initialAdmins;
  late Set<String> _admins;
  late bool _adminOnly;
  late final Set<String> _existingParticipantIds;
  final _memberSearchController = TextEditingController();
  final _memberResults = <UserProfile>[];
  final Map<String, UserProfile> _pendingMembers = {};
  Timer? _memberDebounce;
  bool _isSearchingMembers = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialAdmins = {
      ...widget.conversation.adminIds,
      widget.conversation.createdBy,
    };
    _admins = {..._initialAdmins};
    _adminOnly = widget.conversation.adminOnlyMessaging;
    _existingParticipantIds =
        widget.conversation.participants.map((user) => user.id).toSet();
  }

  @override
  void dispose() {
    _memberDebounce?.cancel();
    _memberSearchController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    if (_adminOnly != widget.conversation.adminOnlyMessaging) {
      return true;
    }
    if (_admins.length != _initialAdmins.length) {
      return true;
    }
    if (_admins.difference(_initialAdmins).isNotEmpty) {
      return true;
    }
    if (_initialAdmins.difference(_admins).isNotEmpty) {
      return true;
    }
    if (_pendingMembers.isNotEmpty) {
      return true;
    }
    return false;
  }

  void _toggleAdmin(String userId, bool value) {
    if (_isSaving || userId == widget.conversation.createdBy) {
      return;
    }
    setState(() {
      _errorMessage = null;
      if (value) {
        _admins.add(userId);
      } else {
        _admins.remove(userId);
      }
    });
  }

  void _onMemberQueryChanged(String value) {
    _memberDebounce?.cancel();
    setState(() {
      _errorMessage = null;
    });

    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() {
        _memberResults.clear();
        _isSearchingMembers = false;
      });
      return;
    }

    _memberDebounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _isSearchingMembers = true;
      });

      try {
        final repository = ref.read(userRepositoryProvider);
        final matches = await repository.searchUsers(trimmed);
        if (!mounted) return;
        setState(() {
          _memberResults
            ..clear()
            ..addAll(matches.where((user) =>
                !_existingParticipantIds.contains(user.id) &&
                !_pendingMembers.containsKey(user.id)));
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Unable to search right now. Try again shortly.';
        });
      } finally {
        if (!mounted) return;
        setState(() {
          _isSearchingMembers = false;
        });
      }
    });
  }

  void _addPendingMember(UserProfile user) {
    if (_isSaving) {
      return;
    }
    setState(() {
      _pendingMembers[user.id] = user;
      _memberResults.removeWhere((candidate) => candidate.id == user.id);
      _errorMessage = null;
    });
  }

  void _removePendingMember(String userId) {
    if (_isSaving) {
      return;
    }
    setState(() {
      _pendingMembers.remove(userId);
    });
  }

  Future<void> _save() async {
    if (_isSaving || !_hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    final newMemberIds = _pendingMembers.keys.toList();
    final adds = _admins.difference(_initialAdmins).toList();
    final removes = _initialAdmins
        .difference(_admins)
        .where((id) => id != widget.conversation.createdBy)
        .toList();
    final adminOnlyChanged =
        _adminOnly != widget.conversation.adminOnlyMessaging;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (newMemberIds.isNotEmpty) {
        await ref.read(chatControllerProvider.notifier).addParticipants(
              conversationId: widget.conversation.id,
              participantIds: newMemberIds,
            );
        _existingParticipantIds.addAll(newMemberIds);
        _pendingMembers.clear();
        _memberSearchController.clear();
        _memberResults.clear();
      }

      await ref.read(chatControllerProvider.notifier).updateGroupAdminSettings(
            conversationId: widget.conversation.id,
            addAdminIds: adds,
            removeAdminIds: removes,
            adminOnlyMessaging: adminOnlyChanged ? _adminOnly : null,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      String message =
          'We could not update the group. Please try again shortly.';
      if (error is DioException) {
        message = error.response?.data is Map &&
                (error.response!.data as Map)['message'] is String
            ? (error.response!.data as Map)['message'] as String
            : error.message ?? message;
      } else if (error is Exception) {
        message = error.toString().replaceFirst('Exception: ', '');
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = message;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Group settings',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed:
                      _isSaving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Admins only mode'),
              subtitle: const Text(
                  'When enabled, only admins can send or edit messages.'),
              value: _adminOnly,
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() {
                        _adminOnly = value;
                        _errorMessage = null;
                      }),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _memberSearchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search people to add',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onMemberQueryChanged,
            ),
            if (_pendingMembers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _pendingMembers.values
                      .map(
                        (user) => InputChip(
                          avatar: CircleAvatar(
                            child: Text(
                              user.displayName.isNotEmpty
                                  ? user.displayName[0]
                                  : '?',
                            ),
                          ),
                          label: Text(user.displayName),
                          onDeleted: () => _removePendingMember(user.id),
                        ),
                      )
                      .toList(),
                ),
              ),
            SizedBox(
              height: 160,
              child: _memberSearchController.text.trim().length < 2 &&
                      _memberResults.isEmpty
                  ? const SizedBox.shrink()
                  : _isSearchingMembers
                      ? const Center(child: CircularProgressIndicator())
                      : _memberResults.isEmpty
                          ? Center(
                              child: Text(
                                'No users found. Try a different name or number.',
                                style: TextStyle(color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              itemCount: _memberResults.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 0),
                              itemBuilder: (context, index) {
                                final user = _memberResults[index];
                                return ListTile(
                                  leading: AppAvatar(
                                    imageUrl: user.avatarUrl,
                                    initials: user.displayName.isNotEmpty
                                        ? user.displayName[0]
                                        : '?',
                                  ),
                                  title: Text(user.displayName),
                                  subtitle: Text(user.phoneNumber),
                                  trailing: const Icon(Icons.person_add_alt),
                                  onTap: () => _addPendingMember(user),
                                );
                              },
                            ),
            ),
            const Divider(height: 24),
            SizedBox(
              height: 280,
              child: ListView.separated(
                itemCount: widget.conversation.participants.length,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (context, index) {
                  final user = widget.conversation.participants[index];
                  final isCreator = user.id == widget.conversation.createdBy;
                  final isAdmin = _admins.contains(user.id);
                  final labels = <String>[];
                  labels.add(user.phoneNumber);
                  if (user.id == widget.currentUserId) {
                    labels.add('You');
                  }
                  if (isCreator) {
                    labels.add('Creator');
                  }

                  return SwitchListTile.adaptive(
                    secondary: AppAvatar(
                      imageUrl: user.avatarUrl,
                      initials: user.displayName.isNotEmpty
                          ? user.displayName[0]
                          : '?',
                    ),
                    title: Text(user.displayName),
                    subtitle: Text(labels.join(' • ')),
                    value: isAdmin,
                    onChanged: (isCreator || _isSaving)
                        ? null
                        : (value) => _toggleAdmin(user.id, value),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Save changes',
              onPressed: (!_hasChanges || _isSaving) ? null : _save,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }
}
