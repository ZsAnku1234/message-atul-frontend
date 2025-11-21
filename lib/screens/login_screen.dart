import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_state.dart';
import '../theme/color_tokens.dart';
import '../theme/text_styles.dart';
import '../widgets/primary_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _otpRequested = false;
  String? _normalizedPhone;
  String? _debugCode;
  bool _isVerifying = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    _isVerifying = false;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authController = ref.read(authControllerProvider.notifier);
    final result =
        await authController.requestOtp(_phoneController.text.trim());

    if (result != null) {
      setState(() {
        _otpRequested = true;
        _normalizedPhone = result.phoneNumber;
        _debugCode = result.code;
      });
      _otpController.clear();
    }
  }

  Future<void> _handleVerify() async {
    _isVerifying = true;
    final isValid = _formKey.currentState!.validate();
    _isVerifying = false;

    if (!isValid) {
      return;
    }

    final authController = ref.read(authControllerProvider.notifier);
    final phoneNumber = _normalizedPhone ?? _phoneController.text.trim();
    final displayName = _displayNameController.text.trim().isEmpty
        ? null
        : _displayNameController.text.trim();

    await authController.verifyOtp(
      phoneNumber: phoneNumber,
      code: _otpController.text.trim(),
      displayName: displayName,
    );
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
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10 || digits.length > 15) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validateOtp(String? value) {
    if (!_otpRequested || !_isVerifying) {
      return null;
    }

    if (value == null || value.isEmpty) {
      return 'Enter the 6-digit code';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'OTP must be 6 digits';
    }

    return null;
  }

  String? _validateDisplayName(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    if (value.trim().length < 2) {
      return 'Too short';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        if (previous?.isAuthenticated != next.isAuthenticated &&
            next.isAuthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.go('/conversations');
          });
        }
      },
    );

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
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pulse',
                    style: AppTextStyles.darkTextTheme.titleLarge?.copyWith(
                      fontSize: 48,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in with your phone number to continue.',
                    style: AppTextStyles.darkTextTheme.bodyLarge,
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
                            ? 'Enter the OTP we sent'
                            : 'Welcome back',
                        style: AppTextStyles.lightTextTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _otpRequested
                            ? 'We sent a 6-digit code to ${_normalizedPhone ?? _phoneController.text.trim()}.'
                            : 'We will send a one-time password to your phone.',
                        style: AppTextStyles.lightTextTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),
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
                      const SizedBox(height: 16),
                      if (_otpRequested) ...[
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
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(
                            labelText: 'Display name (optional)',
                            helperText:
                                'We will use this if you are signing in for the first time.',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: _validateDisplayName,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_debugCode != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Development code: $_debugCode',
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (authState.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            authState.errorMessage!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      PrimaryButton(
                        label:
                            _otpRequested ? 'Verify and Continue' : 'Send OTP',
                        isLoading: isLoading,
                        onPressed: isLoading
                            ? null
                            : (_otpRequested
                                ? _handleVerify
                                : _handleRequestOtp),
                      ),
                      if (_otpRequested) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: isLoading ? null : _resetOtpRequest,
                              child: const Text('Change phone number'),
                            ),
                            TextButton(
                              onPressed: isLoading ? null : _handleRequestOtp,
                              child: const Text('Resend code'),
                            ),
                          ],
                        ),
                      ],
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
