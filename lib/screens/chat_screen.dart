import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../features/auth/auth_controller.dart';
import '../features/chat/chat_controller.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../providers/app_providers.dart';
import '../theme/color_tokens.dart';
import '../utils/indian_time.dart';
import '../utils/phone_masking.dart';
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
    _scrollController.addListener(_onScroll);
    Future.microtask(
      () => ref
          .read(chatControllerProvider.notifier)
          .selectConversation(widget.conversationId),
    );
    Future.microtask(() async {
      try {
        const platform = MethodChannel('com.nuttgram.app/security');
        await platform.invokeMethod('setSecureMode', {'secure': true});
      } catch (_) {
        // Platform channels may fail on other platforms or old Android versions
      }
    });
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    Future.microtask(() async {
      try {
        const platform = MethodChannel('com.nuttgram.app/security');
        await platform.invokeMethod('setSecureMode', {'secure': false});
      } catch (_) {
        // Ignore errors during disposal
      }
    });
    super.dispose();
  }

  void _onScroll() {
    // Load more when scrolling near the top (older messages)
    if (_scrollController.position.pixels <= 100) {
      _loadMoreIfNeeded();
    }
  }

  Future<void> _loadMoreIfNeeded() async {
    final chatState = ref.read(chatControllerProvider);
    if (!chatState.isLoadingMore && chatState.hasMoreMessages) {
      await ref.read(chatControllerProvider.notifier).loadMoreMessages();
    }
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
                      itemCount: messageItems.length +
                          (chatState.hasMoreMessages ? 1 : 0),
                      itemBuilder: (context, index) {
                        final hasHistoryLoader = chatState.hasMoreMessages;
                        if (hasHistoryLoader && index == 0) {
                          // Show pagination loader at the top (oldest side)
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: chatState.isLoadingMore
                                  ? const CircularProgressIndicator()
                                  : const SizedBox.shrink(),
                            ),
                          );
                        }

                        final messageIndex =
                            hasHistoryLoader ? index - 1 : index;
                        final item = messageItems[messageIndex];
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
      final createdAtIndian = message.createdAtIndian;
      final messageDate = DateUtils.dateOnly(createdAtIndian);
      if (lastDate == null || !DateUtils.isSameDay(lastDate, messageDate)) {
        items.add(_MessageListItem.header(_formatDateLabel(createdAtIndian)));
        lastDate = messageDate;
      }
      items.add(_MessageListItem.message(message));
    }

    return items;
  }

  String _formatDateLabel(DateTime dateInIndia) {
    final now = indianNow();
    if (DateUtils.isSameDay(now, dateInIndia)) {
      return 'Today';
    }
    if (DateUtils.isSameDay(now.subtract(const Duration(days: 1)), dateInIndia)) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, yyyy').format(dateInIndia);
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
  late bool _isPrivate;
  late final Set<String> _existingParticipantIds;
  late List<UserProfile> _pendingRequests;
  final _memberSearchController = TextEditingController();
  final _memberResults = <UserProfile>[];
  final Map<String, UserProfile> _pendingMembers = {};
  final Set<String> _processingRequests = {};
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
    _isPrivate = widget.conversation.isPrivate;
    _pendingRequests = List<UserProfile>.from(widget.conversation.pendingJoinRequests);
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
    if (_isPrivate != widget.conversation.isPrivate) {
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

  Future<void> _openDirectChat(UserProfile user) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final conversation =
          await ref.read(chatControllerProvider.notifier).startConversationWith(
                user.id,
              );
      await ref
          .read(chatControllerProvider.notifier)
          .selectConversation(conversation.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      context.push('/conversations/${conversation.id}');
    } catch (error) {
      var message = 'Unable to start a chat right now.';
      if (error is DioException && error.message != null) {
        message = error.message!;
      }
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _handleJoinDecision(UserProfile user, bool approve) async {
    if (_processingRequests.contains(user.id)) {
      return;
    }

    setState(() {
      _processingRequests.add(user.id);
      _errorMessage = null;
    });

    try {
      await ref.read(chatControllerProvider.notifier).respondToJoinRequest(
            conversationId: widget.conversation.id,
            applicantId: user.id,
            approve: approve,
          );
      if (!mounted) return;
      setState(() {
        _pendingRequests.removeWhere((pending) => pending.id == user.id);
      });
    } catch (error) {
      var message = 'Unable to update the join request. Please try again.';
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
        _processingRequests.remove(user.id);
      });
    }
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
    final privacyChanged = _isPrivate != widget.conversation.isPrivate;

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

      if (privacyChanged) {
        await ref.read(chatControllerProvider.notifier).updateGroupPrivacy(
              conversationId: widget.conversation.id,
              isPrivate: _isPrivate,
            );
        if (!_isPrivate && mounted) {
          setState(() {
            _pendingRequests.clear();
          });
        }
      }
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

  Future<void> _shareInviteLink() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final link = await ref
          .read(chatControllerProvider.notifier)
          .generateInviteLink(widget.conversation.id);
      await Share.share('Join my group on Nuttgram: $link');
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Unable to share link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
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
                title: const Text('Private group'),
                subtitle: const Text('Requires approval before new members can join.'),
                value: _isPrivate,
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() {
                          _isPrivate = value;
                          _errorMessage = null;
                        }),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.share),
                title: const Text('Share invite link'),
                onTap: _shareInviteLink,
              ),
              if (_isPrivate) ...[
                const SizedBox(height: 8),
                _PendingRequestList(
                  requests: _pendingRequests,
                  processing: _processingRequests,
                  onAction: _handleJoinDecision,
                  onProfileTap: _openDirectChat,
                ),
                const SizedBox(height: 12),
              ],
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
                                    subtitle: Text(maskPhoneNumber(user.phoneNumber)),
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
      ),
    );
  }
}

typedef _JoinDecisionHandler = Future<void> Function(UserProfile profile, bool approve);

class _PendingRequestList extends StatelessWidget {
  const _PendingRequestList({
    required this.requests,
    required this.processing,
    required this.onAction,
    required this.onProfileTap,
  });

  final List<UserProfile> requests;
  final Set<String> processing;
  final _JoinDecisionHandler onAction;
  final void Function(UserProfile user) onProfileTap;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'No pending join requests.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending join requests',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...requests.map((user) {
          final isBusy = processing.contains(user.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => onProfileTap(user),
                    child: Row(
                      children: [
                        AppAvatar(
                          imageUrl: user.avatarUrl,
                          initials: user.displayName.isNotEmpty
                              ? user.displayName[0]
                              : '?',
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                maskPhoneNumber(user.phoneNumber),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isBusy ? null : () => onAction(user, false),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isBusy ? null : () => onAction(user, true),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
