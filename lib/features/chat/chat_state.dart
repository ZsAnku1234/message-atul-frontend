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
    this.hasMoreMessages = true,
    this.messagesCursor,
    this.isLoadingMore = false,
  });

  final List<ConversationSummary> conversations;
  final ConversationSummary? activeConversation;
  final List<Message> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;
  final bool hasMoreMessages;
  final String? messagesCursor;
  final bool isLoadingMore;

  ChatState copyWith({
    List<ConversationSummary>? conversations,
    ConversationSummary? activeConversation,
    List<Message>? messages,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    bool? hasMoreMessages,
    String? messagesCursor,
    bool? isLoadingMore,
    bool clearError = false,
    bool clearActiveConversation = false,
    bool clearMessagesCursor = false,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      activeConversation: clearActiveConversation
          ? null
          : (activeConversation ?? this.activeConversation),
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      messagesCursor: clearMessagesCursor ? null : (messagesCursor ?? this.messagesCursor),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}
