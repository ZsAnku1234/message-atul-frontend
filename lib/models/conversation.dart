import 'message.dart';
import 'user.dart';

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.participants,
    required this.lastActivity,
    this.title,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String id;
  final String? title;
  final List<UserProfile> participants;
  final Message? lastMessage;
  final DateTime lastActivity;
  final int unreadCount;

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
    return ConversationSummary(
      id: json['id'] as String,
      title: json['title'] as String?,
      participants: (json['participants'] as List<dynamic>)
          .map((dynamic user) => UserProfile.fromJson(user as Map<String, dynamic>))
          .toList(),
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      lastActivity: DateTime.parse(json['lastActivity'] as String),
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  ConversationSummary copyWith({
    Message? lastMessage,
    DateTime? lastActivity,
    int? unreadCount,
  }) {
    return ConversationSummary(
      id: id,
      title: title,
      participants: participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastActivity: lastActivity ?? this.lastActivity,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
