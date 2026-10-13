import 'package:flutter/material.dart';

import '../../../app/routes.dart';

import '../../../core/services/api_service.dart';

class VerifyAccountScreen extends StatefulWidget {
  const VerifyAccountScreen({
    super.key,
    this.identifier,
  });

  final String? identifier;

  @override
  State<VerifyAccountScreen> createState() =>
      _VerifyAccountScreenState();
}

class _VerifyAccountScreenState
    extends State<VerifyAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _identifierController;
  final TextEditingController _otpController =
      TextEditingController();

  bool _isSendingOtp = false;
  bool _isVerifying = false;
  bool _otpSent = false;

  String? _developmentOtp;

  @override
void initState() {
  super.initState();

  _identifierController = TextEditingController();
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();

  if (_identifierController.text.isNotEmpty) {
    return;
  }

  final arguments =
      ModalRoute.of(context)?.settings.arguments;

  if (arguments is Map<String, dynamic>) {
    final identifier =
        arguments['identifier']?.toString();

    if (identifier != null && identifier.isNotEmpty) {
      _identifierController.text = identifier;
    }
  }
}

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEND / RESEND OTP
  // ============================================================

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSendingOtp = true;
    });

    try {
      final response =
          await ApiService.resendVerificationOtp(
        identifier: _identifierController.text.trim(),
      );

      final developmentOtp =
          response['development_otp']?.toString();

      if (!mounted) {
        return;
      }

      setState(() {
        _otpSent = true;
        _developmentOtp = developmentOtp;

        if (developmentOtp != null &&
            developmentOtp.isNotEmpty) {
          _otpController.text = developmentOtp;
        }
      });

      if (developmentOtp != null &&
          developmentOtp.isNotEmpty) {
        debugPrint(
          'DEVELOPMENT VERIFICATION OTP: $developmentOtp',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification OTP generated successfully.',
          ),
        ),
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
            'Unable to send OTP. Please try again.',
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
  // VERIFY OTP
  // ============================================================

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_otpSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please send the verification OTP first.',
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isVerifying = true;
    });

    try {
 final response = await ApiService.verifyOtp(
  identifier: _identifierController.text.trim(),
  otp: _otpController.text.trim(),
);

      if (!mounted) {
        return;
      }

      final isVerified =
          response['is_verified'] == true;

      if (!isVerified) {
        throw ApiException(
          'Account verification was not completed.',
        );
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Account Verified',
            ),
            content: const Text(
              'Your account has been verified successfully.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
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
        AppRoutes.roleSelection,
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
            'Unable to verify account. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isBusy =
        _isSendingOtp || _isVerifying;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verify Account',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // ==================================================
                // ICON
                // ==================================================

                Icon(
                  Icons.verified_user_outlined,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),

                const SizedBox(height: 24),

                // ==================================================
                // TITLE
                // ==================================================

                Text(
                  'Verify your account',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Your account has not been verified yet. '
                  'Enter your registered email or mobile number '
                  'to receive a verification OTP.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 32),

                // ==================================================
                // EMAIL / MOBILE
                // ==================================================

                TextFormField(
                  controller: _identifierController,
                  keyboardType:
                      TextInputType.emailAddress,
                  enabled: !isBusy,
                  decoration: const InputDecoration(
                    labelText: 'Email or Mobile Number',
                    hintText:
                        'Enter your registered email or mobile',
                    prefixIcon: Icon(
                      Icons.person_outline,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter your email or mobile number.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // ==================================================
                // SEND OTP
                // ==================================================

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        isBusy ? null : _sendOtp,
                    child: _isSendingOtp
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _otpSent
                                ? 'RESEND OTP'
                                : 'SEND OTP',
                          ),
                  ),
                ),

                if (_otpSent) ...[
                  const SizedBox(height: 28),

                  // ==================================================
                  // OTP
                  // ==================================================

                  TextFormField(
                    controller: _otpController,
                    keyboardType:
                        TextInputType.number,
                    maxLength: 6,
                    enabled: !isBusy,
                    decoration:
                        const InputDecoration(
                      labelText: 'Verification OTP',
                      hintText: 'Enter 6-digit OTP',
                      prefixIcon: Icon(
                        Icons.lock_outline,
                      ),
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (!_otpSent) {
                        return null;
                      }

                      final otp =
                          value?.trim() ?? '';

                      if (otp.length != 6) {
                        return 'Enter the 6-digit OTP.';
                      }

                      if (!RegExp(
                        r'^\d{6}$',
                      ).hasMatch(otp)) {
                        return 'OTP must contain only numbers.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // VERIFY BUTTON
                  // ==================================================

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          isBusy ? null : _verifyOtp,
                      child: _isVerifying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'VERIFY ACCOUNT',
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ==================================================
                // BACK TO LOGIN
                // ==================================================

                TextButton(
                  onPressed: isBusy
                      ? null
                      : () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.login,
                            (route) => false,
                          );
                        },
                  child: const Text(
                    'BACK TO LOGIN',
                  ),
                ),

                if (_developmentOtp != null)
                  const SizedBox(height: 8),

                if (_developmentOtp != null)
                  Text(
                    'Development OTP is auto-filled.',
                    textAlign: TextAlign.center,
                    style:
                        theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}