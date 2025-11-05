import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user.dart';
import '../../services/auth_repository.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState());

  final AuthRepository _repository;

  Future<void> initialize() async {
    final token = await _repository.readToken();

    if (token == null) {
      state = AuthState.unauthenticated();
      return;
    }

    try {
      final user = await _repository.currentUser();
      state = AuthState.authenticated(user);
    } catch (_) {
      await _repository.clearToken();
      state = AuthState.unauthenticated();
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    try {
      final payload = await _repository.login(email: email, password: password);
      await _repository.persistToken(payload.token);
      state = AuthState.authenticated(payload.user);
      return true;
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _mapError(error),
      );
      return false;
    }
  }

  Future<bool> register(String email, String password, String displayName) async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    try {
      final payload = await _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      await _repository.persistToken(payload.token);
      state = AuthState.authenticated(payload.user);
      return true;
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _mapError(error),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _repository.clearToken();
    state = AuthState.unauthenticated();
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
  final controller = AuthController(repository);
  controller.initialize();
  return controller;
});
