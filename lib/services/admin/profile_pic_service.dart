import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProfilePicService {
  
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
        
        final XFile? x = fromCamera
            ? await picker.pickImage(source: ImageSource.camera, imageQuality: 30)
            : await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);

        if (x == null) return null;

        bytes = await x.readAsBytes();
        
        String? mimeType = x.mimeType;
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
          
          if (x.path.contains('.')) {
            ext = x.path.split('.').last.toLowerCase();
            
            if (ext == 'jpeg') ext = 'jpg';
            
            if (ext.isEmpty || !['jpg', 'png', 'gif', 'webp'].contains(ext)) {
              ext = 'jpg'; 
            }
          } else {
            
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

      const int maxOriginalSize = 1024 * 1024; 
      
      if (bytes.length > maxOriginalSize) {
        throw Exception('Image is too large (${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB). '
            'Maximum size is 1MB. Please try taking the photo again or select a smaller image.');
      }
      
      final base64String = base64Encode(bytes);

      ext = ext.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase();
      
      if (ext == 'jpeg') ext = 'jpg';
      
      if (ext.isEmpty || !['jpg', 'png', 'gif', 'webp'].contains(ext)) {
        ext = 'jpg';
      }
      
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
