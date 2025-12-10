import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user/auth_service.dart';
import '../../../services/user/storage_service.dart';
import '../../../utils/user/dialog_utils.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final AuthService _authService = AuthService();
  final StorageService _storage = StorageService();
  
  Uint8List? _icImageBytes;
  Uint8List? _selfieImageBytes;
  String? _icImageBase64;
  String? _selfieImageBase64;
  bool _isSubmitting = false;
  bool _isUploadingIc = false;
  bool _isUploadingSelfie = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Account Verification',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please upload your IC (Identity Card) and a clear selfie for account verification. This helps us ensure account security.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[900],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Status Info
            _buildStatusInfo(),
            
            const SizedBox(height: 24),
            
            // IC Upload Section
            _buildUploadSection(
              title: 'Identity Card (IC)',
              subtitle: 'Upload a clear photo of your identity card',
              imageBytes: _icImageBytes,
              isUploading: _isUploadingIc,
              onTap: () => _pickImage(isIc: true),
            ),
            
            const SizedBox(height: 24),
            
            // Selfie Upload Section
            _buildUploadSection(
              title: 'Selfie Photo',
              subtitle: 'Upload a clear selfie photo of yourself',
              imageBytes: _selfieImageBytes,
              isUploading: _isUploadingSelfie,
              onTap: () => _pickImage(isIc: false),
            ),
            
            const SizedBox(height: 32),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_icImageBytes == null || _selfieImageBytes == null || _isSubmitting)
                    ? null
                    : _submitVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C8A0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit for Verification',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection({
    required String title,
    required String subtitle,
    required Uint8List? imageBytes,
    required bool isUploading,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C8A0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.upload_file,
                  color: Color(0xFF00C8A0),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: isUploading ? null : onTap,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: imageBytes != null 
                      ? const Color(0xFF00C8A0) 
                      : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: isUploading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00C8A0),
                      ),
                    )
                  : imageBytes != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                imageBytes,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C8A0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Change',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tap to upload',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo() {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _authService.getUserDoc(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final data = snapshot.data?.data();
        final verificationStatus = data?['verificationStatus'] as String?;
        
        if (verificationStatus == null) return const SizedBox.shrink();
        
        Color statusColor;
        IconData statusIcon;
        String statusText;
        String statusMessage;
        
        switch (verificationStatus.toLowerCase()) {
          case 'pending':
            statusColor = Colors.orange;
            statusIcon = Icons.pending;
            statusText = 'Pending Review';
            statusMessage = 'Your verification request is under review. Please wait for admin approval.';
            break;
          case 'approved':
            statusColor = Colors.green;
            statusIcon = Icons.verified;
            statusText = 'Verified';
            statusMessage = 'Your account has been verified successfully.';
            break;
          case 'rejected':
            statusColor = Colors.red;
            statusIcon = Icons.cancel;
            statusText = 'Rejected';
            final rejectionReason = data?['verificationRejectionReason'] as String?;
            statusMessage = rejectionReason != null && rejectionReason.isNotEmpty
                ? 'Verification rejected: $rejectionReason'
                : 'Your verification request was rejected. Please try again with clearer photos.';
            break;
          default:
            return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage({required bool isIc}) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Text(
                isIc ? 'Upload IC Photo' : 'Upload Selfie',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Color(0xFF00C8A0)),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF00C8A0)),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    
    if (source == null) return;
    
    if (isIc) {
      setState(() => _isUploadingIc = true);
    } else {
      setState(() => _isUploadingSelfie = true);
    }
    
    try {
      final imageBytes = await _storage.pickImageBytes(fromCamera: source == 'camera');
      
      if (imageBytes != null && mounted) {
        final base64String = base64Encode(imageBytes);
        
        setState(() {
          if (isIc) {
            _icImageBytes = imageBytes;
            _icImageBase64 = base64String;
            _isUploadingIc = false;
          } else {
            _selfieImageBytes = imageBytes;
            _selfieImageBase64 = base64String;
            _isUploadingSelfie = false;
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _isUploadingIc = false;
            _isUploadingSelfie = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingIc = false;
          _isUploadingSelfie = false;
        });
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Failed to pick image: $e',
        );
      }
    }
  }

  Future<void> _submitVerification() async {
    if (_icImageBase64 == null || _selfieImageBase64 == null) {
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Please upload both IC and selfie photos',
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'verificationRequest': {
          'documents': [
            {
              'name': 'Identity Card',
              'base64': _icImageBase64,
              'type': 'ic',
            },
            {
              'name': 'Selfie Photo',
              'base64': _selfieImageBase64,
              'type': 'selfie',
            },
          ],
          'images': [
            {
              'base64': _icImageBase64,
              'type': 'ic',
            },
            {
              'base64': _selfieImageBase64,
              'type': 'selfie',
            },
          ],
          'submittedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        },
        'verificationStatus': 'pending',
        'isVerified': false,
      });
      
      if (!mounted) return;
      
      DialogUtils.showSuccessMessage(
        context: context,
        message: 'Verification request submitted successfully. Please wait for admin review.',
      );
      
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Failed to submit verification: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

