import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/chat/chat_controller.dart';
import '../models/conversation.dart';
import '../models/user.dart';
import '../providers/app_providers.dart';
import '../theme/color_tokens.dart';
import '../theme/text_styles.dart';
import '../utils/phone_masking.dart';
import '../widgets/app_avatar.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/primary_button.dart';

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _groupSearchDebounce;
  bool _isSearchingGroups = false;
  String? _groupSearchError;
  List<ConversationSummary> _joinableGroups = [];
  final Set<String> _joiningGroupIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    _groupSearchDebounce?.cancel();
    super.dispose();
  }

  List<ConversationSummary> _filterConversations(
    List<ConversationSummary> conversations,
    String? currentUserId,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return conversations;
    }

    final numericQuery = query.replaceAll(RegExp(r'[^0-9]'), '');

    return conversations.where((conversation) {
      final titleMatches =
          conversation.titleFor(currentUserId).toLowerCase().contains(query);
      final participantMatches = conversation.participants.any((participant) {
        final nameMatch = participant.displayName.toLowerCase().contains(query);
        final phoneMatch = numericQuery.isNotEmpty &&
            participant.phoneNumber.contains(numericQuery);
        return nameMatch || phoneMatch;
      });
      final messageMatches =
          conversation.lastMessage?.body.toLowerCase().contains(query) ?? false;

      return titleMatches || participantMatches || messageMatches;
    }).toList();
  }

  Future<void> _openActionSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Start direct chat'),
                onTap: () => Navigator.of(context).pop('chat'),
              ),
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('Create private group'),
                onTap: () => Navigator.of(context).pop('group'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) {
      return;
    }

    if (choice == 'chat') {
      await _openNewChatSheet();
    } else if (choice == 'group') {
      await _openNewGroupSheet();
    }
  }

  Future<void> _openNewChatSheet() async {
    final conversationId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const _NewChatSheet(),
        );
      },
    );

    if (conversationId == null) {
      return;
    }

    await ref
        .read(chatControllerProvider.notifier)
        .selectConversation(conversationId);
    if (!mounted) return;
    context.push('/conversations/$conversationId');
  }

  Future<void> _openNewGroupSheet() async {
    final conversationId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const _NewGroupSheet(),
        );
      },
    );

    if (conversationId == null) {
      return;
    }

    await ref
        .read(chatControllerProvider.notifier)
        .selectConversation(conversationId);
    if (!mounted) return;
    context.push('/conversations/$conversationId');
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _scheduleGroupSearch(value);
  }

  void _scheduleGroupSearch(String rawQuery) {
    _groupSearchDebounce?.cancel();
    final trimmed = rawQuery.trim();

    if (trimmed.length < 2) {
      if (_joinableGroups.isEmpty && _groupSearchError == null && !_isSearchingGroups) {
        return;
      }
      setState(() {
        _joinableGroups = [];
        _groupSearchError = null;
        _isSearchingGroups = false;
      });
      return;
    }

    _groupSearchDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _isSearchingGroups = true;
        _groupSearchError = null;
      });

      try {
        final results = await ref
            .read(chatControllerProvider.notifier)
            .searchJoinableGroups(trimmed);
        if (!mounted) return;
        setState(() {
          _joinableGroups = results;
          _isSearchingGroups = false;
        });
      } catch (error) {
        if (!mounted) return;
        var message = 'Unable to search groups right now.';
        if (error is DioException && error.message != null) {
          message = error.message!;
        }
        setState(() {
          _groupSearchError = message;
          _isSearchingGroups = false;
        });
      }
    });
  }

  Future<void> _handleQuickChat(UserProfile participant) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final existing = _findDirectConversation(participant.id);
    final controller = ref.read(chatControllerProvider.notifier);

    try {
      final conversation = existing ??
          await controller.startConversationWith(participant.id);
      await controller.selectConversation(conversation.id);
      if (!mounted) return;
      context.push('/conversations/${conversation.id}');
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Unable to open this chat. Please try again.'),
        ),
      );
    }
  }

  ConversationSummary? _findDirectConversation(String participantId) {
    for (final conversation in ref.read(chatControllerProvider).conversations) {
      if (conversation.isGroup) {
        continue;
      }
      final matches = conversation.participants
          .any((participant) => participant.id == participantId);
      if (matches) {
        return conversation;
      }
    }
    return null;
  }

  Widget _buildGroupSearchResults() {
    if (_isSearchingGroups) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_groupSearchError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          _groupSearchError!,
          style: const TextStyle(color: AppColors.danger),
        ),
      );
    }

    if (_joinableGroups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No groups found for "${_searchQuery.trim()}".',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Column(
      children: _joinableGroups
          .map(
            (conversation) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: AppAvatar(
                  imageUrl: conversation.participants.isNotEmpty
                      ? conversation.participants.first.avatarUrl
                      : null,
                  initials: conversation.displayTitle.isNotEmpty
                      ? conversation.displayTitle[0]
                      : '?',
                ),
                title: Text(conversation.displayTitle),
                subtitle: Text(
                  conversation.isPrivate ? 'Private group' : 'Public group',
                  style: TextStyle(
                    color: conversation.isPrivate
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                ),
                trailing: ElevatedButton(
                  onPressed: _joiningGroupIds.contains(conversation.id)
                      ? null
                      : () => _handleJoinGroup(conversation),
                  child: Text(conversation.isPrivate ? 'Request' : 'Join'),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _handleJoinGroup(ConversationSummary conversation) async {
    if (_joiningGroupIds.contains(conversation.id)) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _joiningGroupIds.add(conversation.id);
    });

    try {
      final joinedConversation = await ref
          .read(chatControllerProvider.notifier)
          .requestToJoinGroup(conversation.id);
      if (!mounted) return;
      String message;
      if (joinedConversation != null) {
        message = 'Joined ${joinedConversation.displayTitle}.';
        await ref
            .read(chatControllerProvider.notifier)
            .selectConversation(joinedConversation.id);
        context.push('/conversations/${joinedConversation.id}');
      } else {
        message = conversation.isPrivate
            ? 'Request sent to group admins.'
            : 'Join request sent.';
      }
      messenger?.showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _joinableGroups =
            _joinableGroups.where((item) => item.id != conversation.id).toList();
      });
    } catch (error) {
      var message = 'Unable to join this group right now.';
      if (error is DioException && error.message != null) {
        message = error.message!;
      }
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (!mounted) return;
      setState(() {
        _joiningGroupIds.remove(conversation.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final chatState = ref.watch(chatControllerProvider);

    final currentUserId = authState.user?.id;
    final conversations =
        _filterConversations(chatState.conversations, currentUserId);
    final isSearching = _searchQuery.trim().isNotEmpty;

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
    final highlightItemCount =
        highlightList.length > 6 ? 6 : highlightList.length;

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
          await ref.read(chatControllerProvider.notifier).loadConversations();
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
                      controller: _searchController,
                      onChanged: _handleSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search people, channels, or messages',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _handleSearchChanged('');
                                },
                                icon: const Icon(Icons.close_rounded),
                              )
                            : IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.tune_outlined),
                              ),
                      ),
                    ),
                    if (isSearching) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Discover groups',
                        style: AppTextStyles.lightTextTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildGroupSearchResults(),
                    ] else if (highlightList.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (context, index) {
                            final participant = highlightList[index];
                            return InkWell(
                              onTap: () => _handleQuickChat(participant),
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: 80,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppAvatar(
                                      imageUrl: participant.avatarUrl,
                                      initials:
                                          participant.displayName.isNotEmpty
                                              ? participant.displayName[0]
                                              : '?',
                                      size: 58,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      participant.displayName,
                                      style: AppTextStyles
                                          .lightTextTheme.bodyMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 16),
                          itemCount: highlightItemCount,
                        ),
                      ),
                    ],
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
            else if (conversations.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    isSearching
                        ? 'No conversations match "${_searchQuery.trim()}".'
                        : 'Start a conversation to begin chatting.',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final conversation = conversations[index];
                    return Column(
                      children: [
                        ConversationTile(
                          conversation: conversation,
                          currentUserId: currentUserId,
                          onTap: () async {
                            await ref
                                .read(chatControllerProvider.notifier)
                                .selectConversation(conversation.id);
                            if (!mounted) return;
                            context.push('/conversations/${conversation.id}');
                          },
                        ),
                        if (index != conversations.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Divider(),
                          ),
                      ],
                    );
                  },
                  childCount: conversations.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openActionSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('New conversation'),
      ),
    );
  }
}

