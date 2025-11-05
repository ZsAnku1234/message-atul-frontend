import '../../models/conversation.dart';
import '../../models/message.dart';

class ChatState {
  const ChatState({
    this.conversations = const [],
    this.activeConversation,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
  });

  final List<ConversationSummary> conversations;
  final ConversationSummary? activeConversation;
  final List<Message> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;

  ChatState copyWith({
    List<ConversationSummary>? conversations,
    ConversationSummary? activeConversation,
    List<Message>? messages,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      activeConversation: activeConversation ?? this.activeConversation,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
