import 'message.dart';
import 'user.dart';

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.participants,
    required this.lastActivity,
    required this.createdBy,
    this.title,
    this.avatarUrl,
    this.lastMessage,
    this.unreadCount = 0,
    this.isGroup = false,
    this.isPrivate = false,
    this.adminIds = const [],
    this.adminOnlyMessaging = false,
    this.pendingJoinRequests = const [],
  });

  final String id;
  final String? title;
  final String? avatarUrl;
  final List<UserProfile> participants;
  final Message? lastMessage;
  final DateTime lastActivity;
  final int unreadCount;
  final String createdBy;
  final bool isGroup;
  final bool isPrivate;
  final List<String> adminIds;
  final bool adminOnlyMessaging;
  final List<UserProfile> pendingJoinRequests;

  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) {
      return title!;
    }

    if (participants.length == 1) {
      return participants.first.displayName;
    }

    return participants.map((user) => user.displayName).take(2).join(', ');
  }

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final id = _coerceId(json['id']) ?? _coerceId(json['_id']) ?? '';
    final createdBy =
        _coerceId(json['createdBy']) ?? _coerceId(json['created_by']) ?? '';
    final adminSource = (json['adminIds'] as List<dynamic>?) ??
        (json['admins'] as List<dynamic>? ?? []);
    final lastActivityString = json['lastActivity'] as String? ??
        json['lastMessageAt'] as String? ??
        json['updatedAt'] as String?;

    final pendingRequests = (json['pendingJoinRequests'] as List<dynamic>? ?? [])
        .whereType<Map<dynamic, dynamic>>()
        .map((requester) =>
            UserProfile.fromJson(Map<String, dynamic>.from(requester)))
        .toList();

    return ConversationSummary(
      id: id,
      title: json['title'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      participants: (json['participants'] as List<dynamic>)
          .map((dynamic user) =>
              UserProfile.fromJson(user as Map<String, dynamic>))
          .toList(),
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      lastActivity: lastActivityString != null
          ? DateTime.tryParse(lastActivityString) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: json['unreadCount'] as int? ?? 0,
      createdBy: createdBy,
      isGroup: json['isGroup'] as bool? ?? false,
      isPrivate: json['isPrivate'] as bool? ?? false,
      adminIds: adminSource
          .map((dynamic id) => _coerceId(id))
          .whereType<String>()
          .toList(),
      adminOnlyMessaging: json['adminOnlyMessaging'] as bool? ?? false,
      pendingJoinRequests: pendingRequests,
    );
  }

  ConversationSummary copyWith({
    Message? lastMessage,
    DateTime? lastActivity,
    int? unreadCount,
    String? title,
    String? avatarUrl,
    bool? isGroup,
    bool? isPrivate,
    List<String>? adminIds,
    bool? adminOnlyMessaging,
    List<UserProfile>? pendingJoinRequests,
  }) {
    return ConversationSummary(
      id: id,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      participants: participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastActivity: lastActivity ?? this.lastActivity,
      unreadCount: unreadCount ?? this.unreadCount,
      createdBy: createdBy,
      isGroup: isGroup ?? this.isGroup,
      isPrivate: isPrivate ?? this.isPrivate,
      adminIds: adminIds ?? this.adminIds,
      adminOnlyMessaging: adminOnlyMessaging ?? this.adminOnlyMessaging,
      pendingJoinRequests: pendingJoinRequests ?? this.pendingJoinRequests,
    );
  }

  UserProfile? participantForDisplay(String? currentUserId) {
    if (participants.isEmpty) {
      return null;
    }

    if (isGroup || currentUserId == null) {
      return participants.first;
    }

    return participants.firstWhere(
      (participant) => participant.id != currentUserId,
      orElse: () => participants.first,
    );
  }

  String titleFor(String? currentUserId) {
    if (isGroup || currentUserId == null) {
      return displayTitle;
    }
    return participantForDisplay(currentUserId)?.displayName ?? displayTitle;
  }
}

String? _coerceId(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value as Map);
    final nested = map['id'] ?? map['_id'];
    return _coerceId(nested);
  }
  final converted = value.toString().trim();
  return converted.isEmpty ? null : converted;
}
