class UserProfile {
  const UserProfile({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    this.avatarUrl,
    this.statusMessage,
  });

  final String id;
  final String phoneNumber;
  final String displayName;
  final String? avatarUrl;
  final String? statusMessage;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id']) as String?;
    final phone = (json['phoneNumber'] as String?) ?? '';
    final nameRaw = json['displayName'];
    final name = (nameRaw is String && nameRaw.trim().isNotEmpty)
        ? nameRaw.trim()
        : (phone.isNotEmpty
            ? 'User ${phone.length >= 4 ? phone.substring(phone.length - 4) : phone}'
            : 'New User');

    return UserProfile(
      id: id ?? '',
      phoneNumber: phone,
      displayName: name,
      avatarUrl: json['avatarUrl'] as String?,
      statusMessage: json['statusMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'statusMessage': statusMessage,
    };
  }
}
