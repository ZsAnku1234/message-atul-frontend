import 'package:intl/intl.dart';
import 'user.dart';

class Message {
  Message({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.body,
    required this.createdAt,
    this.attachments = const [],
    this.isMine = false,
  });

  final String id;
  final String conversationId;
  final UserProfile sender;
  final String body;
  final DateTime createdAt;
  final List<String> attachments;
  final bool isMine;

  String get formattedTime => DateFormat('h:mm a').format(createdAt);

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      sender: UserProfile.fromJson(json['sender'] as Map<String, dynamic>),
      body: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      attachments: (json['attachments'] as List<dynamic>? ?? [])
          .map((dynamic url) => url as String)
          .toList(),
      isMine: json['isMine'] as bool? ?? false,
    );
  }

  Message copyWith({bool? isMine}) {
    return Message(
      id: id,
      conversationId: conversationId,
      sender: sender,
      body: body,
      createdAt: createdAt,
      attachments: attachments,
      isMine: isMine ?? this.isMine,
    );
  }
}
