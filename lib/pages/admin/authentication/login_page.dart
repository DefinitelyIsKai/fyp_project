import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:fyp_project/services/admin/profile_pic_service.dart';
import 'package:fyp_project/services/admin/face_recognition_service.dart';
import 'package:fyp_project/services/admin/otp_service.dart';
import 'package:fyp_project/routes/app_routes.dart';
import 'package:provider/provider.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:fyp_project/pages/user/authentication/login_page.dart' as user_login;
import 'package:fyp_project/widgets/user/loading_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  
  bool _enableFaceRecognition = true;
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _profilePicService = ProfilePicService();
  final _faceService = FaceRecognitionService();
  final _otpService = OtpService();
  final CollectionReference<Map<String, dynamic>> _logsRef = 
      FirebaseFirestore.instance.collection('logs');
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _capturedImageBase64; 
  Uint8List? _capturedImageBytes; 
  bool _isDetectingFace = false; 
  bool? _faceDetected; 
  Face? _detectedFace; 
  
  bool _showOtpInput = false;
  String? _otpId;
  String? _pendingEmail;
  String? _pendingAdminName;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  int _otpResendCooldown = 0; 

  @override
  void initState() {
    super.initState();
    _initializeFaceService();
  }

  Future<void> _initializeFaceService() async {
    try {
      await _faceService.initialize();
    } catch (e) {
      debugPrint('Error initializing face service: $e');
    }
  }

  @override
  void dispose() {
    
    _capturedImageBase64 = null;
    _capturedImageBytes = null;
    _faceDetected = null;
    _detectedFace = null;
    _isDetectingFace = false;
    _isLoading = false;
    
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final result = await _profilePicService.pickImageBase64(fromCamera: true);
      if (result != null && mounted) {
        setState(() {
          _capturedImageBase64 = result['base64'];
          _capturedImageBytes = base64Decode(_capturedImageBase64!);
          _faceDetected = null; 
          _detectedFace = null; 
        });
        
        await _detectFaceInImage();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _faceDetected = false;
          _isDetectingFace = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _detectFaceInImage() async {
    if (_capturedImageBytes == null) return;
    
    setState(() {
      _isDetectingFace = true;
      _faceDetected = null;
    });
    
    try {
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/face_detection_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(_capturedImageBytes!);
      
      final inputImage = InputImage.fromFilePath(tempFile.path);
      
      final faces = await _faceService.detectFaces(inputImage);
      
      try {
        await tempFile.delete();
      } catch (e) {
        debugPrint('Failed to delete temp file: $e');
      }
      
      if (mounted) {
        setState(() {
          _faceDetected = faces.isNotEmpty;
          _isDetectingFace = false;
          
          _detectedFace = faces.isNotEmpty ? faces.first : null;
        });
        
        if (faces.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No face detected. Please take another photo with your face clearly visible.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Face detected! ${faces.length} face(s) found.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _faceDetected = false;
          _isDetectingFace = false;
        });
        debugPrint('Error detecting face: $e');
      }
    }
  }

  void _removeImage() {
    setState(() {
      _capturedImageBase64 = null;
      _capturedImageBytes = null;
      _faceDetected = null;
      _detectedFace = null;
      _isDetectingFace = false;
    });
  }

  Future<void> _verifyFace(String profileImageBase64) async {
    if (_capturedImageBase64 == null || _capturedImageBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please take a photo first'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    if (_faceDetected != true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No face detected. Please take another photo with your face clearly visible.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verifying Identity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we verify your face...',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    setState(() => _isLoading = true);

    try {
      print('========== Face Verification Started ==========');
      print('Time: ${DateTime.now()}');
      print('Profile image base64 length: ${profileImageBase64.length}');
      print('Captured image bytes length: ${_capturedImageBytes!.length}');
      print('Face detected: $_faceDetected');
      print('Detected face: ${_detectedFace != null ? "Yes" : "No"}');

      print('Decoding captured image...');
      final capturedImage = img.decodeImage(_capturedImageBytes!);
      if (capturedImage == null) {
        throw Exception('Failed to decode captured image');
      }
      print('Captured image decoded: ${capturedImage.width}x${capturedImage.height}');

      print('Starting face comparison...');
      print('Calling compareFaces with profile image and captured image...');
      final similarity = await _faceService.compareFaces(
        profileImageBase64,
        capturedImage,
        _detectedFace,
      );

      print('========== Face Verification Result ==========');
      print('Similarity score: $similarity');
      print('Threshold: 0.96');
      print('Verification ${similarity >= 0.96 ? "SUCCESS" : "FAILED"}');
      print('Similarity difference: ${(similarity - 0.96).toStringAsFixed(4)}');
      print('==============================================');

      const threshold = 0.96;

      final email = _emailController.text.trim();
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentAdmin;

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (similarity >= threshold) {
        
        print('Verification SUCCESS - Navigating to dashboard');
        
        // Set isLogin to true only after successful face verification
        await authService.setLoginStatus(true);
        
        _logLoginSuccess(
          email: email,
          userId: currentUser?.id,
          userName: currentUser?.name,
        );

        _clearLoginResources();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome, ${currentUser?.name ?? 'Admin'}!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
        }
      } else {
        
        print('Verification FAILED - Logging out user');
        _logFaceVerificationFailure(
          email: email,
          userId: currentUser?.id,
          userName: currentUser?.name,
        );

        _clearLoginResources();

        if (mounted) {
          setState(() => _isLoading = false);
          authService.logout();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Face verification failed. Similarity: ${(similarity * 100).toStringAsFixed(1)}% (Required: 96.0%)'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('========== Face Verification Error ==========');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('Time: ${DateTime.now()}');
      print('=============================================');

      final email = _emailController.text.trim();
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentAdmin;

      _logFaceVerificationError(
        email: email,
        userId: currentUser?.id,
        userName: currentUser?.name,
        error: e.toString(),
      );

      if (mounted) {
        Navigator.of(context).pop();
      }

      _clearLoginResources();

      if (mounted) {
        setState(() => _isLoading = false);
        authService.logout();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Face verification error: ${e.toString().length > 100 ? e.toString().substring(0, 100) + "..." : e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (result.success) {
        
        if (!_enableFaceRecognition) {
          
          print('Face recognition is disabled, using OTP verification');
          final currentUser = authService.currentAdmin;
          if (currentUser != null) {
            
            await _sendOtpAndShowInput(
              email: _emailController.text.trim(),
              adminName: currentUser.name,
            );
          } else {
            
            // If no current user but login succeeded, set isLogin to true
            // This handles edge case where verification is skipped
            await authService.setLoginStatus(true);
            
            if (mounted) {
              Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
            }
          }
          return;
        }
        
        final currentUser = authService.currentAdmin;
        if (currentUser != null) {
          try {
            
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.id)
                .get();
            
            final userData = userDoc.data();
            print('User data: ${userData?.keys.toList()}');
            
            final imageData = userData?['image'] as Map<String, dynamic>?;
            print('Image data: $imageData');
            print('Image data type: ${imageData?.runtimeType}');
            
            final profileImageBase64 = imageData?['base64'] as String?;
            print('Base64 string length: ${profileImageBase64?.length ?? 0}');
            print('Base64 is empty: ${profileImageBase64?.isEmpty ?? true}');
            
            if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
              print('Starting face verification, base64 length: ${profileImageBase64.length}');
              
              if (mounted) {
                setState(() => _isLoading = false);
                await _verifyFace(profileImageBase64);
              }
            } else {
              
              print('Error: Profile photo base64 field is empty or does not exist');
              if (mounted) {
                authService.logout();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No profile photo found. Please upload a profile photo first. The image.base64 field is empty.'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            }
          } catch (e, stackTrace) {
            final email = _emailController.text.trim();
            final currentUser = authService.currentAdmin;
            
            _logFaceVerificationError(
              email: email,
              userId: currentUser?.id,
              userName: currentUser?.name,
              error: e.toString(),
            );
            
            print('========== Face Verification Preparation Error ==========');
            print('Reason: Error while getting profile photo or preparing verification');
            print('Error Type: ${e.runtimeType}');
            print('Error: $e');
            print('Stack Trace: $stackTrace');
            print('Time: ${DateTime.now()}');
            print('========================================================');
            
            _clearLoginResources();
            
            if (mounted) {
              authService.logout();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Face verification preparation failed: ${e.toString().length > 100 ? e.toString().substring(0, 100) + "..." : e.toString()}'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        } else {
          // If no current user but login succeeded, set isLogin to true
          // This handles edge case where verification is skipped
          await authService.setLoginStatus(true);
          
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
          }
        }
      } else {
        
        final errorMessage = result.error ?? 'Login failed. Please try again.';
        final email = _emailController.text.trim();
        
        _logLoginFailure(email: email, reason: errorMessage);
        
        print('========== Login Failed ==========');
        print('Reason: Password incorrect or account verification failed');
        print('Error: $errorMessage');
        print('Email: $email');
        print('Time: ${DateTime.now()}');
        print('=================================');
        
        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        }
        
        _clearLoginResources();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearCapturedImage() {
    if (mounted) {
      setState(() {
        _capturedImageBase64 = null;
        _capturedImageBytes = null;
        _faceDetected = null;
        _detectedFace = null;
        _isDetectingFace = false;
      });
    }
  }
  
  void _clearLoginResources() {
    print('Cleaning up login resources...');
    _clearCapturedImage();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
    print('Login resources cleaned up');
  }
  
  Future<void> _logLoginSuccess({
    required String email,
    String? userId,
    String? userName,
  }) async {
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      await _logsRef.add({
        'actionType': 'admin_login_success',
        'email': email,
        'userId': userId,
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminId ?? userId,
      });
    } catch (e) {
      print('Error creating login success log entry: $e');
      
    }
  }
  
  Future<void> _logLoginFailure({
    required String email,
    required String reason,
  }) async {
    try {
      await _logsRef.add({
        'actionType': 'admin_login_failed',
        'email': email,
        'reason': reason,
        'failureType': 'password_incorrect',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': null, 
      });
    } catch (e) {
      print('Error creating login failure log entry: $e');
      
    }
  }
  
  Future<void> _logFaceVerificationFailure({
    required String email,
    String? userId,
    String? userName,
  }) async {
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      await _logsRef.add({
        'actionType': 'admin_face_verification_failed',
        'email': email,
        'userId': userId,
        'userName': userName,
        'reason': 'Face mismatch - similarity below threshold',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminId ?? userId,
      });
    } catch (e) {
      print('Error creating face verification failure log entry: $e');
      
    }
  }
  
  Future<void> _logFaceVerificationError({
    required String email,
    String? userId,
    String? userName,
    required String error,
  }) async {
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      await _logsRef.add({
        'actionType': 'admin_face_verification_error',
        'email': email,
        'userId': userId,
        'userName': userName,
        'error': error,
        'reason': 'Face verification process error',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminId ?? userId,
      });
    } catch (e) {
      print('Error creating face verification error log entry: $e');
      
    }
  }

  void _navigateToForgotPassword() {
    Navigator.of(context).pushNamed(AppRoutes.adminForgotPassword);
  }

  Future<void> _sendOtpAndShowInput({
    required String email,
    required String adminName,
  }) async {
    setState(() {
      _isSendingOtp = true;
      _isLoading = false;
    });

    LoadingDialog.show(
      context: context,
      message: 'Sending OTP...',
    );

    try {
      
      final hasActiveOtp = await _otpService.hasActiveOtp(email);
      if (hasActiveOtp) {
        if (mounted) {
          LoadingDialog.hide(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('An OTP has already been sent. Please check your email or wait a moment before requesting a new one.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() {
          _isSendingOtp = false;
        });
        return;
      }

      final otpId = await _otpService.sendOtp(
        email: email,
        adminName: adminName,
      );

      if (mounted) {
        LoadingDialog.hide(context);
        setState(() {
          _showOtpInput = true;
          _otpId = otpId;
          _pendingEmail = email;
          _pendingAdminName = adminName;
          _otpResendCooldown = 60; 
          _isSendingOtp = false;
        });

        _startOtpResendCooldown();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP has been sent to your email. Please check your inbox.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        LoadingDialog.hide(context);
        setState(() {
          _isSendingOtp = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send OTP: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _startOtpResendCooldown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _otpResendCooldown > 0) {
        setState(() {
          _otpResendCooldown--;
        });
        return true;
      }
      return false;
    });
  }

  Future<void> _verifyOtpAndLogin() async {
    if (_otpId == null || _pendingEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP session expired. Please login again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit OTP.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
    });

    try {
      final result = await _otpService.verifyOtp(
        otpId: _otpId!,
        email: _pendingEmail!,
        otp: otp,
      );

      if (!mounted) return;

      if (result.success) {
        
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentAdmin;
        
        // Set isLogin to true only after successful OTP verification
        await authService.setLoginStatus(true);
        
        _logLoginSuccess(
          email: _pendingEmail!,
          userId: currentUser?.id,
          userName: currentUser?.name,
        );

        setState(() {
          _showOtpInput = false;
          _otpId = null;
          _pendingEmail = null;
          _pendingAdminName = null;
          _otpController.clear();
          _isVerifyingOtp = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome, ${currentUser?.name ?? 'Admin'}!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
        }
      } else {
        setState(() {
          _isVerifyingOtp = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'OTP verification failed'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifyingOtp = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP verification error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_pendingEmail == null || _pendingAdminName == null) return;
    if (_otpResendCooldown > 0) return;

    await _sendOtpAndShowInput(
      email: _pendingEmail!,
      adminName: _pendingAdminName!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primaryMedium,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
                            size: 64,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Admin Login',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'JobSeek Administration Portal',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter your email';
                            if (!value.contains('@')) return 'Please enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter your password';
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _navigateToForgotPassword,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[50],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.face, size: 24, color: Colors.blue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Enable Face Recognition',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _enableFaceRecognition
                                          ? 'Face verification required for login'
                                          : 'Login without face verification',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _enableFaceRecognition,
                                onChanged: (value) {
                                  setState(() {
                                    _enableFaceRecognition = value;
                                    
                                    if (!value) {
                                      _capturedImageBase64 = null;
                                      _capturedImageBytes = null;
                                      _faceDetected = null;
                                      _detectedFace = null;
                                    }
                                  });
                                },
                                activeColor: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                        
                        if (_enableFaceRecognition) ...[
                          const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[50],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Face Verification Photo',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_capturedImageBytes != null) ...[
                                
                                Center(
                                  child: Stack(
                                  children: [
                                    Container(
                                        width: 200,
                                      height: 200,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _faceDetected == true 
                                                ? Colors.green 
                                                : _faceDetected == false 
                                                    ? Colors.red 
                                                    : Colors.grey[300]!,
                                            width: 3,
                                          ),
                                      ),
                                        child: ClipOval(
                                          child: Stack(
                                            children: [
                                              Image.memory(
                                          _capturedImageBytes!,
                                          fit: BoxFit.cover,
                                                width: 200,
                                                height: 200,
                                              ),
                                              if (_isDetectingFace)
                                                Container(
                                                  color: Colors.black54,
                                                  child: const Center(
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        CircularProgressIndicator(color: Colors.white),
                                                        SizedBox(height: 8),
                                                        Text(
                                                          'Detecting face...',
                                                          style: TextStyle(color: Colors.white),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                        top: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: _removeImage,
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.red,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 18,
                                        ),
                                          ),
                                      ),
                                    ),
                                  ],
                                ),
                                ),
                                
                                if (_faceDetected != null && !_isDetectingFace) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _faceDetected == true 
                                          ? Colors.green 
                                          : Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _faceDetected == true 
                                              ? Icons.check_circle 
                                              : Icons.error,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _faceDetected == true 
                                              ? 'Face detected ✓' 
                                              : 'No face detected',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                if (_faceDetected == false)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange[200]!),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'No face detected. Please take another photo with your face clearly visible.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange[900],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ] else ...[
                                
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _takePhoto,
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Take Photo for Verification'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Please take a live photo for face verification',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                        ],
                        
                        if (_showOtpInput) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue[300]!),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.blue[50],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.email, color: Colors.blue[700], size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Enter Verification Code',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'A 6-digit code has been sent to ${_pendingEmail ?? "your email"}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _otpController,
                                  decoration: const InputDecoration(
                                    labelText: 'Verification Code',
                                    prefixIcon: Icon(Icons.lock_outline),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    letterSpacing: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter the verification code';
                                    }
                                    if (value.length != 6) {
                                      return 'Code must be 6 digits';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                      onPressed: (_otpResendCooldown > 0 || _isSendingOtp) ? null : _resendOtp,
                                      child: Text(
                                        _isSendingOtp
                                            ? 'Sending...'
                                            : _otpResendCooldown > 0
                                                ? 'Resend in ${_otpResendCooldown}s'
                                                : 'Resend Code',
                                        style: TextStyle(
                                          color: (_otpResendCooldown > 0 || _isSendingOtp)
                                              ? Colors.grey
                                              : Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _showOtpInput = false;
                                          _otpId = null;
                                          _pendingEmail = null;
                                          _pendingAdminName = null;
                                          _otpController.clear();
                                          _otpResendCooldown = 0;
                                        });
                                      },
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(color: Colors.grey[700]),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isVerifyingOtp ? null : _verifyOtpAndLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[700],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: _isVerifyingOtp
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text('Verify & Login', style: TextStyle(fontSize: 16)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_isLoading || _showOtpInput) ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Login', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Only authorized admin users can access this portal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[900],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Divider(thickness: 1, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.switch_account, size: 20, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Are you a job seeker or recruiter?',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                            builder: (_) => const user_login.LoginPage(),
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.login, size: 18),
                                label: const Text(
                                  'Switch to User Login',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primaryDark,
                                  side: BorderSide(color: AppColors.primaryDark),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
