import 'package:flutter/material.dart';

import '../../../../core/services/api_service.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController =
      TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isResettingPassword = false;

  String? _identifier;
  bool _argumentsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_argumentsLoaded) {
      return;
    }

    final arguments =
        ModalRoute.of(context)?.settings.arguments;

    if (arguments is Map) {
      _identifier =
          arguments['identifier']?.toString();

      _argumentsLoaded = true;
    }

    _argumentsLoaded = true;
  }

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // RESET PASSWORD
  // ============================================================

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_identifier == null ||
        _identifier!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid password reset request.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isResettingPassword = true;
    });

    try {
      final response =
          await ApiService.resetPassword(
        identifier: _identifier!,
        otp: _otpController.text.trim(),
        newPassword:
            _newPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Password Reset Successful',
            ),
            content: Text(
              response['message']?.toString() ??
                  'Your password has been reset successfully.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('CONTINUE'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Something went wrong. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResettingPassword = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 460,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ======================================================
                    // ICON
                    // ======================================================

                    const Icon(
                      Icons.password_rounded,
                      size: 48,
                      color: AppTheme.primary,
                    ),

                    const SizedBox(height: 28),

                    // ======================================================
                    // HEADER
                    // ======================================================

                    const Text(
                      'Create a new password',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Enter the OTP and create a new password for your account.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ======================================================
                    // OTP
                    // ======================================================

                    const Text(
                      'Verification OTP',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _otpController,
                      keyboardType:
                          TextInputType.number,
                      maxLength: 6,
                      enabled: !_isResettingPassword,
                      decoration: const InputDecoration(
                        hintText: 'Enter 6-digit OTP',
                        counterText: '',
                        prefixIcon: Icon(
                          Icons.verified_user_outlined,
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter the OTP';
                        }

                        if (!RegExp(
                          r'^\d{6}$',
                        ).hasMatch(value.trim())) {
                          return 'OTP must contain exactly 6 digits';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ======================================================
                    // NEW PASSWORD
                    // ======================================================

                    const Text(
                      'New password',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller:
                          _newPasswordController,
                      obscureText:
                          _obscureNewPassword,
                      enabled: !_isResettingPassword,
                      decoration: InputDecoration(
                        hintText:
                            'Enter your new password',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                        ),
                        suffixIcon: IconButton(
                          onPressed:
                              _isResettingPassword
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscureNewPassword =
                                            !_obscureNewPassword;
                                      });
                                    },
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons
                                    .visibility_outlined
                                : Icons
                                    .visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty) {
                          return 'Please enter a new password';
                        }

                        if (value.length < 8) {
                          return 'Password must contain at least 8 characters';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ======================================================
                    // CONFIRM PASSWORD
                    // ======================================================

                    const Text(
                      'Confirm new password',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller:
                          _confirmPasswordController,
                      obscureText:
                          _obscureConfirmPassword,
                      enabled: !_isResettingPassword,
                      decoration: InputDecoration(
                        hintText:
                            'Re-enter your new password',
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                        ),
                        suffixIcon: IconButton(
                          onPressed:
                              _isResettingPassword
                                  ? null
                                  : () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons
                                    .visibility_outlined
                                : Icons
                                    .visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty) {
                          return 'Please confirm your password';
                        }

                        if (value !=
                            _newPasswordController.text) {
                          return 'Passwords do not match';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    // ======================================================
                    // RESET PASSWORD BUTTON
                    // ======================================================

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed:
                            _isResettingPassword
                                ? null
                                : _resetPassword,
                        child: _isResettingPassword
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'RESET PASSWORD',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}