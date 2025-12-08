import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_state.dart';
import '../theme/color_tokens.dart';
import '../theme/text_styles.dart';
import '../widgets/primary_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _otpRequested = false;
  String? _normalizedPhone;
  String? _debugCode;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = ref.read(authControllerProvider.notifier);
    final result = await authController.forgotPassword(
      _phoneController.text.trim(),
    );

    if (result != null) {
      setState(() {
        _otpRequested = true;
        _normalizedPhone = result.phoneNumber;
        _debugCode = result.code;
      });
      _otpController.clear();
    } else {
      // Check if error is about account not found
      final authState = ref.read(authControllerProvider);
      if (authState.errorMessage != null && 
          authState.errorMessage!.toLowerCase().contains('no account found')) {
        _showAccountNotFoundDialog();
      }
    }
  }

  void _showAccountNotFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Not Found'),
        content: const Text(
          'No account exists with this phone number. Please sign up to create a new account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/signup'); // Go to signup screen
            },
            child: const Text('Sign Up'),
          ),
        ],
      ),
    );
  }


  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = ref.read(authControllerProvider.notifier);
    final phoneNumber = _normalizedPhone ?? _phoneController.text.trim();

    final success = await authController.resetPassword(
      phoneNumber: phoneNumber,
      code: _otpController.text.trim(),
      newPassword: _passwordController.text,
    );

    if (success && mounted) {
      // Password reset successful, navigate to conversations
      context.go('/conversations');
    }
  }

  void _resetOtpRequest() {
    setState(() {
      _otpRequested = false;
      _normalizedPhone = null;
      _debugCode = null;
    });
    _otpController.clear();
  }

  String? _validatePhone(String? value) {
    if (!_otpRequested) {
      if (value == null || value.isEmpty) {
        return 'Phone number is required';
      }
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 10 || digits.length > 15) {
        return 'Enter a valid phone number';
      }
    }
    return null;
  }

  String? _validateOtp(String? value) {
    if (_otpRequested) {
      if (value == null || value.isEmpty) {
        return 'Enter the 6-digit code';
      }
      if (!RegExp(r'^\d{6}$').hasMatch(value)) {
        return 'OTP must be 6 digits';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (_otpRequested) {
      if (value == null || value.isEmpty) {
        return 'Password is required';
      }
      if (value.length < 8) {
        return 'Password must be at least 8 characters';
      }
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_otpRequested) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }
      if (value != _passwordController.text) {
        return 'Passwords do not match';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.linearGradient,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reset Password',
                    style: AppTextStyles.darkTextTheme.titleLarge?.copyWith(
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 24,
                    offset: Offset(0, -12),
                    color: Color(0x1A000000),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _otpRequested
                            ? 'Set New Password'
                            : 'Forgot Password?',
                        style: AppTextStyles.lightTextTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _otpRequested
                            ? 'Enter the code we sent to ${_normalizedPhone ?? _phoneController.text.trim()}'
                            : 'Enter your phone number to receive a password reset code',
                        style: AppTextStyles.lightTextTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),
                      
                      // Phone Number
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        enabled: !isLoading && !_otpRequested,
                        validator: _validatePhone,
                      ),
                      
                      if (_otpRequested) ...[
                        const SizedBox(height: 16),
                        
                        // OTP Code
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '6-digit code',
                            prefixIcon: Icon(Icons.key_outlined),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: _validateOtp,
                        ),
                        
                        if (_debugCode != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Development code: $_debugCode',
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 16),
                        
                        // New Password
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'New password',
                            helperText: 'At least 8 characters',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: _validatePassword,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          validator: _validateConfirmPassword,
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      if (authState.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            authState.errorMessage!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      
                      PrimaryButton(
                        label: _otpRequested ? 'Reset Password' : 'Send Code',
                        isLoading: isLoading,
                        onPressed: isLoading
                            ? null
                            : (_otpRequested ? _handleResetPassword : _handleRequestOtp),
                      ),
                      
                      if (_otpRequested) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: isLoading ? null : _resetOtpRequest,
                              child: const Text('Change number'),
                            ),
                            TextButton(
                              onPressed: isLoading ? null : _handleRequestOtp,
                              child: const Text('Resend code'),
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Remember your password? ',
                            style: AppTextStyles.lightTextTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: isLoading ? null : () => context.pop(),
                            child: const Text('Sign In'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
