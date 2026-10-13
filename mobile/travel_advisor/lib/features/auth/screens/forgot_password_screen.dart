import 'package:flutter/material.dart';

import '../../../../core/services/api_service.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _identifierController = TextEditingController();

  bool _isSendingOtp = false;

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEND PASSWORD RESET OTP
  // ============================================================

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final response = await ApiService.forgotPassword(
        identifier: _identifierController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      final developmentOtp =
          response['development_otp']?.toString();

      if (developmentOtp == null ||
          developmentOtp.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If an account exists, a reset OTP has been generated.',
            ),
          ),
        );

        return;
      }

      debugPrint(
        'Password Reset Development OTP: $developmentOtp',
      );

      Navigator.pushNamed(
        context,
        AppRoutes.resetPassword,
        arguments: {
          'identifier':
              _identifierController.text.trim(),
          'developmentOtp': developmentOtp,
        },
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
          _isSendingOtp = false;
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
        title: const Text('Forgot Password'),
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
                      Icons.lock_reset_rounded,
                      size: 48,
                      color: AppTheme.primary,
                    ),

                    const SizedBox(height: 28),

                    // ======================================================
                    // HEADER
                    // ======================================================

                    const Text(
                      'Reset your password',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Enter your email or mobile number and we will send you a verification OTP.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ======================================================
                    // EMAIL / MOBILE
                    // ======================================================

                    const Text(
                      'Email or mobile number',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _identifierController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isSendingOtp,
                      decoration: const InputDecoration(
                        hintText:
                            'Enter your email or mobile number',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                        ),
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter your email or mobile number';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    // ======================================================
                    // SEND OTP BUTTON
                    // ======================================================

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSendingOtp
                            ? null
                            : _sendOtp,
                        child: _isSendingOtp
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'SEND OTP',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ======================================================
                    // BACK TO LOGIN
                    // ======================================================

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: _isSendingOtp
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(
                            double.infinity,
                            54,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          side: const BorderSide(
                            color: AppTheme.border,
                          ),
                        ),
                        child: const Text(
                          'BACK TO LOGIN',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
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