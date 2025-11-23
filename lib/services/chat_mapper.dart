import '../models/conversation.dart';
import '../models/message.dart';
import '../models/user.dart';

class ChatMapper {
  const ChatMapper._();

  static ConversationSummary mapConversation(Map<String, dynamic> json) {
    final id = _pickId(json);
    final participants = (json['participants'] as List<dynamic>? ?? [])
        .map((dynamic participant) =>
            UserProfile.fromJson(_normalizeUser(participant)))
        .toList();
    final pendingRequests = (json['pendingJoinRequests'] as List<dynamic>? ?? [])
        .where((requester) => requester is Map || requester is UserProfile)
        .map((dynamic requester) =>
            UserProfile.fromJson(_normalizeUser(requester)))
        .toList();

    final lastMessage = json['lastMessage'] != null
        ? mapMessage(Map<String, dynamic>.from(
            json['lastMessage'] as Map<dynamic, dynamic>))
        : null;

    final lastActivityString = json['lastMessageAt'] as String? ??
        json['lastActivity'] as String? ??
        json['updatedAt'] as String? ??
        DateTime.now().toIso8601String();

    final createdBy = _extractId(json['createdBy']);
    final title = (json['title'] as String?)?.trim();
    final unreadRaw = json['unreadCount'];
    final unread = unreadRaw is int
        ? unreadRaw
        : int.tryParse(unreadRaw?.toString() ?? '') ?? 0;
    final creator =
        createdBy.isNotEmpty ? createdBy : _extractId(json['created_by']);

    return ConversationSummary(
      id: id,
      title: title?.isNotEmpty == true ? title : null,
      participants: participants,
      lastMessage: lastMessage,
      lastActivity: DateTime.parse(lastActivityString),
      unreadCount: unread,
      createdBy: creator,
      isGroup: json['isGroup'] as bool? ?? participants.length > 2,
      isPrivate: json['isPrivate'] as bool? ?? false,
      adminIds: (json['admins'] as List<dynamic>? ?? [])
          .map((dynamic value) => _extractId(value))
          .where((id) => id.isNotEmpty)
          .toList(),
      adminOnlyMessaging: json['adminOnlyMessaging'] as bool? ?? false,
      pendingJoinRequests: pendingRequests,
    );
  }

  static Message mapMessage(Map<String, dynamic> json) {
    final conversation = json['conversation'];
    final conversationId = conversation is Map
        ? _pickId(Map<String, dynamic>.from(conversation as Map))
        : _extractId(conversation);

    return Message(
      id: _pickId(json),
      conversationId: conversationId,
      sender: UserProfile.fromJson(_normalizeUser(json['sender'])),
      body: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((dynamic url) => url as String)
          .toList(),
      isMine: json['isMine'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _normalizeUser(dynamic user) {
    if (user is UserProfile) {
      return user.toJson();
    }

    if (user is Map<String, dynamic>) {
      final phone = (user['phoneNumber'] as String?) ?? '';
      final name = user['displayName'];
      final safeName =
          _resolveDisplayName(name, phone.isNotEmpty ? phone : null);
      final id = user['id'] ?? user['_id'];

      return {
        'id': id is String ? id : (id?.toString() ?? ''),
        'phoneNumber': phone,
        'displayName': safeName,
        'avatarUrl': user['avatarUrl'],
        'statusMessage': user['statusMessage'],
      };
    }

    throw ArgumentError('Invalid user payload: $user');
  }

  static String _extractId(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is Map) {
      return _pickId(Map<String, dynamic>.from(value as Map));
    }
    return value.toString();
  }

  static String _resolveDisplayName(dynamic name, String? phoneNumber) {
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final suffix = phoneNumber.length >= 4
          ? phoneNumber.substring(phoneNumber.length - 4)
          : phoneNumber;
      return 'User $suffix';
    }

    return 'New User';
  }

  static String _pickId(Map<String, dynamic> json) {
    final primary = _extractRawId(json['id']);
    if (primary.isNotEmpty) {
      return primary;
    }

    final fallback = _extractRawId(json['_id']);
    if (fallback.isNotEmpty) {
      return fallback;
    }

    return '';
  }

  static String _extractRawId(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    final normalized = value.toString().trim();
    return normalized;
  }
}
