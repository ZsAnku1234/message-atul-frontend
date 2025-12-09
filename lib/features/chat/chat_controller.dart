import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../providers/app_providers.dart';
import '../../services/chat_repository.dart';
import '../../services/socket_service.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'chat_state.dart';

class ChatController extends StateNotifier<ChatState> {
  ChatController(
    this._ref,
    this._repository,
    this._socketService,
  ) : super(const ChatState()) {
    _authSubscription = _ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        if (next.isAuthenticated) {
          unawaited(_handleAuthenticated(next));
        } else if (previous?.isAuthenticated == true && !next.isAuthenticated) {
          _handleSignOut();
        }
      },
      fireImmediately: true,
    );
  }

  final Ref _ref;
  final ChatRepository _repository;
  final SocketService _socketService;

  late final ProviderSubscription<AuthState> _authSubscription;
  StreamSubscription<ChatSocketEvent>? _socketSubscription;
  String? _joinedConversationId;

  @override
  void dispose() {
    _authSubscription.close();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    unawaited(_socketService.disconnect());
    super.dispose();
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final conversations = await _repository.fetchConversations();

      state = state.copyWith(
        conversations: _sortConversations(conversations),
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapError(error),
      );
    }
  }

  Future<void> selectConversation(String conversationId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final previousId = state.activeConversation?.id;

    try {
      // Use pagination endpoint for messages
      final page = await _repository.fetchMessages(
        conversationId: conversationId,
        limit: 30, // Initial load
      );
      
      // Still need conversation details
      final result = await _repository.fetchConversationDetail(conversationId);
      final conversation = result.$1;
      final messages = _decorateMessages(page.messages);
      final normalizedConversation = conversation.copyWith(unreadCount: 0);
      final updatedList = _sortConversations([
        ...state.conversations
            .where((item) => item.id != normalizedConversation.id),
        normalizedConversation,
      ]);

      state = state.copyWith(
        conversations: updatedList,
        activeConversation: normalizedConversation,
        messages: messages,
        hasMoreMessages: page.hasMore,
        messagesCursor: page.nextCursor,
        isLoading: false,
        clearError: true,
      );
      _switchConversationRoom(previousId, conversation.id);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapError(error),
      );
    }
  }

  Future<void> loadMoreMessages() async {
    if (state.isLoadingMore || !state.hasMoreMessages) {
      return;
    }

    final conversationId = state.activeConversation?.id;
    if (conversationId == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final page = await _repository.fetchMessages(
        conversationId: conversationId,
        before: state.messagesCursor,
        limit: 50,
      );

      final decoratedMessages = _decorateMessages(page.messages);
      
      // Prepend older messages (they come in reverse chronological order)
      final allMessages = [...decoratedMessages, ...state.messages];

      state = state.copyWith(
        messages: allMessages,
        hasMoreMessages: page.hasMore,
        messagesCursor: page.nextCursor,
        isLoadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: _mapError(error),
      );
    }
  }

  Future<void> sendMessage(String content,
      {List<String> attachments = const []}) async {
    final activeConversation = state.activeConversation;
    final currentUser = _ref.read(authControllerProvider).user;

    if (activeConversation == null || currentUser == null) {
      return;
    }

    state = state.copyWith(isSending: true, clearError: true);

    final optimistic = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      conversationId: activeConversation.id,
      sender: currentUser,
      body: content,
      createdAt: DateTime.now(),
      attachments: attachments,
      isMine: true,
    );

    state = state.copyWith(
      messages: [...state.messages, optimistic],
    );

    try {
      final delivered = await _repository.sendMessage(
        conversationId: activeConversation.id,
        content: content,
        attachments: attachments,
      );

      final mapped = delivered.copyWith(isMine: true);
      final messages = [
        ...state.messages.where((message) =>
            message.id != optimistic.id && message.id != mapped.id),
        mapped,
      ];

      state = state.copyWith(
        messages: messages,
        conversations: _applyMessageToConversations(
          state.conversations,
          mapped,
          isActiveConversation: true,
        ),
        isSending: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        messages: state.messages
            .where((message) => message.id != optimistic.id)
            .toList(),
        isSending: false,
        errorMessage: _mapError(error),
      );
    }
  }

  void reset() {
    _joinedConversationId = null;
    state = const ChatState();
  }

  void _upsertConversation(ConversationSummary conversation) {
    final isActive = state.activeConversation?.id == conversation.id;
    final updatedList = [
      ...state.conversations.where((item) => item.id != conversation.id),
      conversation,
    ];

    state = state.copyWith(
      conversations: _sortConversations(updatedList),
      activeConversation: isActive ? conversation : state.activeConversation,
      clearError: true,
    );
  }

  Future<ConversationSummary> startConversationWith(
      String participantId) async {
    try {
      final conversation = await _repository.createConversation(
        participantIds: [participantId],
      );
      _upsertConversation(conversation);

      return conversation;
    } catch (error) {
      state = state.copyWith(
        errorMessage: _mapError(error),
      );
      rethrow;
    }
  }

  Future<ConversationSummary> createGroup({
    required String name,
    required List<String> participantIds,
    bool isPrivate = true,
  }) async {
    try {
      final conversation = await _repository.createConversation(
        participantIds: participantIds,
        title: name,
        isPrivate: isPrivate,
      );
      _upsertConversation(conversation);

      return conversation;
    } catch (error) {
      state = state.copyWith(
        errorMessage: _mapError(error),
      );
      rethrow;
    }
  }

  Future<void> updateGroupAdminSettings({
    required String conversationId,
    List<String> addAdminIds = const [],
    List<String> removeAdminIds = const [],
    bool? adminOnlyMessaging,
  }) async {
    try {
      if (addAdminIds.isEmpty &&
          removeAdminIds.isEmpty &&
          adminOnlyMessaging == null) {
        return;
      }

      if (addAdminIds.isNotEmpty || removeAdminIds.isNotEmpty) {
        final conversation = await _repository.updateAdmins(
          conversationId: conversationId,
          add: addAdminIds,
          remove: removeAdminIds,
        );
        _upsertConversation(conversation);
      }

      if (adminOnlyMessaging != null) {
        final conversation = await _repository.setAdminOnlyMessaging(
          conversationId: conversationId,
          adminOnlyMessaging: adminOnlyMessaging,
        );
        _upsertConversation(conversation);
      }
    } catch (error) {
      state = state.copyWith(
        errorMessage: _mapError(error),
      );
      rethrow;
    }
  }

  Future<ConversationSummary> addParticipants({
    required String conversationId,
    required List<String> participantIds,
  }) async {
    try {
      final conversation = await _repository.addParticipants(
        conversationId: conversationId,
        participantIds: participantIds,
      );
      _upsertConversation(conversation);
      return conversation;
    } catch (error) {
      state = state.copyWith(
        errorMessage: _mapError(error),
      );
      rethrow;
    }
  }

  Future<void> updateGroupPrivacy({
    required String conversationId,
    required bool isPrivate,
  }) async {
    try {
      final conversation = await _repository.updateConversation(
        conversationId: conversationId,
        isPrivate: isPrivate,
      );
      _upsertConversation(conversation);
    } catch (error) {
      state = state.copyWith(errorMessage: _mapError(error));
      rethrow;
    }
  }

  Future<void> respondToJoinRequest({
    required String conversationId,
    required String applicantId,
    required bool approve,
  }) async {
    try {
      final conversation = await _repository.respondToJoinRequest(
        conversationId: conversationId,
        applicantId: applicantId,
        approve: approve,
      );
      _upsertConversation(conversation);
    } catch (error) {
      state = state.copyWith(errorMessage: _mapError(error));
      rethrow;
    }
  }

  Future<ConversationSummary?> requestToJoinGroup(String conversationId) async {
    try {
      final conversation = await _repository.requestToJoinGroup(conversationId);
      if (conversation != null) {
        _upsertConversation(conversation);
      }
      return conversation;
    } catch (error) {
      state = state.copyWith(errorMessage: _mapError(error));
      rethrow;
    }
  }

  Future<List<ConversationSummary>> searchJoinableGroups(String query) async {
    try {
      return await _repository.searchGroups(query);
    } catch (error) {
      state = state.copyWith(errorMessage: _mapError(error));
      rethrow;
    }
  }

  Future<void> _handleAuthenticated(AuthState authState) async {
    if (!authState.isAuthenticated) {
      return;
    }

    _socketSubscription?.cancel();
    _socketSubscription = _socketService.events.listen(_handleSocketEvent);
    await _socketService.connect();
    await loadConversations();
  }

  void _handleSignOut() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _joinedConversationId = null;
    unawaited(_socketService.disconnect());
    reset();
  }

  void _switchConversationRoom(String? previousId, String nextId) {
    final currentRoom = _joinedConversationId;

    if (currentRoom != null && currentRoom != nextId) {
      unawaited(_socketService.leaveConversation(currentRoom));
    } else if (previousId != null && previousId != nextId) {
      unawaited(_socketService.leaveConversation(previousId));
    }

    _joinedConversationId = nextId;
    unawaited(_socketService.joinConversation(nextId));
  }

  void _handleSocketEvent(ChatSocketEvent event) {
    if (event is ChatSocketMessageReceived) {
      _handleIncomingMessage(event.message);
      return;
    }
    if (event is ChatSocketMessageUpdated) {
      _handleUpdatedMessage(event.message);
      return;
    }
    if (event is ChatSocketMessageDeleted) {
      _handleDeletedMessage(event.messageId, event.conversationId);
      return;
    }
    if (event is ChatSocketConversationUpdated) {
      _upsertConversation(event.conversation);
      return;
    }
    if (event is ChatSocketConversationAdded) {
      _upsertConversation(event.conversation);
      return;
    }
    if (event is ChatSocketConversationRemoved) {
      _handleConversationRemoval(event.conversationId);
      return;
    }
    if (event is ChatSocketConversationDeleted) {
      _handleConversationRemoval(event.conversationId);
    }
  }

  void _handleIncomingMessage(Message incoming) {
    final message = _decorateMessage(incoming);
    final isActive = state.activeConversation?.id == message.conversationId;

    var messages = state.messages;
    var activeConversation = state.activeConversation;

    if (isActive) {
      final updated =
          state.messages.where((existing) => existing.id != message.id).toList()
            ..add(message)
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      messages = updated;
      if (activeConversation != null) {
        activeConversation = activeConversation.copyWith(
          lastMessage: message,
          lastActivity: message.createdAt,
        );
      }
    }

    final conversations = _applyMessageToConversations(
      state.conversations,
      message,
      isActiveConversation: isActive,
    );

    state = state.copyWith(
      messages: messages,
      conversations: conversations,
      activeConversation: activeConversation,
    );
  }

  void _handleUpdatedMessage(Message incoming) {
    final message = _decorateMessage(incoming);
    final isActive = state.activeConversation?.id == message.conversationId;

    var messages = state.messages;
    var activeConversation = state.activeConversation;

    if (isActive) {
      messages = state.messages
          .map((existing) => existing.id == message.id ? message : existing)
          .toList();
      if (activeConversation?.lastMessage?.id == message.id) {
        activeConversation = activeConversation?.copyWith(lastMessage: message);
      }
    }

    final conversations = state.conversations.map((conversation) {
      if (conversation.id != message.conversationId) {
        return conversation;
      }
      if (conversation.lastMessage?.id != message.id) {
        return conversation;
      }
      return conversation.copyWith(lastMessage: message);
    }).toList();

    state = state.copyWith(
      messages: messages,
      conversations: conversations,
      activeConversation: activeConversation,
    );
  }

  void _handleDeletedMessage(String messageId, String conversationId) {
    final isActive = state.activeConversation?.id == conversationId;

    final messages = isActive
        ? state.messages.where((message) => message.id != messageId).toList()
        : state.messages;
    final activeConversation = state.activeConversation;

    final conversations = state.conversations.map((conversation) {
      if (conversation.id != conversationId) {
        return conversation;
      }
      if (conversation.lastMessage?.id != messageId) {
        return conversation;
      }
      return conversation;
    }).toList();

    state = state.copyWith(
      messages: messages,
      conversations: conversations,
      activeConversation: activeConversation,
    );
  }

  void _handleConversationRemoval(String conversationId) {
    final updated = state.conversations
        .where((conversation) => conversation.id != conversationId)
        .toList();
    final shouldClearActive = state.activeConversation?.id == conversationId;
    if (_joinedConversationId == conversationId) {
      _joinedConversationId = null;
    }
    state = state.copyWith(
      conversations: _sortConversations(updated),
      messages: shouldClearActive ? [] : null,
      clearActiveConversation: shouldClearActive,
    );
  }

  Future<void> leaveConversation() async {
    final conversation = state.activeConversation;
    final currentUser = _ref.read(authControllerProvider).user;

    if (conversation == null || currentUser == null) {
      return;
    }

    try {
      await _repository.removeParticipant(
        conversationId: conversation.id,
        participantId: currentUser.id,
      );

      final remaining = state.conversations
          .where((item) => item.id != conversation.id)
          .toList();

      state = state.copyWith(
        conversations: remaining,
        messages: [],
        clearActiveConversation: true,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _mapError(error));
      rethrow;
    }
  }

  List<Message> _decorateMessages(List<Message> messages) {
    return messages.map(_decorateMessage).toList();
  }

  Message _decorateMessage(Message message) {
    final currentUserId = _ref.read(authControllerProvider).user?.id;
    final isMine = currentUserId != null && message.sender.id == currentUserId;
    return message.copyWith(isMine: isMine);
  }

  List<ConversationSummary> _applyMessageToConversations(
    List<ConversationSummary> existing,
    Message message, {
    required bool isActiveConversation,
  }) {
    var conversations = existing;
    final index =
        existing.indexWhere((item) => item.id == message.conversationId);

    if (index >= 0) {
      final updated = existing[index].copyWith(
        lastMessage: message,
        lastActivity: message.createdAt,
        unreadCount: isActiveConversation || message.isMine
            ? existing[index].unreadCount
            : existing[index].unreadCount + 1,
      );

      conversations = [
        ...existing.sublist(0, index),
        updated,
        ...existing.sublist(index + 1),
      ];
    }

    return _sortConversations(conversations);
  }

  List<ConversationSummary> _sortConversations(
    List<ConversationSummary> conversations,
  ) {
    final sorted = [...conversations];
    sorted.sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
    return sorted;
  }

  String _mapError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
      if (error.message != null && error.message!.isNotEmpty) {
        return error.message!;
      }
      return 'Network request failed. Please try again.';
    }

    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }

    if (error is Error) {
      return error.toString();
    }

    return 'Unable to process your request right now.';
  }
  Future<String> generateInviteLink(String conversationId) async {
    try {
      return await _repository.fetchInviteLink(conversationId);
    } catch (error) {
      state = state.copyWith(errorMessage: _mapError(error));
      rethrow;
    }
  }

  Future<void> joinViaLink(String token) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final conversation = await _repository.joinViaLink(token);
      _upsertConversation(conversation);
      await selectConversation(conversation.id);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapError(error),
      );
      rethrow;
    }
  }
}


final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  final socketService = ref.watch(socketServiceProvider);
  return ChatController(ref, repository, socketService);
});
