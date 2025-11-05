import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/message.dart';
import '../../services/chat_repository.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import 'chat_state.dart';

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._repository, this._authState) : super(const ChatState());

  final ChatRepository _repository;
  final AuthState _authState;

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final conversations = await _repository.fetchConversations();
      state = state.copyWith(
        conversations: conversations,
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

    try {
      final (conversation, messages) =
          await _repository.fetchConversationDetail(conversationId);
      state = state.copyWith(
        activeConversation: conversation,
        messages: _decorateMessages(messages),
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

  Future<void> sendMessage(String content) async {
    if (state.activeConversation == null) {
      return;
    }

    state = state.copyWith(isSending: true);
    final optimistic = Message(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      conversationId: state.activeConversation!.id,
      sender: _authState.user!,
      body: content,
      createdAt: DateTime.now(),
      isMine: true,
    );

    state = state.copyWith(messages: [...state.messages, optimistic]);

    try {
      final message = await _repository.sendMessage(
        conversationId: state.activeConversation!.id,
        content: content,
      );

      state = state.copyWith(
        messages: [
          ...state.messages.where((item) => item.id != optimistic.id),
          message.copyWith(isMine: true),
        ],
        isSending: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: _mapError(error),
        messages: state.messages.where((item) => item.id != optimistic.id).toList(),
      );
    }
  }

  List<Message> _decorateMessages(List<Message> messages) {
    final currentUserId = _authState.user?.id;
    return messages
        .map((message) => message.copyWith(isMine: message.sender.id == currentUserId))
        .toList();
  }

  String _mapError(Object error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return 'Unable to process your request right now.';
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  final authState = ref.watch(authControllerProvider);
  final controller = ChatController(repository, authState);

  if (authState.isAuthenticated) {
    controller.loadConversations();
  }

  return controller;
});
