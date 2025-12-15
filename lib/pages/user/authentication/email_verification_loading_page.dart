import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/user/auth_service.dart';
import '../../../utils/user/dialog_utils.dart';
import 'login_page.dart';

class EmailVerificationLoadingPage extends StatefulWidget {
  const EmailVerificationLoadingPage({super.key});

  @override
  State<EmailVerificationLoadingPage> createState() => _EmailVerificationLoadingPageState();
}

class _EmailVerificationLoadingPageState extends State<EmailVerificationLoadingPage> {
  final AuthService _authService = AuthService();
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  bool _checking = false;
  bool _resending = false;
  int _resendCooldown = 0; 

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerified());
  }

  Future<void> _checkVerified() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final verified = await _authService.refreshAndCheckEmailVerified();
      if (!mounted) return;
      if (verified) {
        _pollTimer?.cancel();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    } catch (e) {
      DialogUtils.showWarningMessage(
        context: context, 
        message: 'Not verified(network error): $e',
      );
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendCooldown > 0) return;
    setState(() => _resending = true);
    try {
      await _authService.resendVerificationEmail();
      if (!mounted) return;
      DialogUtils.showSuccessMessage(
        context: context,
        message: 'Verification email resent. Please check your inbox.',
      );
      if (mounted) {
        setState(() {
          _resendCooldown = 60;
        });
        _startResendCooldown();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = 'Failed to resend verification email.';
      
      if (e.code == 'too-many-requests') {
        errorMessage = 'Too many requests. Please wait a few minutes before trying again.';
        if (mounted) {
          setState(() {
            _resendCooldown = 300;
          });
          _startResendCooldown();
        }
      } else if (e.code == 'user-not-found') {
        errorMessage = 'User account not found. Please sign up again.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled.';
      } else {
        errorMessage = 'Failed to resend: ${e.message ?? e.code}';
      }
      
      DialogUtils.showWarningMessage(
        context: context,
        message: errorMessage,
      );
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'Failed to resend verification email.';
      if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Too many requests. Please wait a few minutes before trying again.';
        if (mounted) {
          setState(() {
            _resendCooldown = 300;
          });
          _startResendCooldown();
        }
      } else {
        errorMessage = 'Failed to resend: $e';
      }
      DialogUtils.showWarningMessage(
        context: context,
        message: errorMessage,
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF00C8A0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    color: primaryColor,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Verify Your Email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'A sent a verification link to your email.\nPlease check your inbox and click the link to verify your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(
                  color: Color(0xFF00C8A0),
                ),
                const SizedBox(height: 40),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_resending || _resendCooldown > 0) ? null : _resend,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _resending
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _resendCooldown > 0
                                    ? 'Resend in ${_resendCooldown}s'
                                    : 'Resend Email',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _checking ? null : _checkVerified,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _checking
                            ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: primaryColor,
                                ),
                              )
                            : const Text(
                                "I've Verified",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This page will automatically advance once your email is verified.',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


