import 'package:intl/intl.dart';

import '../utils/indian_time.dart';
import 'user.dart';

class Message {
  Message({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.body,
    required this.createdAt,
    List<String> attachments = const [],
    this.isMine = false,
  }) : attachments = _filterAttachmentUrls(attachments);

  final String id;
  final String conversationId;
  final UserProfile sender;
  final String body;
  final DateTime createdAt;
  final List<String> attachments;
  final bool isMine;

  DateTime get createdAtIndian => createdAt.asIndianTime;

  String get formattedTime => DateFormat('h:mm a').format(createdAtIndian);
  String get formattedDate => DateFormat('MMMM d, yyyy').format(createdAtIndian);

  factory Message.fromJson(Map<String, dynamic> json) {
    final conversationField = json['conversationId'] ?? json['conversation'];
    final conversationId = _coerceId(conversationField) ?? '';

    return Message(
      id: _coerceId(json['id']) ?? _coerceId(json['_id']) ?? '',
      conversationId: conversationId,
      sender: UserProfile.fromJson(json['sender'] as Map<String, dynamic>),
      body: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      attachments: _filterAttachmentUrls(json['attachments']),
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

List<String> _filterAttachmentUrls(dynamic raw) {
  final values = <String>[];

  if (raw is List) {
    values.addAll(raw.whereType<String>());
  } else if (raw is Iterable) {
    for (final item in raw) {
      if (item is String) {
        values.add(item);
      }
    }
  } else if (raw is String) {
    values.add(raw);
  }

  return values
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty && !_looksLikeScreenshot(url))
      .toList();
}

bool _looksLikeScreenshot(String url) {
  final lower = url.toLowerCase();
  return lower.contains("screenshot") ||
      lower.contains("screen%20shot") ||
      lower.contains("screen-shot") ||
      lower.contains("screen_shot");
}
