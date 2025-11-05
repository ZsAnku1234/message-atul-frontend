import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user.dart';
import 'api_client.dart';

class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  Future<List<ConversationSummary>> fetchConversations() async {
    final response = await _dio.get<Map<String, dynamic>>('/conversations');
    final items = response.data!['conversations'] as List<dynamic>;
    return items
        .map((dynamic json) => _mapConversation(json as Map<String, dynamic>))
        .toList();
  }

  Future<(ConversationSummary, List<Message>)> fetchConversationDetail(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/conversations/$id');
    final data = response.data!;
    final conversation = _mapConversation(data['conversation'] as Map<String, dynamic>);
    final messages = (data['messages'] as List<dynamic>)
        .map((dynamic json) => _mapMessage(json as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
    return (conversation, messages);
  }

  Future<Message> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/messages',
      data: {
        'conversationId': conversationId,
        'content': content,
      },
    );

    return _mapMessage(response.data!['message'] as Map<String, dynamic>);
  }

  Future<ConversationSummary> createConversation(List<String> participantIds) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/conversations',
      data: {'participantIds': participantIds},
    );

    return _mapConversation(response.data!['conversation'] as Map<String, dynamic>);
  }

  ConversationSummary _mapConversation(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id'] as String? ?? json['_id'] as String,
      title: json['title'] as String?,
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map((dynamic user) => UserProfile.fromJson(_mergeUser(user)))
          .toList(),
      lastMessage: json['lastMessage'] != null
          ? _mapMessage(json['lastMessage'] as Map<String, dynamic>)
          : null,
      lastActivity: DateTime.parse(
        json['lastMessageAt'] as String? ??
            json['updatedAt'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  Message _mapMessage(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String? ?? json['_id'] as String,
      conversationId: json['conversation'] is Map<String, dynamic>
          ? (json['conversation'] as Map<String, dynamic>)['id'] as String? ??
              (json['conversation'] as Map<String, dynamic>)['_id'] as String
          : json['conversation'] as String,
      sender: UserProfile.fromJson(_mergeUser(json['sender'])),
      body: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((dynamic url) => url as String)
          .toList(),
      isMine: false,
    );
  }

  Map<String, dynamic> _mergeUser(dynamic user) {
    if (user is Map<String, dynamic>) {
      return {
        'id': user['id'] ?? user['_id'],
        'email': user['email'],
        'displayName': user['displayName'],
        'avatarUrl': user['avatarUrl'],
        'statusMessage': user['statusMessage'],
      };
    }

    throw ArgumentError('Invalid user payload');
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);
