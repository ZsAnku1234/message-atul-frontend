import 'package:dio/dio.dart';

import '../models/user.dart';

class UserRepository {
  UserRepository(this._dio);

  final Dio _dio;

  Future<List<UserProfile>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return [];
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/users/search',
      queryParameters: {'q': trimmed},
    );

    final items = response.data?['users'] as List<dynamic>? ?? [];
    return items
        .map((dynamic json) =>
            UserProfile.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }
}
