import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../../core/services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mobileController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoggingIn = false;
  bool _isOtpLoginMode = false;
  bool _isSendingOtp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  FocusScope.of(context).unfocus();

  setState(() {
    _isLoggingIn = true;
  });

  final identifier = _emailController.text.trim();

  try {
    await ApiService.login(
  identifier: identifier,
  password: _passwordController.text,
);

    if (!mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.roleSelection,
      (route) => false,
    );
  } on ApiException catch (e) {
    if (!mounted) {
      return;
    }

    // ==========================================================
    // UNVERIFIED ACCOUNT
    // ==========================================================

    if (e.statusCode == 403 &&
        e.message == 'Account is not verified.') {
      final shouldVerify = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Account not verified',
            ),
            content: const Text(
              'Your account needs to be verified before '
              'you can continue.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child: const Text('VERIFY ACCOUNT'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      if (shouldVerify == true) {
        Navigator.pushNamed(
          context,
          AppRoutes.verifyAccount,
          arguments: {
            'identifier': identifier,
          },
        );
      }

      return;
    }

    // ==========================================================
    // OTHER LOGIN ERRORS
    // ==========================================================

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
          'Unable to connect to the server. '
          'Please try again.',
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoggingIn = false;
      });
    }
  }
}

  // ============================================================
  // SEND LOGIN OTP
  // ============================================================

  Future<void> _sendLoginOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSendingOtp = true;
    });

    final mobile = _mobileController.text.trim();

    try {
      final response = await ApiService.sendLoginOtp(
        mobile: mobile,
      );

      if (!mounted) {
        return;
      }

      final devOtp = response['development_otp']?.toString();

      Navigator.pushNamed(
        context,
        AppRoutes.otp,
        arguments: {
          'mobile': mobile,
          'identifier': mobile,
          'isLogin': true,
          'developmentOtp': devOtp,
        },
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.danger,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to send verification code. Please try again.',
          ),
          backgroundColor: AppTheme.danger,
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
                    // APP ICON
                    // ======================================================

                    const Icon(
                      Icons.route_rounded,
                      size: 46,
                      color: AppTheme.primary,
                    ),

                    const SizedBox(height: 28),

                    // ======================================================
                    // HEADER
                    // ======================================================

                    const Text(
                      'Welcome',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Sign in to check your Mumbai–Pune travel risk and plan your journey safely.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ======================================================
                    // LOGIN METHOD SELECTOR
                    // ======================================================

                    Container(
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.border.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _isLoggingIn || _isSendingOtp
                                  ? null
                                  : () {
                                      setState(() {
                                        _isOtpLoginMode = false;
                                      });
                                    },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: !_isOtpLoginMode
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: !_isOtpLoginMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Password',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: !_isOtpLoginMode
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _isLoggingIn || _isSendingOtp
                                  ? null
                                  : () {
                                      setState(() {
                                        _isOtpLoginMode = true;
                                      });
                                    },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _isOtpLoginMode
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _isOtpLoginMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Mobile OTP',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _isOtpLoginMode
                                        ? AppTheme.textPrimary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    if (!_isOtpLoginMode) ...[
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
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoggingIn,
                        decoration: const InputDecoration(
                          hintText: 'Enter your email or mobile number',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email or mobile number';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // ======================================================
                      // PASSWORD
                      // ======================================================

                      const Text(
                        'Password',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        enabled: !_isLoggingIn,
                        decoration: InputDecoration(
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                          ),
                          suffixIcon: IconButton(
                            onPressed: _isLoggingIn
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 8) {
                            return 'Password must contain at least 8 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoggingIn
                              ? null
                              : () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.forgotPassword,
                                  );
                                },
                          child: const Text('Forgot password?'),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoggingIn ? null : _login,
                          child: _isLoggingIn
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ] else ...[
                      // ======================================================
                      // MOBILE NUMBER OTP LOGIN
                      // ======================================================

                      const Text(
                        'Mobile number',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        enabled: !_isSendingOtp,
                        decoration: const InputDecoration(
                          hintText: 'Enter your 10-digit mobile number',
                          prefixIcon: Icon(
                            Icons.phone_android_rounded,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your mobile number';
                          }
                          final digits = value.replaceAll(RegExp(r'\D'), '');
                          if (digits.length < 10) {
                            return 'Mobile number must be at least 10 digits';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'A 6-digit verification code will be sent via SMS to your mobile number.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppTheme.textSecondary,
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isSendingOtp ? null : _sendLoginOtp,
                          child: _isSendingOtp
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'SEND VERIFICATION CODE',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ======================================================
                    // DIVIDER
                    // ======================================================

                    Row(
                      children: [
                        const Expanded(
                          child: Divider(),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                          child: Text(
                            'New to the app?',
                            style: TextStyle(
                              color:
                                  AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ======================================================
                    // CREATE ACCOUNT BUTTON
                    // ======================================================

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: _isLoggingIn
                            ? null
                            : () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.signup,
                                );
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
                          'CREATE ACCOUNT',
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