class _NewChatSheet extends ConsumerStatefulWidget {
  const _NewChatSheet();

  @override
  ConsumerState<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewGroupSheet extends ConsumerStatefulWidget {
  const _NewGroupSheet();

  @override
  ConsumerState<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _NewGroupSheetState extends ConsumerState<_NewGroupSheet> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _results = <UserProfile>[];
  final Map<String, UserProfile> _selected = {};
  Timer? _debounce;
  bool _isPrivate = true;
  bool _isSearching = false;
  bool _isCreating = false;
  String? _errorMessage;

  bool get _canCreate =>
      _nameController.text.trim().length >= 3 &&
      _selected.isNotEmpty &&
      !_isCreating;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _errorMessage = null;
    });

    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() {
        _results.clear();
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _isSearching = true;
      });

      try {
        final repository = ref.read(userRepositoryProvider);
        final matches = await repository.searchUsers(trimmed);
        if (!mounted) return;
        setState(() {
          _results
            ..clear()
            ..addAll(matches);
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Unable to search right now. Try again shortly.';
        });
      } finally {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  void _toggleSelection(UserProfile user) {
    if (_isCreating) return;
    setState(() {
      if (_selected.containsKey(user.id)) {
        _selected.remove(user.id);
      } else {
        _selected[user.id] = user;
      }
    });
  }

  void _removeSelection(String userId) {
    if (_isCreating) return;
    setState(() {
      _selected.remove(userId);
    });
  }

  Future<void> _createGroup() async {
    if (!_canCreate) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final conversation =
          await ref.read(chatControllerProvider.notifier).createGroup(
                name: _nameController.text.trim(),
                participantIds: _selected.keys.toList(),
                isPrivate: _isPrivate,
              );
      if (!mounted) return;
      Navigator.of(context).pop(conversation.id);
    } catch (error) {
      String message =
          'We could not create this group. Please try again in a moment.';
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
        _isCreating = false;
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
                  'Create private group',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Group name',
                hintText: 'Marketing standup',
              ),
              onChanged: (_) => setState(() {}),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private group'),
              subtitle: const Text(
                  'Only members and invited users can see this group.'),
              value: _isPrivate,
              onChanged: (value) {
                if (_isCreating) return;
                setState(() => _isPrivate = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search members to add',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 12),
            if (_selected.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selected.values
                    .map(
                      (user) => InputChip(
                        avatar: CircleAvatar(
                          child: Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?',
                          ),
                        ),
                        label: Text(user.displayName),
                        onDeleted: () => _removeSelection(user.id),
                      ),
                    )
                    .toList(),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: _searchController.text.trim().length < 2 &&
                      _results.isEmpty
                  ? Center(
                      child: Text(
                        'Type at least two characters to find teammates.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                'No matches yet. Try a different name or number.',
                                style: TextStyle(color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              itemCount: _results.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 0),
                              itemBuilder: (context, index) {
                                final user = _results[index];
                                final isSelected =
                                    _selected.containsKey(user.id);
                                return ListTile(
                                  leading: AppAvatar(
                                    imageUrl: user.avatarUrl,
                                    initials: user.displayName.isNotEmpty
                                        ? user.displayName[0]
                                        : '?',
                                  ),
                                  title: Text(user.displayName),
                                  subtitle: Text(maskPhoneNumber(user.phoneNumber)),
                                  trailing: Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.add_circle_outline,
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.grey.shade500,
                                  ),
                                  onTap: () => _toggleSelection(user),
                                );
                              },
                            ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Create group',
              onPressed: _canCreate ? _createGroup : null,
              isLoading: _isCreating,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewChatSheetState extends ConsumerState<_NewChatSheet> {
  final _controller = TextEditingController();
  final _results = <UserProfile>[];
  Timer? _debounce;
  bool _isSearching = false;
  bool _isCreating = false;
  String? _pendingUserId;
  String? _errorMessage;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _errorMessage = null;
    });

    final trimmed = value.trim();
    if (trimmed.length < 2) {
      setState(() {
        _results.clear();
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _isSearching = true;
      });

      try {
        final repository = ref.read(userRepositoryProvider);
        final matches = await repository.searchUsers(trimmed);
        if (!mounted) return;
        setState(() {
          _results
            ..clear()
            ..addAll(matches);
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Unable to search right now. Try again shortly.';
        });
      } finally {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _startConversation(UserProfile user) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isCreating = true;
      _pendingUserId = user.id;
      _errorMessage = null;
    });

    try {
      final chatController = ref.read(chatControllerProvider.notifier);
      final conversation = await chatController.startConversationWith(user.id);
      if (!mounted) return;
      Navigator.of(context).pop(conversation.id);
    } catch (error) {
      String message =
          'We could not start the chat. Please try again in a moment.';

      if (error is DioException) {
        message = error.response?.data is Map &&
                (error.response!.data as Map)['message'] is String
            ? (error.response!.data as Map)['message'] as String
            : error.message ?? message;
      } else if (error is Exception) {
        message = error.toString().replaceFirst('Exception: ', '');
      } else if (error is Error) {
        message = error.toString();
      }

      if (!mounted) return;
      setState(() {
        _errorMessage = message;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _pendingUserId = null;
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
                  'Start a new chat',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search by name or phone number',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            SizedBox(
              height: 320,
              child: _controller.text.trim().length < 2 && _results.isEmpty
                  ? Center(
                      child: Text(
                        'Type at least two characters to search your workspace.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                'No people found. Ask them to sign in first!',
                                style: TextStyle(color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.separated(
                              itemCount: _results.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 0),
                              itemBuilder: (context, index) {
                                final user = _results[index];
                                final isPending =
                                    _isCreating && _pendingUserId == user.id;
                                return ListTile(
                                  leading: AppAvatar(
                                    imageUrl: user.avatarUrl,
                                    initials: user.displayName.isNotEmpty
                                        ? user.displayName[0]
                                        : '?',
                                  ),
                                  title: Text(user.displayName),
                                  subtitle: Text(maskPhoneNumber(user.phoneNumber)),
                                  trailing: isPending
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.arrow_forward_ios,
                                          size: 16),
                                  onTap: isPending
                                      ? null
                                      : () => _startConversation(user),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
