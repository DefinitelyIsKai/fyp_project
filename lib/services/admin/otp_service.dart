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
  static const int _otpExpiryMinutes = 10; // OTP有效期10分钟
  static const int _maxAttempts = 3; // 最大验证尝试次数

  /// 生成6位数字OTP
  String _generateOtp() {
    final random = Random();
    final otp = StringBuffer();
    for (int i = 0; i < _otpLength; i++) {
      otp.write(random.nextInt(10));
    }
    return otp.toString();
  }

  /// 发送OTP到邮箱
  /// 返回生成的OTP ID（用于后续验证）
  Future<String> sendOtp({
    required String email,
    required String adminName,
  }) async {
    try {
      // 生成OTP
      final otp = _generateOtp();
      
      // 计算过期时间
      final expiresAt = DateTime.now().add(Duration(minutes: _otpExpiryMinutes));
      
      // 获取当前认证用户（在登录流程中应该已经认证）
      final currentUser = _auth.currentUser;
      final userId = currentUser?.uid;
      
      // 保存OTP到Firestore（包含用户ID以便安全规则验证）
      final otpDoc = await _firestore.collection(_otpCollection).add({
        'email': email.trim().toLowerCase(),
        'otp': otp,
        'isUsed': false,
        'attempts': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'adminName': adminName,
        'userId': userId, // 添加用户ID用于安全规则验证
      });

      final otpId = otpDoc.id;
      
      // 发送邮件
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

  /// 验证OTP
  /// 返回验证结果
  Future<OtpVerificationResult> verifyOtp({
    required String otpId,
    required String email,
    required String otp,
  }) async {
    try {
      // 获取OTP文档
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

      // 验证邮箱是否匹配
      if (storedEmail != email.trim().toLowerCase()) {
        return OtpVerificationResult(
          success: false,
          error: 'Email mismatch. Please use the correct email.',
        );
      }

      // 验证用户ID是否匹配（安全验证）
      final storedUserId = data['userId'] as String?;
      final currentUser = _auth.currentUser;
      if (storedUserId != null && currentUser != null && storedUserId != currentUser.uid) {
        return OtpVerificationResult(
          success: false,
          error: 'OTP verification failed. User mismatch.',
        );
      }

      // 检查是否已使用
      if (isUsed) {
        return OtpVerificationResult(
          success: false,
          error: 'This OTP has already been used. Please request a new OTP.',
        );
      }

      // 检查是否过期
      if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
        return OtpVerificationResult(
          success: false,
          error: 'OTP has expired. Please request a new OTP.',
        );
      }

      // 检查尝试次数
      if (attempts >= _maxAttempts) {
        return OtpVerificationResult(
          success: false,
          error: 'Maximum verification attempts exceeded. Please request a new OTP.',
        );
      }

      // 验证OTP
      if (storedOtp != otp.trim()) {
        // 增加尝试次数（如果安全规则允许）
        try {
          await _firestore.collection(_otpCollection).doc(otpId).update({
            'attempts': FieldValue.increment(1),
          });
        } catch (e) {
          // 如果更新失败（权限问题），记录错误但继续
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

      // OTP验证成功，标记为已使用
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

  /// 检查是否有有效的未使用OTP（用于防止频繁发送）
  Future<bool> hasActiveOtp(String email) async {
    try {
      final now = DateTime.now();
      final nowTimestamp = Timestamp.fromDate(now);
      
      // Query for active OTPs (not used and not expired)
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
      // If query fails (e.g., composite index needed), return false to allow sending
      return false;
    }
  }
}

/// OTP验证结果
class OtpVerificationResult {
  final bool success;
  final String? error;

  OtpVerificationResult({
    required this.success,
    this.error,
  });
}

