import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:fyp_project/services/admin/profile_pic_service.dart';
import 'package:fyp_project/services/admin/face_recognition_service.dart';
import 'package:fyp_project/widgets/admin/dialogs/user_dialogs/image_preview_dialog.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class AddAdminImageStep extends StatelessWidget {
  final ValueNotifier<String?> selectedImageBase64Notifier;
  final ValueNotifier<String?> selectedImageFileTypeNotifier;
  final ValueNotifier<bool> isPickingImageNotifier;
  final ValueNotifier<bool> isImageUploadedNotifier;
  final ValueNotifier<bool?> faceDetectedNotifier;
  final ValueNotifier<bool> isDetectingFaceNotifier;
  final VoidCallback onNext;
  final Map<String, Uint8List> imageCache;

  const AddAdminImageStep({
    super.key,
    required this.selectedImageBase64Notifier,
    required this.selectedImageFileTypeNotifier,
    required this.isPickingImageNotifier,
    required this.isImageUploadedNotifier,
    required this.faceDetectedNotifier,
    required this.isDetectingFaceNotifier,
    required this.onNext,
    required this.imageCache,
  });

  Future<Map<String, String>?> _pickImageBase64(BuildContext context) async {
    try {
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
                const Text(
                  'Select Profile Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_camera, color: Colors.blue),
                  ),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.photo_library, color: Colors.blue),
                  ),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );

      if (source == null) return null;

      final profilePicService = ProfilePicService();
      return await profilePicService.pickImageBase64(fromCamera: source == 'camera');
    } catch (e) {
      if (context.mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
      return null;
    }
  }

  Future<void> _detectFaceInImage(
    BuildContext context,
    String imageBase64,
    FaceRecognitionService faceService,
  ) async {
    isDetectingFaceNotifier.value = true;
    faceDetectedNotifier.value = null;
    
    try {
      await faceService.initialize();
      
      final imageBytes = base64Decode(imageBase64);
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/face_detection_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes);
      
      final inputImage = InputImage.fromFilePath(tempFile.path);
      
      final faces = await faceService.detectFaces(inputImage);
      
      try {
        await tempFile.delete();
      } catch (e) {
        debugPrint('Failed to delete temp file: $e');
      }
      
      if (context.mounted) {
        faceDetectedNotifier.value = faces.isNotEmpty;
        isDetectingFaceNotifier.value = false;
        
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
      if (context.mounted) {
        faceDetectedNotifier.value = false;
        isDetectingFaceNotifier.value = false;
        debugPrint('Error detecting face: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error detecting face: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildPreviewImage(String base64String) {
    try {
      final cleanBase64 = base64String.trim().replaceAll(RegExp(r'\s+'), '');
      Uint8List bytes = imageCache[cleanBase64] ?? base64Decode(cleanBase64);
      if (!imageCache.containsKey(cleanBase64)) {
        imageCache[cleanBase64] = bytes;
      }
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: 200,
        height: 200,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[100],
            child: Icon(Icons.broken_image, color: Colors.red[300], size: 40),
          );
        },
      );
    } catch (e) {
      return Container(
        width: 200,
        height: 200,
        color: Colors.grey[100],
        child: Icon(Icons.broken_image, color: Colors.red[300], size: 40),
      );
    }
  }

  void _showImagePreview(BuildContext context, String base64String) {
    ImagePreviewDialog.show(
      context: context,
      base64String: base64String,
      imageCache: imageCache,
    );
  }

  @override
  Widget build(BuildContext context) {
    final faceService = FaceRecognitionService();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Upload Profile Photo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please upload or take a photo for the admin profile',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          
          ValueListenableBuilder<String?>(
            valueListenable: selectedImageBase64Notifier,
            builder: (context, selectedImageBase64, _) => ValueListenableBuilder<bool>(
              valueListenable: isPickingImageNotifier,
              builder: (context, isPickingImage, _) => GestureDetector(
                onTap: isPickingImage ? null : () async {
                  isPickingImageNotifier.value = true;
                  try {
                    final imageData = await _pickImageBase64(context);
                    if (imageData != null && imageData['base64'] != null) {
                      final cleanBase64 = imageData['base64']!.trim().replaceAll(RegExp(r'\s+'), '');
                      selectedImageBase64Notifier.value = cleanBase64;
                      selectedImageFileTypeNotifier.value = imageData['fileType'];
                      isPickingImageNotifier.value = false;
                      
                      faceDetectedNotifier.value = null;
                      
                      await _detectFaceInImage(
                        context,
                        cleanBase64,
                        faceService,
                      );
                      
                      isImageUploadedNotifier.value = faceDetectedNotifier.value == true;
                    } else {
                      isPickingImageNotifier.value = false;
                      isImageUploadedNotifier.value = false;
                    }
                  } catch (e) {
                    isPickingImageNotifier.value = false;
                    isImageUploadedNotifier.value = false;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(e.toString().replaceFirst('Exception: ', '')),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectedImageBase64 != null ? Colors.green : Colors.grey[300]!,
                      width: 3,
                    ),
                    color: selectedImageBase64 != null ? Colors.green[50] : Colors.grey[50],
                  ),
                  child: isPickingImage
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : selectedImageBase64 != null
                          ? ClipOval(
                              child: _buildPreviewImage(selectedImageBase64),
                            )
                          : Icon(
                              Icons.add_photo_alternate,
                              color: Colors.grey[400],
                              size: 64,
                            ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          ValueListenableBuilder<bool?>(
            valueListenable: faceDetectedNotifier,
            builder: (context, faceDetected, _) => ValueListenableBuilder<bool>(
              valueListenable: isDetectingFaceNotifier,
              builder: (context, isDetectingFace, _) {
                if (selectedImageBase64Notifier.value == null) {
                  return const SizedBox.shrink();
                }
                if (isDetectingFace) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Detecting face...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (faceDetected == true) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                        const SizedBox(width: 12),
                        const Text(
                          'Face detected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (faceDetected == false) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 12),
                        const Text(
                          'No face detected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          const SizedBox(height: 16),
          
          ValueListenableBuilder<String?>(
            valueListenable: selectedImageBase64Notifier,
            builder: (context, selectedImageBase64, _) {
              if (selectedImageBase64 != null) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showImagePreview(context, selectedImageBase64),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue[700],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.preview, size: 20),
                      label: const Text(
                        'Preview',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        selectedImageBase64Notifier.value = null;
                        selectedImageFileTypeNotifier.value = null;
                        isImageUploadedNotifier.value = false;
                        faceDetectedNotifier.value = null;
                        isDetectingFaceNotifier.value = false;
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[700],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      label: const Text(
                        'Remove',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 60),
          
          ValueListenableBuilder<bool>(
            valueListenable: isImageUploadedNotifier,
            builder: (context, isUploaded, _) => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isUploaded ? onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

