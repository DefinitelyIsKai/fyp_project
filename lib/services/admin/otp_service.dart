import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../user/email_service.dart';

class OtpService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EmailService _emailService = EmailService();
  
  static const String _otpCollection = 'admin_otps';
  static const int _otpLength = 6;
  static const int _otpExpiryMinutes = 10;
  static const int _maxAttempts = 3;

  String _generateOtp() {
    final random = Random();
    final otp = StringBuffer();
    for (int i = 0; i < _otpLength; i++) {
      otp.write(random.nextInt(10));
    }
    return otp.toString();
  }

  Future<String> sendOtp({
    required String email,
    required String adminName,
  }) async {
    try {
      final otp = _generateOtp();
      
      final expiresAt = DateTime.now().add(Duration(minutes: _otpExpiryMinutes));
      
      final currentUser = _auth.currentUser;
      final userId = currentUser?.uid;
      
      final otpDoc = await _firestore.collection(_otpCollection).add({
        'email': email.trim().toLowerCase(),
        'otp': otp,
        'isUsed': false,
        'attempts': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'adminName': adminName,
        'userId': userId,
      });

      final otpId = otpDoc.id;
      
      await _emailService.sendOtpEmail(
        recipientEmail: email,
        recipientName: adminName,
        otp: otp,
      );

      debugPrint('OTP sent successfully to $email. OTP ID: $otpId');
      return otpId;
    } catch (e) {
      debugPrint('Error sending OTP: $e');
      rethrow;
    }
  }

  Future<OtpVerificationResult> verifyOtp({
    required String otpId,
    required String email,
    required String otp,
  }) async {
    try {
      final otpDoc = await _firestore.collection(_otpCollection).doc(otpId).get();
      
      if (!otpDoc.exists) {
        return OtpVerificationResult(
          success: false,
          error: 'OTP not found. Please request a new OTP.',
        );
      }

      final data = otpDoc.data()!;
      final storedEmail = (data['email'] as String?)?.toLowerCase() ?? '';
      final storedOtp = data['otp'] as String? ?? '';
      final isUsed = data['isUsed'] as bool? ?? false;
      final attempts = data['attempts'] as int? ?? 0;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

      if (storedEmail != email.trim().toLowerCase()) {
        return OtpVerificationResult(
          success: false,
          error: 'Email mismatch. Please use the correct email.',
        );
      }

      final storedUserId = data['userId'] as String?;
      final currentUser = _auth.currentUser;
      if (storedUserId != null && currentUser != null && storedUserId != currentUser.uid) {
        return OtpVerificationResult(
          success: false,
          error: 'OTP verification failed. User mismatch.',
        );
      }

      if (isUsed) {
        return OtpVerificationResult(
          success: false,
          error: 'This OTP has already been used. Please request a new OTP.',
        );
      }

      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        return OtpVerificationResult(
          success: false,
          error: 'OTP has expired. Please request a new OTP.',
        );
      }

      if (attempts >= _maxAttempts) {
        return OtpVerificationResult(
          success: false,
          error: 'Maximum verification attempts exceeded. Please request a new OTP.',
        );
      }

      if (storedOtp != otp.trim()) {
        try {
          await _firestore.collection(_otpCollection).doc(otpId).update({
            'attempts': FieldValue.increment(1),
          });
        } catch (e) {
          debugPrint('Warning: Failed to update attempts counter: $e');
          debugPrint('Please configure Firestore security rules to allow updating attempts field');
        }

        final remainingAttempts = _maxAttempts - (attempts + 1);
        return OtpVerificationResult(
          success: false,
          error: remainingAttempts > 0
              ? 'Invalid OTP. $remainingAttempts attempt(s) remaining.'
              : 'Invalid OTP. Maximum attempts exceeded. Please request a new OTP.',
        );
      }

      await _firestore.collection(_otpCollection).doc(otpId).update({
        'isUsed': true,
        'usedAt': FieldValue.serverTimestamp(),
      });

      return OtpVerificationResult(
        success: true,
        error: null,
      );
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      return OtpVerificationResult(
        success: false,
        error: 'Verification failed: ${e.toString()}',
      );
    }
  }

  Future<bool> hasActiveOtp(String email) async {
    try {
      final now = DateTime.now();
      final nowTimestamp = Timestamp.fromDate(now);
      
      final querySnapshot = await _firestore
          .collection(_otpCollection)
          .where('email', isEqualTo: email.trim().toLowerCase())
          .where('isUsed', isEqualTo: false)
          .where('expiresAt', isGreaterThan: nowTimestamp)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking active OTP: $e');
      return false;
    }
  }
}

class OtpVerificationResult {
  final bool success;
  final String? error;

  OtpVerificationResult({
    required this.success,
    this.error,
  });
}
