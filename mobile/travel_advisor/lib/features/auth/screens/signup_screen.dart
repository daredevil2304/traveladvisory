import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/services/api_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isCreatingAccount = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    if (_isCreatingAccount) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCreatingAccount = true;
    });

    try {
      final response = await ApiService.register(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobile: _mobileController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      final email = response['email']?.toString() ??
          _emailController.text.trim();

      Navigator.pushNamed(
        context,
        AppRoutes.otp,
        arguments: {
          'identifier': email,
          'email': email,
          'mobile': _mobileController.text.trim(),
          'isLogin': false,
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : 'Unable to create account. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingAccount = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,

      prefixIcon: Icon(
        icon,
        color: AppTheme.forestGreen,
        size: 21,
      ),

      suffixIcon: suffixIcon,

      filled: true,
      fillColor: AppTheme.white,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),

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
          color: AppTheme.forestGreen,
          width: 1.5,
        ),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  String? _required(
    String? value,
    String field,
  ) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightMint,

      body: SafeArea(
        child: Form(
          key: _formKey,

          child: Column(
            children: [

              // ============================================================
              // TOP BAR
              // ============================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  12,
                  24,
                  0,
                ),

                child: Row(
                  children: [

                    IconButton(
                      onPressed: _isCreatingAccount
                          ? null
                          : () {
                              Navigator.pop(context);
                            },

                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                      ),

                      color: AppTheme.darkNavy,
                    ),

                    const Spacer(),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),

                      decoration: BoxDecoration(
                        color: AppTheme.mint,
                        borderRadius: BorderRadius.circular(30),
                      ),

                      child: Row(
                        children: const [

                          Icon(
                            Icons.shield_outlined,
                            size: 15,
                            color: AppTheme.forestGreen,
                          ),

                          SizedBox(width: 5),

                          Text(
                            'Secure signup',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.forestGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ============================================================
              // CONTENT
              // ============================================================

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    16,
                    24,
                    28,
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      // ======================================================
                      // HEADER
                      // ======================================================

                      const Text(
                        'Create your account',

                        style: TextStyle(
                          fontSize: 30,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkNavy,
                        ),
                      ),

                      const SizedBox(height: 9),

                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AppTheme.textSecondary,
                          ),

                          children: [

                            TextSpan(
                              text:
                                  'Your safer journey ',
                            ),

                            TextSpan(
                              text:
                                  'starts here.',
                              style: TextStyle(
                                color:
                                    AppTheme.forestGreen,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ======================================================
                      // PROGRESS INDICATOR
                      // ======================================================

                      Row(
                        children: [

                          Container(
                            width: 30,
                            height: 5,

                            decoration: BoxDecoration(
                              color:
                                  AppTheme.forestGreen,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                          ),

                          const SizedBox(width: 5),

                          Container(
                            width: 30,
                            height: 5,

                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                          ),

                          const SizedBox(width: 5),

                          Container(
                            width: 30,
                            height: 5,

                            decoration: BoxDecoration(
                              color: AppTheme.border,
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ======================================================
                      // FULL NAME
                      // ======================================================

                      const Text(
                        'Full Name',

                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkNavy,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _nameController,

                        textCapitalization:
                            TextCapitalization.words,

                        enabled: !_isCreatingAccount,

                        decoration: _inputDecoration(
                          hint: 'Enter your name',
                          icon:
                              Icons.person_outline_rounded,
                        ),

                        validator: (value) =>
                            _required(
                              value,
                              'Name',
                            ),
                      ),

                      const SizedBox(height: 16),

                      // ======================================================
                      // EMAIL
                      // ======================================================

                      const Text(
                        'Email Address',

                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkNavy,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _emailController,

                        keyboardType:
                            TextInputType.emailAddress,

                        enabled: !_isCreatingAccount,

                        decoration: _inputDecoration(
                          hint: 'Enter your email',
                          icon:
                              Icons.email_outlined,
                        ),

                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Email is required';
                          }

                          if (!value.contains('@')) {
                            return 'Enter a valid email';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ======================================================
                      // MOBILE
                      // ======================================================

                      const Text(
                        'Mobile Number',

                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkNavy,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _mobileController,

                        keyboardType:
                            TextInputType.phone,

                        enabled: !_isCreatingAccount,

                        decoration: _inputDecoration(
                          hint:
                              'Enter your mobile number',
                          icon:
                              Icons.phone_outlined,
                        ),

                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Mobile number is required';
                          }

                          if (value.length < 10) {
                            return 'Enter a valid mobile number';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ======================================================
                      // PASSWORD
                      // ======================================================

                      const Text(
                        'Password',

                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkNavy,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller:
                            _passwordController,

                        obscureText:
                            _obscurePassword,

                        enabled: !_isCreatingAccount,

                        decoration: _inputDecoration(
                          hint:
                              'Create a password',

                          icon:
                              Icons.lock_outline_rounded,

                          suffixIcon:
                              IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword =
                                    !_obscurePassword;
                              });
                            },

                            icon: Icon(
                              _obscurePassword
                                  ? Icons
                                      .visibility_off_outlined
                                  : Icons
                                      .visibility_outlined,

                              color:
                                  AppTheme.textSecondary,
                            ),
                          ),
                        ),

                        validator: (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return 'Password is required';
                          }

                          if (value.length < 8) {
                            return 'Use at least 8 characters';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // ======================================================
                      // CONFIRM PASSWORD
                      // ======================================================

                      const Text(
                        'Confirm Password',

                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkNavy,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextFormField(
                        controller:
                            _confirmPasswordController,

                        obscureText:
                            _obscureConfirmPassword,

                        enabled: !_isCreatingAccount,

                        decoration: _inputDecoration(
                          hint:
                              'Re-enter your password',

                          icon:
                              Icons.lock_outline_rounded,

                          suffixIcon:
                              IconButton(
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },

                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons
                                      .visibility_off_outlined
                                  : Icons
                                      .visibility_outlined,

                              color:
                                  AppTheme.textSecondary,
                            ),
                          ),
                        ),

                        validator: (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return 'Please confirm your password';
                          }

                          if (value !=
                              _passwordController.text) {
                            return 'Passwords do not match';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // ======================================================
                      // SECURITY MESSAGE
                      // ======================================================

                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),

                        decoration: BoxDecoration(
                          color: AppTheme.mint,
                          borderRadius:
                              BorderRadius.circular(14),
                        ),

                        child: const Row(
                          children: [

                            Icon(
                              Icons
                                  .verified_user_outlined,
                              size: 20,
                              color:
                                  AppTheme.forestGreen,
                            ),

                            SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                'Your account information is protected.',

                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color:
                                      AppTheme.forestGreen,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ======================================================
                      // CREATE ACCOUNT BUTTON
                      // ======================================================

                      SizedBox(
                        width: double.infinity,
                        height: 56,

                        child: ElevatedButton(
                          onPressed: _isCreatingAccount
                              ? null
                              : _createAccount,

                          child: _isCreatingAccount
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,

                                  children: const [

                                    Text(
                                      'CREATE ACCOUNT',

                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.w800,
                                        letterSpacing: 0.4,
                                      ),
                                    ),

                                    SizedBox(width: 10),

                                    Icon(
                                      Icons
                                          .arrow_forward_rounded,
                                      size: 20,
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ======================================================
                      // LOGIN LINK
                      // ======================================================

                      Center(
                        child: GestureDetector(
                          onTap: _isCreatingAccount
                              ? null
                              : () {
                                  Navigator.pop(context);
                                },

                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    AppTheme
                                        .textSecondary,
                              ),

                              children: [

                                TextSpan(
                                  text:
                                      'Already have an account? ',
                                ),

                                TextSpan(
                                  text: 'Login',

                                  style: TextStyle(
                                    color:
                                        AppTheme
                                            .forestGreen,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
