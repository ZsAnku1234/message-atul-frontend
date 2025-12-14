import 'package:dio/dio.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'chat_mapper.dart';

class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  Future<List<ConversationSummary>> fetchConversations() async {
    final response = await _dio.get<Map<String, dynamic>>('/conversations');
    final items = response.data!['conversations'] as List<dynamic>;
    return items
        .map((dynamic json) =>
            ChatMapper.mapConversation(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<(ConversationSummary, List<Message>)> fetchConversationDetail(
      String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/conversations/$id');
    final data = response.data!;
    final conversation = ChatMapper.mapConversation(
        Map<String, dynamic>.from(data['conversation'] as Map));
    final messages = (data['messages'] as List<dynamic>)
        .map((dynamic json) =>
            ChatMapper.mapMessage(Map<String, dynamic>.from(json as Map)))
        .toList()
        .reversed
        .toList();
    return (conversation, messages);
  }

  Future<Message> sendMessage({
    required String conversationId,
    required String content,
    List<String> attachments = const [],
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/messages',
      data: {
        'conversationId': conversationId,
        'content': content,
        if (attachments.isNotEmpty) 'attachments': attachments,
      },
    );

    return ChatMapper.mapMessage(
        Map<String, dynamic>.from(response.data!['message'] as Map));
  }

  Future<ConversationSummary> createConversation({
    required List<String> participantIds,
    String? title,
    bool isPrivate = false,
  }) async {
    final payload = <String, dynamic>{
      'participantIds': participantIds,
    };
    if (title != null && title.trim().isNotEmpty) {
      payload['title'] = title.trim();
    }
    if (isPrivate) {
      payload['isPrivate'] = true;
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/conversations',
      data: payload,
    );

    final raw =
        Map<String, dynamic>.from(response.data!['conversation'] as Map);
    final participants = raw['participants'];

    if (participants is List &&
        participants.isNotEmpty &&
        participants.first is! Map) {
      final rawId = raw['id'] ?? raw['_id'];
      final id = rawId is String ? rawId : rawId?.toString();
      if (id == null || id.isEmpty) {
        throw StateError('Conversation id missing from create response.');
      }
      final details = await fetchConversationDetail(id);
      return details.$1;
    }

    return ChatMapper.mapConversation(raw);
  }

  Future<ConversationSummary> updateAdmins({
    required String conversationId,
    List<String> add = const [],
    List<String> remove = const [],
  }) async {
    final payload = <String, dynamic>{};
    if (add.isNotEmpty) {
      payload['add'] = add;
    }
    if (remove.isNotEmpty) {
      payload['remove'] = remove;
    }

    if (payload.isEmpty) {
      throw ArgumentError('At least one admin change is required.');
    }

    final response = await _dio.patch<Map<String, dynamic>>(
      '/conversations/$conversationId/admins',
      data: payload,
    );

    return ChatMapper.mapConversation(
      Map<String, dynamic>.from(response.data!['conversation'] as Map),
    );
  }

  Future<ConversationSummary> setAdminOnlyMessaging({
    required String conversationId,
    required bool adminOnlyMessaging,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/conversations/$conversationId/message-control',
      data: {'adminOnlyMessaging': adminOnlyMessaging},
    );

    return ChatMapper.mapConversation(
      Map<String, dynamic>.from(response.data!['conversation'] as Map),
    );
  }

  Future<ConversationSummary> addParticipants({
    required String conversationId,
    required List<String> participantIds,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/conversations/$conversationId/participants',
      data: {'participantIds': participantIds},
    );

    return ChatMapper.mapConversation(
      Map<String, dynamic>.from(response.data!['conversation'] as Map),
    );
  }

  Future<void> removeParticipant({
    required String conversationId,
    required String participantId,
  }) async {
    await _dio.delete<void>(
      '/conversations/$conversationId/participants/$participantId',
    );
  }

  Future<ConversationSummary> updateConversation({
    required String conversationId,
    String? title,
    String? avatarUrl,
    bool? isPrivate,
  }) async {
    final payload = <String, dynamic>{};
    if (title != null && title.trim().isNotEmpty) {
      payload['title'] = title.trim();
    }
    if (avatarUrl != null) {
      payload['avatarUrl'] = avatarUrl;
    }
    if (isPrivate != null) {
      payload['isPrivate'] = isPrivate;
    }
    if (payload.isEmpty) {
      throw ArgumentError('Provide at least one field to update.');
    }

    final response = await _dio.patch<Map<String, dynamic>>(
      '/conversations/$conversationId',
      data: payload,
    );

    return ChatMapper.mapConversation(
      Map<String, dynamic>.from(response.data!['conversation'] as Map),
    );
  }

  Future<ConversationSummary> respondToJoinRequest({
    required String conversationId,
    required String applicantId,
    required bool approve,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/conversations/$conversationId/join-requests/$applicantId',
      data: {'action': approve ? 'approve' : 'reject'},
    );

    return ChatMapper.mapConversation(
      Map<String, dynamic>.from(response.data!['conversation'] as Map),
    );
  }

  Future<ConversationSummary?> requestToJoinGroup(String conversationId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/conversations/$conversationId/join',
    );
    final data = response.data ?? {};
    if (data['status'] == 'joined' && data['conversation'] is Map) {
      return ChatMapper.mapConversation(
        Map<String, dynamic>.from(data['conversation'] as Map),
      );
    }
    return null;
  }

  Future<List<ConversationSummary>> searchGroups(String query) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/conversations/search',
      queryParameters: {'q': query},
    );
    final items = response.data?['conversations'];
    if (items is List) {
      return items
          .map(
            (dynamic item) =>
                ChatMapper.mapConversation(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    }
    return [];
  }

  Future<MessagePage> fetchMessages({
    required String conversationId,
    String? before,
    int limit = 50,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/messages/conversations/$conversationId/messages',
      queryParameters: {
        if (before != null) 'before': before,
        'limit': limit.toString(),
      },
    );

    final data = response.data!;
    final messages = (data['messages'] as List<dynamic>)
        .map((dynamic json) =>
            ChatMapper.mapMessage(Map<String, dynamic>.from(json as Map)))
        .toList()
        .reversed
        .toList();

    return MessagePage(
      messages: messages,
      hasMore: data['hasMore'] as bool,
      nextCursor: data['nextCursor'] as String?,
    );
  }
  Future<String> fetchInviteLink(String conversationId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/conversations/$conversationId/invite-link',
    );
    return response.data!['link'] as String;
  }

  Future<ConversationSummary> joinViaLink(String token) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/conversations/join',
      data: {'token': token},
    );
    return ChatMapper.mapConversation(
        Map<String, dynamic>.from(response.data!['conversation'] as Map));
  }
}


class MessagePage {
  const MessagePage({
    required this.messages,
    required this.hasMore,
    this.nextCursor,
  });

  final List<Message> messages;
  final bool hasMore;
  final String? nextCursor;
}
