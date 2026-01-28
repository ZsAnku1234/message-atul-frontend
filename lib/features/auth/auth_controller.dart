import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
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
  String? _verificationId;
  ConfirmationResult? _webConfirmationResult;
  RecaptchaVerifier? _webRecaptchaVerifier;

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

    // Default to raw input
    String normalizedPhone = phoneNumber;

    try {
      print('[AuthController] requestOtp: function called with $phoneNumber');
      // Normalize phone number for India (Default to +91)
      final trimmed = phoneNumber.trim();
      final cleanDigits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (cleanDigits.length == 10) {
        // Assume 10-digit input is Indian
        normalizedPhone = '+91$cleanDigits';
      } else if (cleanDigits.length == 12 && cleanDigits.startsWith('91')) {
        // Check if user typed 9198... without +
        normalizedPhone = '+$cleanDigits';
      } else if (!trimmed.startsWith('+')) {
        // Fallback for other cases
        normalizedPhone = '+$cleanDigits';
      } else {
        normalizedPhone = trimmed;
      }
      
      if (kIsWeb) {
        // Web specific implementation
        print('[AuthController] requestOtp: Web detected. Initializing RecaptchaVerifier if null...');
        _webRecaptchaVerifier ??= RecaptchaVerifier(
          container: 'recaptcha-container',
          auth: FirebaseAuthPlatform.instance,
        );
        print('[AuthController] requestOtp: RecaptchaVerifier initialized/ready.');
        
        print('[AuthController] requestOtp: Calling signInWithPhoneNumber with $normalizedPhone...');
        _webConfirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(
          normalizedPhone,
          _webRecaptchaVerifier!,
        );
        print('[AuthController] requestOtp: signInWithPhoneNumber completed.');
        
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return OtpRequestResult(
          phoneNumber: normalizedPhone, 
          code: null, // No placeholder code for production
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );
      } else {
        // Mobile implementation
        final completer = Completer<void>();
        String? vId;
        
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: normalizedPhone,
          verificationCompleted: (PhoneAuthCredential credential) async {},
          verificationFailed: (FirebaseAuthException e) {
             completer.completeError(e);
          },
          codeSent: (String verificationId, int? resendToken) {
             vId = verificationId;
             completer.complete();
          },
          codeAutoRetrievalTimeout: (String verificationId) {
             vId = verificationId;
          },
        );
        
        await completer.future;

        state = state.copyWith(status: AuthStatus.unauthenticated);
        _verificationId = vId; 
        
        return OtpRequestResult(
          phoneNumber: phoneNumber, 
          code: null, // No placeholder code for production
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );
      }
      } catch (error, stackTrace) {
        developer.log(
          'OTP request failed',
          name: 'AuthController',
          error: error,
          stackTrace: stackTrace,
        );
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: '${_mapError(error)}\n\nSent: $normalizedPhone',
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
      // 1. Verify OTP with Firebase
      User? firebaseUser;
      
      if (kIsWeb) {
        if (_webConfirmationResult == null) {
          throw Exception("Web confirmation result missing. Request OTP first.");
        }
        final userCredential = await _webConfirmationResult!.confirm(code);
        firebaseUser = userCredential.user;
      } else {
        if (_verificationId == null) {
          throw Exception("Verification ID is missing. Request OTP first.");
        }
        
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );
        
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        firebaseUser = userCredential.user;
      }
      
      if (firebaseUser == null) {
         throw Exception("Firebase Authentication failed.");
      }
      
      final idToken = await firebaseUser.getIdToken();

      if (idToken == null) {
        throw Exception("Failed to retrieve Firebase ID Token.");
      }

      // 2. Call Backend with Firebase ID Token
      final payload = await _repository.loginWithFirebase(
        idToken: idToken,
        displayName: displayName,
        password: password,
      );
      await _repository.persistToken(payload.token);
      state = AuthState.authenticated(payload.user);
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
      return true;
    } catch (error, stackTrace) {
      print('[AuthController] Login EXCEPTION: $error'); // Added debug log
      print('[AuthController] StackTrace: $stackTrace'); // Added debug log
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
    // Reuse the existing Firebase OTP request logic
    // This sets _verificationId / _webConfirmationResult internally
    return requestOtp(phoneNumber, purpose: 'reset');
  }

  // Reset password with OTP
  Future<bool> resetPassword({
    required String phoneNumber,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);

    try {
      // 1. Verify OTP with Firebase (Same logic as signup)
      User? firebaseUser;
      
      if (kIsWeb) {
        if (_webConfirmationResult == null) {
          throw Exception("Web confirmation result missing. Request OTP first.");
        }
        final userCredential = await _webConfirmationResult!.confirm(code);
        firebaseUser = userCredential.user;
      } else {
        if (_verificationId == null) {
          throw Exception("Verification ID is missing. Request OTP first.");
        }
        
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        );
        
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        firebaseUser = userCredential.user;
      }
      
      if (firebaseUser == null) {
         throw Exception("Firebase Authentication failed.");
      }
      
      final idToken = await firebaseUser.getIdToken();

      if (idToken == null) {
        throw Exception("Failed to retrieve Firebase ID Token.");
      }

      // 2. Call Backend to update password using loginWithFirebase
      // This will update the user's password if provided
      final payload = await _repository.loginWithFirebase(
        idToken: idToken,
        password: newPassword,
      );

      await _repository.persistToken(payload.token);
      state = AuthState.authenticated(payload.user);
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
      await _repository.clearToken();
      state = AuthState.unauthenticated();
    } catch (error, stackTrace) {
      developer.log(
        'Sign out failed',
        name: 'AuthController',
        error: error,
        stackTrace: stackTrace,
      );
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
    // Firebase specific errors
    if (error is FirebaseAuthException) {
      return error.message ?? error.code;
    }
    if (error is FirebaseException) {
      return error.message ?? error.code;
    }

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
    
    // Handle Errors (like TypeError, AssertionError)
    if (error is Error) {
      return 'Error: ${error.toString()}';
    }

    return 'Something went wrong: $error';
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(ref, repository);
});
