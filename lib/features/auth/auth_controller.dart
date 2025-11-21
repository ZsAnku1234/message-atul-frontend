import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart';
import '../../services/auth_repository.dart';
import '../../providers/app_providers.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref, this._repository) : super(const AuthState()) {
    _initialize();
  }

  final Ref _ref;
  final AuthRepository _repository;

  Future<void> _initialize() async {
    final token = await _repository.readToken();

    if (token == null) {
      state = AuthState.unauthenticated();
      return;
    }

    try {
      final user = await _repository.currentUser();
      state = AuthState.authenticated(user);
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

  Future<OtpRequestResult?> requestOtp(String phoneNumber) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);

    try {
      final result = await _repository.requestOtp(phoneNumber: phoneNumber);
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

  Future<bool> verifyOtp({
    required String phoneNumber,
    required String code,
    String? displayName,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);

    try {
      final payload = await _repository.verifyOtp(
        phoneNumber: phoneNumber,
        code: code,
        displayName: displayName,
      );
      await _repository.persistToken(payload.token);
      state = AuthState.authenticated(payload.user);
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'OTP verification failed',
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
      await _repository.clearToken();
    } finally {
      state = AuthState.unauthenticated();
    }
  }

  void updateUser(UserProfile profile) {
    state = state.copyWith(user: profile);
  }

  String _mapError(Object error) {
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
