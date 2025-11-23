import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';

const _tokenStorageKey = 'auth_token';
const _userStorageKey = 'auth_user';
const bool _demoAuthOverride =
    bool.fromEnvironment('DEMO_AUTH', defaultValue: false);

class AuthPayload {
  const AuthPayload({required this.user, required this.token});

  final UserProfile user;
  final String token;
}

class OtpRequestResult {
  const OtpRequestResult({
    required this.phoneNumber,
    required this.expiresAt,
    this.code,
  });

  final String phoneNumber;
  final DateTime expiresAt;
  final String? code;
}

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<OtpRequestResult> requestOtp({
    required String phoneNumber,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/request-otp',
        data: {'phoneNumber': phoneNumber},
      );

      final data = response.data!;
      return OtpRequestResult(
        phoneNumber: data['phoneNumber'] as String,
        expiresAt: DateTime.parse(data['expiresAt'] as String),
        code: data['code'] as String?,
      );
    } on DioException catch (error) {
      if (_isDemoAuthEnabled(error)) {
        return _buildDemoOtpResult(phoneNumber: phoneNumber);
      }
      rethrow;
    }
  }

  Future<AuthPayload> verifyOtp({
    required String phoneNumber,
    required String code,
    String? displayName,
  }) async {
    final request = <String, dynamic>{
      'phoneNumber': phoneNumber,
      'code': code,
    };
    if (displayName != null && displayName.trim().isNotEmpty) {
      request['displayName'] = displayName.trim();
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: request,
      );

      final data = response.data!;
      final authPayload = AuthPayload(
        user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
        token: data['token'] as String,
      );
      await _persistUser(authPayload.user);
      return authPayload;
    } on DioException catch (error) {
      if (_isDemoAuthEnabled(error)) {
        final fallback = _buildDemoPayload(
          phoneNumber: phoneNumber,
          displayName: displayName,
        );
        await _persistUser(fallback.user);
        return fallback;
      }
      rethrow;
    }
  }

  Future<UserProfile> currentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final data = response.data!;
      final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
      await _persistUser(user);
      return user;
    } on DioException catch (error) {
      if (_isDemoAuthEnabled(error)) {
        final cachedUser = await _readPersistedUser();
        if (cachedUser != null) {
          return cachedUser;
        }
      }
      rethrow;
    }
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
    await _storage.delete(key: _userStorageKey);
    _dio.options.headers.remove('Authorization');
  }

  bool _isDemoAuthEnabled(DioException error) {
    final allowFallback = !kReleaseMode || _demoAuthOverride;
    if (!allowFallback) {
      return false;
    }

    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown;
  }

  OtpRequestResult _buildDemoOtpResult({
    required String phoneNumber,
  }) {
    final normalized = _normalizePhoneNumber(phoneNumber);
    final code = (Random().nextInt(900000) + 100000).toString();
    return OtpRequestResult(
      phoneNumber: normalized,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      code: code,
    );
  }

  AuthPayload _buildDemoPayload({
    required String phoneNumber,
    String? displayName,
  }) {
    final normalized = _normalizePhoneNumber(phoneNumber);
    final suffix = normalized.length >= 4
        ? normalized.substring(normalized.length - 4)
        : normalized;
    final resolvedName = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : 'User $suffix';
    final profile = UserProfile(
      id: 'demo-user',
      phoneNumber: normalized,
      displayName: resolvedName,
      avatarUrl: null,
      statusMessage: 'Demo mode – no backend connected',
    );

    return AuthPayload(user: profile, token: 'demo-token');
  }

  String _normalizePhoneNumber(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return '+0000000000';
    }
    return '+$digits';
  }

  Future<void> _persistUser(UserProfile user) async {
    await _storage.write(
      key: _userStorageKey,
      value: jsonEncode(user.toJson()),
    );
  }

  Future<UserProfile?> _readPersistedUser() async {
    final jsonString = await _storage.read(key: _userStorageKey);
    if (jsonString == null) {
      return null;
    }

    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    final request = <String, dynamic>{};
    if (displayName != null) {
      request['displayName'] = displayName;
    }
    if (avatarUrl != null) {
      request['avatarUrl'] = avatarUrl;
    }

    print('Updating profile with request: $request');

    final response = await _dio.put<Map<String, dynamic>>(
      '/users/profile',
      data: request,
    );

    final data = response.data!;
    final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
    
    print('Received updated user from server: ${user.displayName}, avatar: ${user.avatarUrl}');
    
    await _persistUser(user);
    
    print('User persisted to local storage');
    
    return user;
  }
}
