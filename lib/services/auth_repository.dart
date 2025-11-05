import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import 'api_client.dart';

const _tokenStorageKey = 'auth_token';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

class AuthPayload {
  const AuthPayload({required this.user, required this.token});

  final UserProfile user;
  final String token;
}

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<AuthPayload> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = response.data!;
    return AuthPayload(
      user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
      token: data['token'] as String,
    );
  }

  Future<AuthPayload> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'displayName': displayName,
      },
    );

    final data = response.data!;
    return AuthPayload(
      user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
      token: data['token'] as String,
    );
  }

  Future<UserProfile> currentUser() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');
    final data = response.data!;
    return UserProfile.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> persistToken(String token) async {
    await _storage.write(key: _tokenStorageKey, value: token);
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<String?> readToken() async {
    final token = await _storage.read(key: _tokenStorageKey);
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
    return token;
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenStorageKey);
    _dio.options.headers.remove('Authorization');
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final client = ref.watch(apiClientProvider);
  return AuthRepository(client, storage);
});
