import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import '../../models/user/resume_attachment.dart';

class StorageService {
  StorageService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? 'anonymous';

  // 🔹 Convert resume file to Base64 and store in Firestore
  Future<ResumeAttachment?> pickAndUploadResume() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;

      final file = result.files.single;
      
      // Handle both web (file.bytes) and mobile (file.path) platforms
      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw Exception('Unable to read file: both bytes and path are null');
      }
      
      // Check file size EARLY - Firestore limit is 1MB per document (including all fields)
      // Base64 encoding increases size by ~33%, and we need space for other fields
      // So we limit original file to ~650KB to ensure total document stays under 1MB
      const int maxOriginalSize = 650 * 1024; // 650KB original ≈ 870KB base64 + metadata
      if (bytes.length > maxOriginalSize) {
        final fileSizeMB = (bytes.length / 1024 / 1024).toStringAsFixed(2);
        throw Exception('File is too large (${fileSizeMB}MB / ${(bytes.length / 1024).toStringAsFixed(0)}KB). '
            'Maximum allowed size is 650KB. '
            'Please select a smaller file or compress your resume before uploading.');
      }
      
      final base64String = base64Encode(bytes);
      
      // Estimate total document size (base64 + metadata fields)
      // Metadata: fileName (~100 bytes), fileType (~10 bytes), uploadedAt (~30 bytes)
      const int estimatedMetadataSize = 200; // bytes
      final int estimatedTotalSize = base64String.length + estimatedMetadataSize;
      
      // Final check on estimated total document size (Firestore's hard limit is 1MB)
      const int maxDocumentSize = 1000 * 1024; // 1000KB - leave some margin
      if (estimatedTotalSize > maxDocumentSize) {
        final base64SizeMB = (base64String.length / 1024 / 1024).toStringAsFixed(2);
        final totalSizeMB = (estimatedTotalSize / 1024 / 1024).toStringAsFixed(2);
        throw Exception('File is too large after encoding (${base64SizeMB}MB base64, ~${totalSizeMB}MB total). '
            'Firestore document limit is 1MB. '
            'Please select a smaller file or compress your resume before uploading.');
      }
      
      // Validate and sanitize file extension
      String ext = (file.extension?.toLowerCase() ?? 'unknown').trim();
      // Remove any invalid characters and normalize
      ext = ext.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase();
      // Normalize common formats
      if (ext == 'jpeg') ext = 'jpg';
      // Validate extension is allowed
      if (ext.isEmpty || !['pdf', 'png', 'jpg', 'jpeg'].contains(ext)) {
        ext = 'pdf'; // Default fallback
      }
      
      // Sanitize file name (remove invalid characters for Firestore)
      String fileName = file.name.trim();
      if (fileName.isEmpty) {
        fileName = 'Resume.$ext';
      }
      // Remove any control characters and limit length
      fileName = fileName.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
      if (fileName.length > 255) {
        fileName = '${fileName.substring(0, 250)}.$ext';
      }

      // Validate base64 string is not empty and contains only valid base64 characters
      if (base64String.isEmpty) {
        throw Exception('Failed to encode file: base64 string is empty');
      }
      // Validate base64 string contains only valid characters (A-Z, a-z, 0-9, +, /, =)
      if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(base64String)) {
        throw Exception('Invalid base64 string: contains invalid characters');
      }
      // Try to decode to verify it's valid base64
      try {
        base64Decode(base64String);
      } catch (e) {
        throw Exception('Invalid base64 string: failed to decode - $e');
      }

      final attachment = ResumeAttachment(
        fileName: fileName,
        fileType: ext,
        base64Data: base64String,
      );

      // Create a new Map instead of modifying the returned Map
      final resumeData = Map<String, dynamic>.from(attachment.toMap());
      
      // Validate all required fields are present and not empty
      if (resumeData['fileName'] == null || (resumeData['fileName'] as String).isEmpty) {
        throw Exception('Invalid file name');
      }
      if (resumeData['fileType'] == null || (resumeData['fileType'] as String).isEmpty) {
        throw Exception('Invalid file type');
      }
      if (resumeData['base64'] == null || (resumeData['base64'] as String).isEmpty) {
        throw Exception('Invalid base64 data');
      }
      
      // Add uploadedAt timestamp
      final uploadedAt = DateTime.now().toIso8601String();
      resumeData['uploadedAt'] = uploadedAt;

      // Validate field names don't start with __ (Firestore reserved)
      for (final key in resumeData.keys) {
        if (key.startsWith('__')) {
          throw Exception('Invalid field name: field names cannot start with __');
        }
        if (key.isEmpty) {
          throw Exception('Invalid field name: field names cannot be empty');
        }
      }

      // Final validation: Calculate actual document size before saving
      final actualBase64Length = (resumeData['base64'] as String).length;
      final estimatedFirestoreSize = actualBase64Length + 
          (resumeData['fileName'] as String).length +
          (resumeData['fileType'] as String).length +
          uploadedAt.length +
          200; // Overhead for Firestore structure
      
      // Debug: Print resume data structure (without base64 content for privacy)
      print('Uploading resume - fileName: "${resumeData['fileName']}", fileType: "${resumeData['fileType']}", '
          'base64 length: ${(actualBase64Length / 1024).toStringAsFixed(1)}KB, '
          'estimated total: ${(estimatedFirestoreSize / 1024).toStringAsFixed(1)}KB');
      
      // Final safety check before saving
      const int maxFirestoreDocumentSize = 1024 * 1024; // 1MB exactly
      if (estimatedFirestoreSize > maxFirestoreDocumentSize) {
        throw Exception('File is too large for Firestore (${(estimatedFirestoreSize / 1024 / 1024).toStringAsFixed(2)}MB). '
            'Maximum document size is 1MB. '
            'Please select a smaller file (recommended: under 650KB original size).');
      }

      // Before saving, clean up existing base64 data from resume and image fields
      // to prevent Firestore document size limit (1MB) error
      Map<String, dynamic>? existingData;
      try {
        final userDoc = await _firestore.collection('users').doc(_uid).get();
        if (userDoc.exists) {
          existingData = userDoc.data();
          if (existingData != null) {
            // Clean up existing resume base64 data
            if (existingData['resume'] is Map) {
              final existingResume = Map<String, dynamic>.from(existingData['resume'] as Map);
              if (existingResume.containsKey('base64')) {
                existingResume.remove('base64');
                // Only keep resume if it has downloadUrl
                if (existingResume.containsKey('downloadUrl') && existingResume['downloadUrl'] != null) {
                  await _firestore.collection('users').doc(_uid).update({
                    'resume': existingResume,
                  });
                  // Update existingData to reflect the change
                  existingData['resume'] = existingResume;
                } else {
                  // Remove resume if no downloadUrl
                  await _firestore.collection('users').doc(_uid).update({
                    'resume': FieldValue.delete(),
                  });
                  existingData.remove('resume');
                }
              }
            }
            
            // Clean up existing image base64 data
            if (existingData['image'] is Map) {
              final existingImage = Map<String, dynamic>.from(existingData['image'] as Map);
              if (existingImage.containsKey('base64')) {
                existingImage.remove('base64');
                // Only keep image if it has downloadUrl
                if (existingImage.containsKey('downloadUrl') && existingImage['downloadUrl'] != null) {
                  await _firestore.collection('users').doc(_uid).update({
                    'image': existingImage,
                  });
                  // Update existingData to reflect the change
                  existingData['image'] = existingImage;
                } else {
                  // Remove image if no downloadUrl
                  await _firestore.collection('users').doc(_uid).update({
                    'image': FieldValue.delete(),
                  });
                  existingData.remove('image');
                }
              }
            }
          }
        }
      } catch (cleanupError) {
        // Log but don't fail - cleanup is best effort
        print('Warning: Failed to cleanup existing base64 data: $cleanupError');
      }

      // Estimate total document size with new resume data
      // Calculate size of existing document (without resume)
      int existingSize = 0;
      if (existingData != null) {
        final tempData = Map<String, dynamic>.from(existingData);
        tempData.remove('resume'); // Remove old resume to calculate size without it
        existingSize = _estimateDocumentSize(tempData);
      }
      
      // Calculate size of new resume data
      final newResumeSize = _estimateDocumentSize({'resume': resumeData});
      
      // Total estimated size
      final totalEstimatedSize = existingSize + newResumeSize;
      const int maxDocSize = 1024 * 1024; // 1MB
      
      // If total size would exceed limit, don't save base64 data
      Map<String, dynamic> resumeDataToSave = Map<String, dynamic>.from(resumeData);
      if (totalEstimatedSize > maxDocSize) {
        print('Warning: Document would exceed 1MB limit. Removing base64 data from resume.');
        // Remove base64 data, only keep metadata
        resumeDataToSave.remove('base64');
        // If no downloadUrl, we can't save the resume
        if (!resumeDataToSave.containsKey('downloadUrl') || resumeDataToSave['downloadUrl'] == null) {
          throw Exception('Cannot save resume: Document size would exceed Firestore limit (1MB). '
              'Please remove other large data (like images) or use a smaller resume file.');
        }
      }

      // Use update instead of set to avoid potential merge issues
      try {
        await _firestore.collection('users').doc(_uid).update({
          'resume': resumeDataToSave,
        });
      } catch (updateError) {
        // If update fails (document doesn't exist), use set with merge
        if (updateError is FirebaseException && 
            (updateError.code == 'not-found' || updateError.code == 'permission-denied')) {
          await _firestore.collection('users').doc(_uid).set({
            'resume': resumeDataToSave,
          }, SetOptions(merge: true));
        } else {
          rethrow;
        }
      }
      
      // Return attachment without base64 if we removed it
      if (resumeDataToSave.containsKey('base64') == false && resumeData.containsKey('base64')) {
        return ResumeAttachment(
          fileName: attachment.fileName,
          fileType: attachment.fileType,
          downloadUrl: attachment.downloadUrl,
          base64Data: null, // base64 was not saved
        );
      }

      return attachment;
    } catch (e) {
      print('Error uploading resume: $e');
      rethrow;
    }
  }

  // 🔹 Convert image to Base64 and store in Firestore
  Future<String?> pickAndUploadImage({required bool fromCamera}) async {
    try {
      final bool useImagePicker = kIsWeb ||
          (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS));

      late Uint8List bytes;
      late String ext;

      if (useImagePicker) {
        if (fromCamera && !kIsWeb && !(Platform.isAndroid || Platform.isIOS)) {
          return null;
        }

        final ImagePicker picker = ImagePicker();
        // Use very low quality to reduce file size and prevent Firestore document size limit
        // Camera: 30% quality (camera photos are typically larger and uncompressed)
        // Gallery: 40% quality (may already be compressed, but still need aggressive compression)
        final XFile? x = fromCamera
            ? await picker.pickImage(source: ImageSource.camera, imageQuality: 30)
            : await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);

        if (x == null) return null;

        bytes = await x.readAsBytes();
        
        // Try to get extension from MIME type first (more reliable)
        String? mimeType = x.mimeType;
        if (mimeType != null) {
          // Extract extension from MIME type (e.g., "image/jpeg" -> "jpeg")
          final mimeParts = mimeType.split('/');
          if (mimeParts.length == 2 && mimeParts[0] == 'image') {
            ext = mimeParts[1].toLowerCase();
            // Normalize common formats
            if (ext == 'jpeg') ext = 'jpg';
            if (!['jpg', 'png', 'gif', 'webp'].contains(ext)) {
              ext = 'jpg'; // Fallback
            }
          } else {
            ext = 'jpg'; // Fallback
          }
        } else {
          // Fallback to path-based extraction
          if (x.path.contains('.')) {
            ext = x.path.split('.').last.toLowerCase();
            // Normalize
            if (ext == 'jpeg') ext = 'jpg';
            // Validate extension is a valid image format
            if (ext.isEmpty || !['jpg', 'png', 'gif', 'webp'].contains(ext)) {
              ext = 'jpg'; // Default to jpg
            }
          } else {
            // No extension found, default to jpg (camera images are typically jpg)
            ext = 'jpg';
          }
        }
      } else {
        if (fromCamera) return null;
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.image,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return null;
        final file = result.files.single;
        bytes = file.bytes ?? await File(file.path!).readAsBytes();
        ext = file.extension?.toLowerCase() ?? 'jpg';
      }

      // Check image size BEFORE encoding
      // Firestore limit is 1MB per document total, base64 increases size by ~33%
      // We need to be very conservative to account for existing document data
      // With aggressive compression (30-40% quality), we can allow slightly larger originals
      const int maxOriginalSize = 400 * 1024; // 400KB original - very conservative limit
      
      if (bytes.length > maxOriginalSize) {
        throw Exception('Image is too large (${(bytes.length / 1024).toStringAsFixed(0)}KB). '
            'Maximum size is 400KB. Please try taking the photo again or select a smaller image.');
      }
      
      final base64String = base64Encode(bytes);
      
      // Before saving, clean up existing base64 data from image and resume fields
      // to prevent Firestore document size limit (1MB) error
      Map<String, dynamic>? existingData;
      try {
        final userDoc = await _firestore.collection('users').doc(_uid).get();
        if (userDoc.exists) {
          existingData = userDoc.data();
          if (existingData != null) {
            // Clean up existing image base64 data
            if (existingData['image'] is Map) {
              final existingImage = Map<String, dynamic>.from(existingData['image'] as Map);
              if (existingImage.containsKey('base64')) {
                existingImage.remove('base64');
                // Only keep image if it has downloadUrl
                if (existingImage.containsKey('downloadUrl') && existingImage['downloadUrl'] != null) {
                  await _firestore.collection('users').doc(_uid).update({
                    'image': existingImage,
                  });
                } else {
                  // Remove image if no downloadUrl
                  await _firestore.collection('users').doc(_uid).update({
                    'image': FieldValue.delete(),
                  });
                }
              }
            }
            
            // Also clean up resume base64 data to free up space
            if (existingData['resume'] is Map) {
              final existingResume = Map<String, dynamic>.from(existingData['resume'] as Map);
              if (existingResume.containsKey('base64')) {
                existingResume.remove('base64');
                if (existingResume.containsKey('downloadUrl') && existingResume['downloadUrl'] != null) {
                  await _firestore.collection('users').doc(_uid).update({
                    'resume': existingResume,
                  });
                } else {
                  await _firestore.collection('users').doc(_uid).update({
                    'resume': FieldValue.delete(),
                  });
                }
              }
            }
          }
        }
      } catch (cleanupError) {
        // Log but don't fail - cleanup is best effort
        print('Warning: Failed to cleanup existing base64 data: $cleanupError');
      }
      
      // Estimate total document size with new image data
      // Calculate size of existing document (without image)
      int existingSize = 0;
      if (existingData != null) {
        final tempData = Map<String, dynamic>.from(existingData);
        tempData.remove('image'); // Remove old image to calculate size without it
        existingSize = _estimateDocumentSize(tempData);
      }
      
      // Calculate size of new image data
      final newImageSize = _estimateDocumentSize({'image': {
        'fileType': ext,
        'base64': base64String,
      }});
      
      // Total estimated size
      final totalEstimatedSize = existingSize + newImageSize;
      const int maxDocSize = 1024 * 1024; // 1MB
      
      // If total size would exceed limit, don't save base64 data
      if (totalEstimatedSize > maxDocSize) {
        final base64SizeKB = (base64String.length / 1024).toStringAsFixed(1);
        throw Exception('Image is too large for Firestore (${base64SizeKB}KB base64). '
            'The document would exceed the 1MB limit. '
            'Please try taking the photo again with lower resolution or select a smaller image.');
      }
      
      print('Image size: ${(bytes.length / 1024).toStringAsFixed(1)}KB original, ${(base64String.length / 1024).toStringAsFixed(1)}KB base64');

      // Final validation and sanitization
      // Ensure fileType is valid (no special characters, only alphanumeric)
      ext = ext.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase();
      
      // Normalize jpeg to jpg
      if (ext == 'jpeg') ext = 'jpg';
      
      // Final check - ensure it's a valid format, default to jpg if not
      if (ext.isEmpty || !['jpg', 'png', 'gif', 'webp'].contains(ext)) {
        ext = 'jpg';
      }
      
      // Double-check ext is not empty (should never happen at this point, but safety check)
      if (ext.isEmpty) {
        ext = 'jpg';
      }

      // Debug: Print values before upload
      print('Uploading image - fileType: "$ext", base64 length: ${base64String.length}, bytes: ${bytes.length}, uid: $_uid');
      print('Extension after processing: "$ext"');

      // Prepare the image data map - ensure all field names are valid
      final imageData = <String, dynamic>{
        'fileType': ext,
        'base64': base64String,
        'uploadedAt': FieldValue.serverTimestamp(),
      };

      // Validate field names are not empty and don't contain invalid characters
      for (final key in imageData.keys) {
        if (key.isEmpty) {
          throw Exception('Invalid field name: empty string');
        }
        // Firestore field names cannot start with __ (reserved) or contain certain characters
        if (key.startsWith('__')) {
          throw Exception('Invalid field name: cannot start with __');
        }
      }

      // Use update instead of set to avoid potential merge issues
      try {
        await _firestore.collection('users').doc(_uid).update({
          'image': imageData,
        });
      } catch (updateError) {
        // If update fails (document doesn't exist), use set with merge
        if (updateError is FirebaseException && 
            (updateError.code == 'not-found' || updateError.code == 'permission-denied')) {
          await _firestore.collection('users').doc(_uid).set({
            'image': imageData,
          }, SetOptions(merge: true));
        } else {
          rethrow;
        }
      }

      return base64String;
    } catch (e) {
      print('Upload error: $e');
      // Print more details for debugging
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      return null;
    }
  }

  // 🔹 Convert post images to Base64 and store in Firestore
  // Uses ImagePicker with compression (similar to profile image upload)
  /// Pick images and convert to base64 without uploading to Firestore
  /// Returns list of base64 strings for preview
  Future<List<String>> pickPostImages() async {
    try {
      bool useImagePicker = kIsWeb ||
          (!kIsWeb && Platform.isAndroid );

      List<XFile> selectedFiles = [];

      if (useImagePicker) {
        // Use ImagePicker for better compression support
        final ImagePicker picker = ImagePicker();
        // Try to pick multiple images with compression
        // Note: pickMultiImage may not be available on all platforms
        try {
          selectedFiles = await picker.pickMultiImage(imageQuality: 70); // 70% quality for post images
        } catch (e) {
          // Fallback: allow user to pick one image at a time
          // In this case, we'll use FilePicker for multiple selection
          print('Multi-image picker not available, using FilePicker fallback: $e');
          useImagePicker = false; // Fall through to FilePicker
        }
      }
      
      if (!useImagePicker) {
        // Fallback to FilePicker for other platforms
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: const ['png', 'jpg', 'jpeg'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return <String>[];
        // Convert FilePicker files to a format we can process
        for (final file in result.files) {
          if (file.path != null) {
            selectedFiles.add(XFile(file.path!));
          }
        }
      }

      if (selectedFiles.isEmpty) return <String>[];

      final List<String> base64Strings = [];

      for (final xFile in selectedFiles) {
        try {
          late Uint8List bytes;

          bytes = await xFile.readAsBytes();
          
          // Check image size (similar to profile upload logic)
          // Firestore limit is 1MB per document, base64 increases size by ~33%
          const int maxOriginalSize = 1500 * 1024; // 1.5MB original - already compressed by imageQuality
          
          if (bytes.length > maxOriginalSize) {
            throw Exception('Image "${xFile.name}" is too large (${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB). '
                'Maximum size is 1.5MB. Please select a smaller image.');
          }
          
          final base64String = base64Encode(bytes);
          
          // Final check on actual base64 size
          const int maxBase64Size = 980 * 1024; // 980KB - close to 1MB limit
          if (base64String.length > maxBase64Size) {
            throw Exception('Image "${xFile.name}" is too large after encoding (${(base64String.length / 1024).toStringAsFixed(1)}KB). '
                'Firestore limit is 1MB per document. Please select a smaller image.');
          }

          base64Strings.add(base64String);
        } catch (e) {
          print('Failed to process image ${xFile.name}: $e');
          // Continue with other images even if one fails
        }
      }

      return base64Strings;
    } catch (e) {
      print('Error picking post images: $e');
      rethrow;
    }
  }

  /// Upload base64 images to Firestore post document
  Future<void> uploadPostImages({required String postId, required List<String> base64Images}) async {
    if (base64Images.isEmpty) return;

    try {
      // Get reference to the post document
      final postDoc = _firestore.collection('posts').doc(postId);
      
      // Check if document exists to determine if we need to set ownerId
      final docSnapshot = await postDoc.get();
      final bool docExists = docSnapshot.exists;
      final bool needsOwnerId = !docExists;

      // Prepare data to write - store as simple base64 strings in attachments array
      final data = <String, dynamic>{
        'attachments': FieldValue.arrayUnion(base64Images)
      };

      // Include ownerId only if document doesn't exist yet
      if (needsOwnerId) {
        data['ownerId'] = _uid;
      }

      // Use update with merge, or set if document doesn't exist
      if (docExists) {
        await postDoc.update(data);
      } else {
        await postDoc.set(data, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error uploading post images: $e');
      rethrow;
    }
  }

  Future<List<String>> pickAndUploadPostImages({required String postId}) async {
    try {
      bool useImagePicker = kIsWeb ||
          (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS));

      List<XFile> selectedFiles = [];

      if (useImagePicker) {
        // Use ImagePicker for better compression support
        final ImagePicker picker = ImagePicker();
        // Try to pick multiple images with compression
        // Note: pickMultiImage may not be available on all platforms
        try {
          selectedFiles = await picker.pickMultiImage(imageQuality: 70); // 70% quality for post images
        } catch (e) {
          // Fallback: allow user to pick one image at a time
          // In this case, we'll use FilePicker for multiple selection
          print('Multi-image picker not available, using FilePicker fallback: $e');
          useImagePicker = false; // Fall through to FilePicker
        }
      }
      
      if (!useImagePicker) {
        // Fallback to FilePicker for other platforms
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: const ['png', 'jpg', 'jpeg'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return <String>[];
        // Convert FilePicker files to a format we can process
        for (final file in result.files) {
          if (file.path != null) {
            selectedFiles.add(XFile(file.path!));
          }
        }
      }

      if (selectedFiles.isEmpty) return <String>[];

      final List<String> uploaded = [];
      final List<String> failedImages = [];

      // Get reference to the post document
      final postDoc = _firestore.collection('posts').doc(postId);
      
      // Check if document exists to determine if we need to set ownerId
      final docSnapshot = await postDoc.get();
      final bool docExists = docSnapshot.exists;
      final bool needsOwnerId = !docExists;

      for (final xFile in selectedFiles) {
        try {
          late Uint8List bytes;
          late String ext;

          bytes = await xFile.readAsBytes();
          
          // Get extension from MIME type (similar to profile upload)
          String? mimeType = xFile.mimeType;
          if (mimeType != null) {
            final mimeParts = mimeType.split('/');
            if (mimeParts.length == 2 && mimeParts[0] == 'image') {
              ext = mimeParts[1].toLowerCase();
              if (ext == 'jpeg') ext = 'jpg';
              if (!['jpg', 'png', 'gif', 'webp'].contains(ext)) {
                ext = 'jpg';
              }
            } else {
              ext = 'jpg';
            }
          } else {
            // Fallback to path-based extraction
            if (xFile.path.contains('.')) {
              ext = xFile.path.split('.').last.toLowerCase();
              if (ext == 'jpeg') ext = 'jpg';
              if (ext.isEmpty || !['jpg', 'png', 'gif', 'webp'].contains(ext)) {
                ext = 'jpg';
              }
            } else {
              ext = 'jpg';
            }
          }

          // Check image size (similar to profile upload logic)
          // Firestore limit is 1MB per document, base64 increases size by ~33%
          const int maxOriginalSize = 1500 * 1024; // 1.5MB original - already compressed by imageQuality
          
          if (bytes.length > maxOriginalSize) {
            throw Exception('Image "${xFile.name}" is too large (${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB). '
                'Maximum size is 1.5MB. Please select a smaller image.');
          }
          
          final base64String = base64Encode(bytes);
          
          // Final check on actual base64 size
          const int maxBase64Size = 980 * 1024; // 980KB - close to 1MB limit
          if (base64String.length > maxBase64Size) {
            throw Exception('Image "${xFile.name}" is too large after encoding (${(base64String.length / 1024).toStringAsFixed(1)}KB). '
                'Firestore limit is 1MB per document. Please select a smaller image.');
          }

          // Validate and sanitize extension
          ext = ext.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase();
          if (ext == 'jpeg') ext = 'jpg';
          if (ext.isEmpty || !['jpg', 'png', 'gif', 'webp'].contains(ext)) {
            ext = 'jpg';
          }

          print('Uploading post image - fileType: "$ext", base64 length: ${base64String.length}, bytes: ${bytes.length}');

          // Prepare data to write - store as simple base64 string in attachments array
          final data = <String, dynamic>{
            'attachments': FieldValue.arrayUnion([base64String])
          };

          // Include ownerId only if document doesn't exist yet
          if (needsOwnerId) {
            data['ownerId'] = _uid;
          }

          // Use update with merge, or set if document doesn't exist
          if (docExists) {
            await postDoc.update(data);
          } else {
            await postDoc.set(data, SetOptions(merge: true));
          }

          uploaded.add(base64String);
        } catch (e) {
          print('Failed to upload image ${xFile.name}: $e');
          failedImages.add(xFile.name);
        }
      }

      // If all images failed, throw an error
      if (uploaded.isEmpty && failedImages.isNotEmpty) {
        throw Exception('Failed to upload all images. ${failedImages.length} image(s) failed: ${failedImages.join(", ")}');
      }

      // If some images failed, log a warning
      if (failedImages.isNotEmpty) {
        print('Warning: ${failedImages.length} image(s) failed to upload: ${failedImages.join(", ")}');
      }

      return uploaded;
    } catch (e) {
      print('Error picking/uploading post images: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  /// Estimate the size of a Firestore document in bytes
  int _estimateDocumentSize(Map<String, dynamic> data) {
    int size = 0;
    for (final entry in data.entries) {
      // Field name size
      size += entry.key.length;
      // Field value size
      size += _estimateValueSize(entry.value);
    }
    // Add overhead for Firestore structure (approximately 100 bytes)
    size += 100;
    return size;
  }

  /// Estimate the size of a value in bytes
  int _estimateValueSize(dynamic value) {
    if (value == null) return 0;
    if (value is String) return value.length;
    if (value is int) return 8; // 8 bytes for int64
    if (value is double) return 8; // 8 bytes for double
    if (value is bool) return 1; // 1 byte for boolean
    if (value is DateTime) return 8; // 8 bytes for timestamp
    if (value is List) {
      int listSize = 0;
      for (final item in value) {
        listSize += _estimateValueSize(item);
      }
      return listSize;
    }
    if (value is Map) {
      int mapSize = 0;
      for (final entry in value.entries) {
        mapSize += (entry.key as String).length; // Key size
        mapSize += _estimateValueSize(entry.value); // Value size
      }
      return mapSize;
    }
    // For other types, estimate as string representation
    return value.toString().length;
  }

}
