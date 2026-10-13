import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../../core/services/api_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int _otpLength = 6;

  final _formKey = GlobalKey<FormState>();

  final List<TextEditingController> _controllers =
      List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes =
      List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  Timer? _timer;

  int _secondsRemaining = 30;
  bool _isVerifying = false;

  String? _identifier;
  String? _mobile;
  bool _isLogin = false;
  String? _developmentOtp;
  bool _isAutoFilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _identifier = args['identifier']?.toString() ?? args['email']?.toString();
      _mobile = args['mobile']?.toString();
      _isLogin = args['isLogin'] == true;
      _developmentOtp = args['developmentOtp']?.toString();

      if (_developmentOtp != null &&
          _developmentOtp!.length == _otpLength &&
          !_isAutoFilled) {
        _isAutoFilled = true;
        _simulateSmsArrival(_developmentOtp!);
      }
    }
  }

  void _simulateSmsArrival(String otpCode) {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.mark_chat_unread_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SMS • Travel Advisory',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Your verification code is $otpCode. Auto-filling now.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        ),
      );

      for (int i = 0; i < _otpLength && i < otpCode.length; i++) {
        _controllers[i].text = otpCode[i];
      }
      _focusNodes.last.unfocus();
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();

    for (final controller in _controllers) {
      controller.dispose();
    }

    for (final node in _focusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();

    setState(() {
      _secondsRemaining = 30;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_secondsRemaining <= 1) {
          timer.cancel();

          if (mounted) {
            setState(() {
              _secondsRemaining = 0;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _secondsRemaining--;
            });
          }
        }
      },
    );
  }

  void _handleOtpChange(
    int index,
    String value,
  ) {
    // Normal single-digit input.
    if (value.length == 1) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }

      setState(() {});
      return;
    }

    // Handle pasted OTP.
    if (value.length > 1) {
      final digits = value.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      for (int i = 0; i < digits.length; i++) {
        final targetIndex = index + i;

        if (targetIndex >= _otpLength) {
          break;
        }

        _controllers[targetIndex].text = digits[i];
      }

      final nextIndex =
          (index + digits.length).clamp(
        0,
        _otpLength - 1,
      );

      if (_isOtpComplete()) {
        _focusNodes[_otpLength - 1].unfocus();
      } else {
        _focusNodes[nextIndex].requestFocus();
      }

      setState(() {});
    }
  }

  KeyEventResult _handleKeyEvent(
    int index,
    KeyEvent event,
  ) {
    if (event is KeyDownEvent &&
        event.logicalKey ==
            LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty &&
          index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();

        setState(() {});

        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  bool _isOtpComplete() {
    return _controllers.every(
      (controller) => controller.text.length == 1,
    );
  }

  String _getOtp() {
    return _controllers
        .map((controller) => controller.text)
        .join();
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining != 0) {
      return;
    }

    for (final controller in _controllers) {
      controller.clear();
    }

    _focusNodes.first.requestFocus();
    _startTimer();

    try {
      String? devOtp;
      if (_isLogin) {
        final mobile = _mobile ?? _identifier;
        if (mobile != null && mobile.isNotEmpty) {
          final res = await ApiService.sendLoginOtp(mobile: mobile);
          devOtp = res['development_otp']?.toString();
        }
      } else {
        final id = _identifier ?? _mobile;
        if (id != null && id.isNotEmpty) {
          final res = await ApiService.resendVerificationOtp(identifier: id);
          devOtp = res['development_otp']?.toString();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A new verification code has been dispatched.',
            ),
          ),
        );

        if (devOtp != null && devOtp.length == _otpLength) {
          _simulateSmsArrival(devOtp);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend code. Please try again.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();

    if (!_isOtpComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter all 6 digits of the OTP.',
          ),
        ),
      );
      return;
    }

    final otp = _getOtp();

    setState(() {
      _isVerifying = true;
    });

    try {
      if (_isLogin) {
        final mobile = _mobile ?? _identifier;
        if (mobile == null || mobile.isEmpty) {
          throw ApiException('Mobile number is required for OTP verification.');
        }

        await ApiService.loginWithOtp(
          mobile: mobile,
          otp: otp,
        );
      } else {
        final id = _identifier ?? _mobile;
        if (id == null || id.isEmpty) {
          throw ApiException('Account identifier is required for OTP verification.');
        }

        await ApiService.verifyOtp(
          identifier: id,
          otp: otp,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isVerifying = false;
      });

      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.fromLTRB(
              24,
              28,
              24,
              28,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(
                        alpha: 0.10,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppTheme.primary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isLogin ? 'Login verified!' : 'Account verified!',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'You have successfully signed in. Let’s plan your journey.'
                        : 'Your account has been successfully verified. Let’s personalise your travel experience.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.roleSelection,
                          (route) => false,
                        );
                      },
                      child: const Text(
                        'CONTINUE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.danger,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification failed. Please try again.'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 58,
      child: Focus(
        onKeyEvent: (
          node,
          event,
        ) {
          return _handleKeyEvent(
            index,
            event,
          );
        },
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textInputAction: index == _otpLength - 1
              ? TextInputAction.done
              : TextInputAction.next,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppTheme.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppTheme.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppTheme.primary,
                width: 2,
              ),
            ),
          ),
          autofillHints: const [
            AutofillHints.oneTimeCode,
          ],
          onChanged: (value) {
            _handleOtpChange(
              index,
              value,
            );
          },
          onFieldSubmitted: (_) {
            if (index == _otpLength - 1) {
              _verifyOtp();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightMint,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            12,
            24,
            32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                  ),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),

                const SizedBox(height: 24),

                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color:
                          AppTheme.primary.withValues(
                        alpha: 0.10,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppTheme.primary,
                      size: 36,
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                Center(
                  child: Text(
                    _isLogin ? 'Sign in with OTP' : 'Verify your account',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Center(
                  child: Text(
                    _isLogin
                        ? 'Enter the 6-digit verification code sent to ${_mobile ?? "your mobile"}.'
                        : 'Enter the 6-digit verification code sent to your registered mobile number.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Verification code',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (_isAutoFilled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.forestGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 13,
                              color: AppTheme.forestGreen,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Auto-filled from SMS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.forestGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                AutofillGroup(
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      _otpLength,
                      (index) {
                        return _buildOtpBox(index);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Center(
                  child: TextButton(
                    onPressed:
                        _secondsRemaining == 0
                            ? _resendOtp
                            : null,
                    child: Text(
                      _secondsRemaining == 0
                          ? 'RESEND OTP'
                          : 'Resend OTP in '
                              '$_secondsRemaining'
                              's',
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        _isVerifying
                            ? null
                            : _verifyOtp,
                    child: _isVerifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'VERIFY & CONTINUE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.border,
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.security_rounded,
                        size: 22,
                        color: AppTheme.primary,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your verification code is used only to verify your account.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color:
                                AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}