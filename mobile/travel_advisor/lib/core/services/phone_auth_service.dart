import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PhoneAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Formats any Indian mobile number into E.164 format (+91XXXXXXXXXX)
  static String formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '').trim();
    if (cleaned.startsWith('+91')) {
      return cleaned;
    }
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      return '+$cleaned';
    }
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return '+91$cleaned';
  }

  /// Sends a real cellular SMS OTP via Firebase Phone Auth
  static Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String smsCode) onAutoRetrieval,
    required void Function(String errorMessage) onError,
    int? resendToken,
  }) async {
    final formattedNumber = formatPhoneNumber(phoneNumber);
    debugPrint('Dispatching Firebase cellular SMS to $formattedNumber');

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('Automatic SMS verification triggered by Android');
          try {
            await _auth.signInWithCredential(credential);
            final smsCode = credential.smsCode ?? '';
            onAutoRetrieval(smsCode);
          } catch (e) {
            debugPrint('Error signing in with auto credential: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Firebase phone verification failed: ${e.code} - ${e.message}');
          String message = e.message ?? 'Failed to send SMS code.';
          if (e.code == 'invalid-phone-number') {
            message = 'Please enter a valid 10-digit mobile number.';
          } else if (e.code == 'too-many-requests') {
            message = 'Too many requests. Please wait a few minutes before trying again.';
          } else if (e.code == 'quota-exceeded') {
            message = 'SMS quota exceeded. Please try again later.';
          }
          onError(message);
        },
        codeSent: (String verificationId, int? newResendToken) {
          debugPrint('Firebase SMS code dispatched successfully. Verification ID: $verificationId');
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('Firebase SMS auto-retrieval timeout');
        },
      );
    } catch (e) {
      debugPrint('Unexpected error in verifyPhoneNumber: $e');
      onError('Unable to initiate SMS delivery. Please try again.');
    }
  }

  /// Verifies the entered SMS OTP against Firebase
  static Future<bool> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user != null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error verifying Firebase OTP: ${e.code} - ${e.message}');
      throw e.message ?? 'Invalid verification code.';
    } catch (e) {
      debugPrint('Unexpected error in verifyOtp: $e');
      throw 'Verification failed. Please check the code and try again.';
    }
  }
}
