import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart';
import '../../services/auth_repository.dart';
import '../../providers/app_providers.dart';
import '../../services/notification_service.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref, this._repository) : super(const AuthState()) {
    _initialize();
  }

  final Ref _ref;
  final AuthRepository _repository;

  Future<void> _initialize() async {
    print('[AuthController] Initializing...');
    final token = await _repository.readToken();

    if (token == null) {
      print('[AuthController] No token found');
      state = AuthState.unauthenticated();
      return;
    }

    print('[AuthController] Token found, fetching current user...');
    
    try {
      final user = await _repository.currentUser();
      print('[AuthController] User loaded: ${user.displayName}, avatar: ${user.avatarUrl}');
      state = AuthState.authenticated(user);
      
      // Initialize notifications
      await _ref.read(notificationServiceProvider).initialize();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to initialize auth session',
        name: 'AuthController',
        error: error,
        stackTrace: stackTrace,
      );
      await _repository.clearToken();
      state = AuthState.unauthenticated();
    }
  }

  // Request OTP for signup or password reset
  Future<OtpRequestResult?> requestOtp(String phoneNumber, {String? purpose}) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);

    try {
      final result = await _repository.requestOtp(
        phoneNumber: phoneNumber,
        purpose: purpose,
      );
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return result;
    } catch (error, stackTrace) {
      developer.log(
        'OTP request failed',
        name: 'AuthController',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _mapError(error),
      );
      return null;
    }
  }

  // Signup with OTP + password
  Future<bool> signup({
    required String phoneNumber,
    required String code,
    required String displayName,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);

    try {
      final payload = await _repository.signup(
        phoneNumber: phoneNumber,
        code: code,
        displayName: displayName,
        password: password,
      );
      await _repository.persistToken(payload.token);
      state = AuthState.authenticated(payload.user);
      await _ref.read(notificationServiceProvider).initialize();
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Signup failed',
        name: 'AuthController',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _mapError(error),
      );
      return false;
    }
  }

  // Login with password
  Future<bool> loginWithPassword({
    required String phoneNumber,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);

    try {
      final payload = await _repository.loginWithPassword(
        phoneNumber: phoneNumber,
        password: password,
      );
      await _repository.persistToken(payload.token);
      state = AuthState.authenticated(payload.user);
      await _ref.read(notificationServiceProvider).initialize();
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Login failed',
        name: 'AuthController',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _mapError(error),
      );
      return false;
    }
  }

  // Forgot password - request OTP
  Future<OtpRequestResult?> forgotPassword(String phoneNumber) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);

    try {
      final result = await _repository.forgotPassword(phoneNumber: phoneNumber);
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return result;
    } catch (error, stackTrace) {
      developer.log(
        'Forgot password request failed',
        name: 'AuthController',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _mapError(error),
      );
      return null;
    }
  }

  // Reset password with OTP
  Future<bool> resetPassword({
    required String phoneNumber,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);

    try {
      final payload = await _repository.resetPassword(
        phoneNumber: phoneNumber,
        code: code,
        newPassword: newPassword,
      );
      await _repository.persistToken(payload.token);
      state = AuthState.authenticated(payload.user);
      await _ref.read(notificationServiceProvider).initialize();
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Password reset failed',
        name: 'AuthController',
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _mapError(error),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _ref.read(notificationServiceProvider).unregisterToken();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to unregister push token',
        name: 'AuthController',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      await _repository.clearToken();
      state = AuthState.unauthenticated();
    }
  }

  void updateUser(UserProfile profile) {
    state = state.copyWith(user: profile);
  }

  Future<bool> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    if (state.user == null) {
      return false;
    }

    try {
      final updatedUser = await _repository.updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      state = state.copyWith(user: updatedUser);
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Profile update failed',
        name: 'AuthController',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  String _mapError(Object error) {
    // Extract error message from DioException
    if (error is DioException) {
      final response = error.response;
      if (response?.data is Map<String, dynamic>) {
        final message = response!.data['message'];
        if (message is String) {
          return message;
        }
      }
      // Fallback to error message
      if (error.message != null) {
        return error.message!;
      }
    }
    
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return 'Something went wrong. Please try again.';
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(ref, repository);
});
