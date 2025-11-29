import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service for handling profile picture operations
/// Converts images to base64 format without saving to Firestore
/// Same logic as storage_service.dart but without Firestore upload
class ProfilePicService {
  /// Pick an image from camera or gallery and convert to base64
  /// Returns a map with 'base64' and 'fileType' keys, or null if cancelled/error
  Future<Map<String, String>?> pickImageBase64({required bool fromCamera}) async {
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
      const int maxOriginalSize = 1024 * 1024; // 1MB original
      
      if (bytes.length > maxOriginalSize) {
        throw Exception('Image is too large (${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB). '
            'Maximum size is 1MB. Please try taking the photo again or select a smaller image.');
      }
      
      final base64String = base64Encode(bytes);

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

      return {
        'base64': base64String,
        'fileType': ext,
      };
    } catch (e) {
      print('Error picking image: $e');
      rethrow;
    }
  }
}

