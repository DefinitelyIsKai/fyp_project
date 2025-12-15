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
import 'package:image/image.dart' as img;
import '../../models/user/resume_attachment.dart';

class StorageService {
  StorageService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? 'anonymous';

 
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
      
      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw Exception('Unable to read file: both bytes and path are null');
      }

      String ext = (file.extension?.toLowerCase() ?? 'unknown').trim();
      ext = ext.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase();
      if (ext == 'jpeg') ext = 'jpg';
      
      final isImage = ['png', 'jpg', 'jpeg'].contains(ext);
      if (isImage) {
        bytes = await _compressImage(bytes, maxWidth: 1920, maxHeight: 1920, quality: 75);
        
        const int maxOriginalSize = 650 * 1024;
        if (bytes.length > maxOriginalSize) {
          bytes = await _compressImage(bytes, maxWidth: 1280, maxHeight: 1280, quality: 60);
          
          if (bytes.length > maxOriginalSize) {
            bytes = await _compressImage(bytes, maxWidth: 1024, maxHeight: 1024, quality: 30);
            
            if (bytes.length > maxOriginalSize) {
              final fileSizeMB = (bytes.length / 1024 / 1024).toStringAsFixed(2);
              throw Exception('Image is too large (${fileSizeMB}MB / ${(bytes.length / 1024).toStringAsFixed(0)}KB). '
                  'Maximum allowed size is 650KB. '
                  'Please select a smaller image or try taking a photo with lower resolution.');
            }
          }
        }
      } else {
        const int maxOriginalSize = 650 * 1024; 
        if (bytes.length > maxOriginalSize) {
          final fileSizeMB = (bytes.length / 1024 / 1024).toStringAsFixed(2);
          throw Exception('File is too large (${fileSizeMB}MB / ${(bytes.length / 1024).toStringAsFixed(0)}KB). '
              'Maximum allowed size is 650KB. '
              'Please select a smaller file or compress your resume before uploading.');
        }
      }
      
      final base64String = base64Encode(bytes);
      const int estimatedMetadataSize = 200; 
      final int estimatedTotalSize = base64String.length + estimatedMetadataSize;
      
      const int maxDocumentSize = 1000 * 1024; 
      if (estimatedTotalSize > maxDocumentSize) {
        final base64SizeMB = (base64String.length / 1024 / 1024).toStringAsFixed(2);
        final totalSizeMB = (estimatedTotalSize / 1024 / 1024).toStringAsFixed(2);
        throw Exception('File is too large after encoding (${base64SizeMB}MB base64, ~${totalSizeMB}MB total). '
            'Firestore document limit is 1MB. '
            'Please select a smaller file or compress your resume before uploading.');
      }
      
      if (ext.isEmpty || !['pdf', 'png', 'jpg', 'jpeg'].contains(ext)) {
        ext = 'pdf'; 
      }
      
      String fileName = file.name.trim();
      if (fileName.isEmpty) {
        fileName = 'Resume.$ext';
      }
      fileName = fileName.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
      if (fileName.length > 255) {
        fileName = '${fileName.substring(0, 250)}.$ext';
      }

      if (base64String.isEmpty) {
        throw Exception('Failed to encode file: base64 string is empty');
      }
      if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(base64String)) {
        throw Exception('Invalid base64 string: contains invalid characters');
      }
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

      final resumeData = Map<String, dynamic>.from(attachment.toMap());
      
      if (resumeData['fileName'] == null || (resumeData['fileName'] as String).isEmpty) {
        throw Exception('Invalid file name');
      }
      if (resumeData['fileType'] == null || (resumeData['fileType'] as String).isEmpty) {
        throw Exception('Invalid file type');
      }
      if (resumeData['base64'] == null || (resumeData['base64'] as String).isEmpty) {
        throw Exception('Invalid base64 data');
      }
      
      final uploadedAt = DateTime.now().toIso8601String();
      resumeData['uploadedAt'] = uploadedAt;

      for (final key in resumeData.keys) {
        if (key.startsWith('__')) {
          throw Exception('Invalid field name: field names cannot start with __');
        }
        if (key.isEmpty) {
          throw Exception('Invalid field name: field names cannot be empty');
        }
      }

      final actualBase64Length = (resumeData['base64'] as String).length;
      final estimatedFirestoreSize = actualBase64Length + 
          (resumeData['fileName'] as String).length +
          (resumeData['fileType'] as String).length +
          uploadedAt.length + 200; 
      
     
      print('Uploading resume - fileName: "${resumeData['fileName']}", fileType: "${resumeData['fileType']}", '
          'base64 length: ${(actualBase64Length / 1024).toStringAsFixed(1)}KB, '
          'estimated total: ${(estimatedFirestoreSize / 1024).toStringAsFixed(1)}KB');
      
      const int maxFirestoreDocumentSize = 1024 * 1024;
      if (estimatedFirestoreSize > maxFirestoreDocumentSize) {
        throw Exception('File is too large for Firestore (${(estimatedFirestoreSize / 1024 / 1024).toStringAsFixed(2)}MB). '
            'Maximum document size is 1MB. '
            'Please select a smaller file (recommended: under 650KB original size).');
      }

    
      Map<String, dynamic>? existingData;
      try {
        final userDoc = await _firestore.collection('users').doc(_uid).get();
        if (userDoc.exists) {
          existingData = userDoc.data();
          if (existingData != null) {
            if (existingData['resume'] is Map) {
              final existingResume = Map<String, dynamic>.from(existingData['resume'] as Map);
              if (existingResume.containsKey('base64')) {
                existingResume.remove('base64');
                if (existingResume.containsKey('downloadUrl') && existingResume['downloadUrl'] != null) {
                  await _firestore.collection('users').doc(_uid).update({
                    'resume': existingResume,
                  });
                  existingData['resume'] = existingResume;
                } else {
                  await _firestore.collection('users').doc(_uid).update({
                    'resume': FieldValue.delete(),
                  });
                  existingData.remove('resume');
                }
              }
            }
            
          }
        }
      } catch (cleanupError) {
        print('Warning: Failed to cleanup existing base64 data: $cleanupError');
      }

      int existingSize = 0;
      if (existingData != null) {
        final tempData = Map<String, dynamic>.from(existingData);
        tempData.remove('resume'); 
        existingSize = _estimateDocumentSize(tempData);
      }
      
      final newResumeSize = _estimateDocumentSize({'resume': resumeData});
      
      final totalEstimatedSize = existingSize + newResumeSize;
      const int maxDocSize = 1024 * 1024; 
      
      Map<String, dynamic> resumeDataToSave = Map<String, dynamic>.from(resumeData);
      if (totalEstimatedSize > maxDocSize) {
        print('Warning: Document would exceed 1MB limit. Removing base64 data from resume.');
        resumeDataToSave.remove('base64');
        if (!resumeDataToSave.containsKey('downloadUrl') || resumeDataToSave['downloadUrl'] == null) {
          throw Exception('Cannot save resume: Document size would exceed Firestore limit (1MB). '
              'Please remove other large data (like images) or use a smaller resume file.');
        }
      }

      try {
        await _firestore.collection('users').doc(_uid).update({
          'resume': resumeDataToSave,
        });
      } catch (updateError) {
        if (updateError is FirebaseException && 
            (updateError.code == 'not-found' || updateError.code == 'permission-denied')) {
          await _firestore.collection('users').doc(_uid).set({
            'resume': resumeDataToSave,
          }, SetOptions(merge: true));
        } else {
          rethrow;
        }
      }
      
      if (resumeDataToSave.containsKey('base64') == false && resumeData.containsKey('base64')) {
        return ResumeAttachment(
          fileName: attachment.fileName,
          fileType: attachment.fileType,
          downloadUrl: attachment.downloadUrl,
          base64Data: null, 
        );
      }

      return attachment;
    } catch (e) {
      print('Error uploading resume: $e');
      rethrow;
    }
  }

  Future<Uint8List> _compressImage(Uint8List imageBytes, {int maxWidth = 1920, int maxHeight = 1920, int quality = 85}) async {
    try {
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      int width = image.width;
      int height = image.height;
      
      if (width > maxWidth || height > maxHeight) {
        double aspectRatio = width / height;
        if (width > height) {
          width = maxWidth;
          height = (maxWidth / aspectRatio).round();
        } else {
          height = maxHeight;
          width = (maxHeight * aspectRatio).round();
        }
        
        image = img.copyResize(image, width: width, height: height);
      }

      final compressedBytes = img.encodeJpg(image, quality: quality);
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      print('Error compressing image: $e');
      return imageBytes;
    }
  }

  Future<Uint8List?> pickImageBytes({required bool fromCamera, String? preferredCamera}) async {
    try {
      final bool useImagePicker = kIsWeb ||
          (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS));

      late Uint8List bytes;

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

        bytes = await _compressImage(bytes, maxWidth: 1920, maxHeight: 1920, quality: 75);
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
        bytes = await _compressImage(bytes, maxWidth: 1920, maxHeight: 1920, quality: 75);
      }

      const int maxOriginalSize = 500 * 1024;
      if (bytes.length > maxOriginalSize) {
        bytes = await _compressImage(bytes, maxWidth: 1280, maxHeight: 1280, quality: 60);
        
        if (bytes.length > maxOriginalSize) {
          throw Exception('Image is too large (${(bytes.length / 1024).toStringAsFixed(0)}KB). '
              'Maximum size is 500KB. Please try taking the photo again or select a smaller image.');
        }
      }

      return bytes;
    } catch (e) {
      print('Error picking image: $e');
      rethrow;
    }
  }


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
        final XFile? x = fromCamera
            ? await picker.pickImage(source: ImageSource.camera, imageQuality: 30)
            : await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);

        if (x == null) return null;

        bytes = await x.readAsBytes();
        bytes = await _compressImage(bytes, maxWidth: 1024, maxHeight: 1024, quality: 75);
         
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
        bytes = await _compressImage(bytes, maxWidth: 1024, maxHeight: 1024, quality: 75);
        ext = file.extension?.toLowerCase() ?? 'jpg';
      }


      const int maxBase64Size = 250 * 1024; 
      const int maxOriginalSize = 300 * 1024; 
      
      if (bytes.length > maxOriginalSize) {
        bytes = await _compressImage(bytes, maxWidth: 800, maxHeight: 800, quality: 60);
      }
      
      String base64String = base64Encode(bytes);
      
      int compressionAttempts = 0;
      while (base64String.length > maxBase64Size && compressionAttempts < 3) {
        if (compressionAttempts == 0) {
          bytes = await _compressImage(bytes, maxWidth: 800, maxHeight: 800, quality: 50);
        } else if (compressionAttempts == 1) {
          bytes = await _compressImage(bytes, maxWidth: 600, maxHeight: 600, quality: 45);
        } else {
          bytes = await _compressImage(bytes, maxWidth: 512, maxHeight: 512, quality: 40);
        }
        base64String = base64Encode(bytes);
        compressionAttempts++;
      }
      
      if (base64String.length > maxBase64Size) {
        final base64SizeKB = (base64String.length / 1024).toStringAsFixed(1);
        throw Exception('Image is too large (${base64SizeKB}KB base64). '
            'Maximum size is 250KB. Please try taking the photo again with lower resolution or select a smaller image.');
      }
      
      
      Map<String, dynamic>? existingData;
      try {
        final userDoc = await _firestore.collection('users').doc(_uid).get();
        if (userDoc.exists) {
          existingData = userDoc.data();
          if (existingData != null) {
            if (existingData['image'] is Map) {
              final existingImage = Map<String, dynamic>.from(existingData['image'] as Map);
              if (existingImage.containsKey('base64')) {
                existingImage.remove('base64');
                if (existingImage.containsKey('downloadUrl') && existingImage['downloadUrl'] != null) {
                  await _firestore.collection('users').doc(_uid).update({
                    'image': existingImage,
                  });
                } else {
                  await _firestore.collection('users').doc(_uid).update({
                    'image': FieldValue.delete(),
                  });
                }
              }
            }
          }
        }
      } catch (cleanupError) {
        print('Warning: Failed to cleanup existing base64 data: $cleanupError');
      }
      
    
      int existingSize = 0;
      if (existingData != null) {
        final tempData = Map<String, dynamic>.from(existingData);
        tempData.remove('image');
        existingSize = _estimateDocumentSize(tempData);
      }
      
 
      final newImageSize = _estimateDocumentSize({'image': {
        'fileType': ext,
        'base64': base64String,
      }});
      
   
      final totalEstimatedSize = existingSize + newImageSize;
      const int maxDocSize = 1024 * 1024; 
      

      if (totalEstimatedSize > maxDocSize) {
        final base64SizeKB = (base64String.length / 1024).toStringAsFixed(1);
        throw Exception('Image is too large for Firestore (${base64SizeKB}KB base64). '
            'The document would exceed the 1MB limit. '
            'Please try taking the photo again with lower resolution or select a smaller image.');
      }
      
      print('Image size: ${(bytes.length / 1024).toStringAsFixed(1)}KB original, ${(base64String.length / 1024).toStringAsFixed(1)}KB base64');

      ext = ext.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase();
      

      if (ext == 'jpeg') ext = 'jpg';
      
  
      if (ext.isEmpty || !['jpg', 'png', 'gif', 'webp'].contains(ext)) {
        ext = 'jpg';
      }
      
      if (ext.isEmpty) {
        ext = 'jpg';
      }

      print('Uploading image - fileType: "$ext", base64 length: ${base64String.length}, bytes: ${bytes.length}, uid: $_uid');
      print('Extension after processing: "$ext"');
      final imageData = <String, dynamic>{
        'fileType': ext,
        'base64': base64String,
        'uploadedAt': FieldValue.serverTimestamp(),
      };

      for (final key in imageData.keys) {
        if (key.isEmpty) {
          throw Exception('Invalid field name: empty string');
        }
        if (key.startsWith('__')) {
          throw Exception('Invalid field name: cannot start with __');
        }
      }
      try {
        await _firestore.collection('users').doc(_uid).update({
          'image': imageData,
        });
      } catch (updateError) {
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
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  Future<List<String>> pickPostImages() async {
    try {
      bool useImagePicker = kIsWeb ||
          (!kIsWeb && Platform.isAndroid );

      List<XFile> selectedFiles = [];

      if (useImagePicker) {
        final ImagePicker picker = ImagePicker();
        try {
          selectedFiles = await picker.pickMultiImage(imageQuality: 70); 
        } catch (e) {
          print('Multi-image picker not available, using FilePicker fallback: $e');
          useImagePicker = false; 
        }
      }
      
      if (!useImagePicker) {
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: const ['png', 'jpg', 'jpeg'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return <String>[];
        for (final file in result.files) {
          if (file.path != null) {
            selectedFiles.add(XFile(file.path!));
          }
        }
      }

      if (selectedFiles.isEmpty) return <String>[];

      final List<String> base64Strings = [];
      final List<String> errorMessages = [];

      for (final xFile in selectedFiles) {
        try {
          late Uint8List bytes;

          bytes = await xFile.readAsBytes();
  
          const int maxOriginalSize = 1500 * 1024;
          
          if (bytes.length > maxOriginalSize) {
            final errorMsg = 'Image "${xFile.name}" is too large (${(bytes.length / 1024 / 1024).toStringAsFixed(2)}MB). '
                'Maximum size is 1.5MB. Please select a smaller image.';
            errorMessages.add(errorMsg);
            print('Failed to process image ${xFile.name}: $errorMsg');
            continue;
          }
          
          final base64String = base64Encode(bytes);
        
          const int maxBase64Size = 980 * 1024; 
          if (base64String.length > maxBase64Size) {
            final errorMsg = 'Image "${xFile.name}" is too large after encoding (${(base64String.length / 1024).toStringAsFixed(1)}KB). '
                'Firestore limit is 1MB per document. Please select a smaller image.';
            errorMessages.add(errorMsg);
            print('Failed to process image ${xFile.name}: $errorMsg');
            continue;
          }

          base64Strings.add(base64String);
        } catch (e) {
          final errorMsg = e.toString().contains('too large') 
              ? e.toString() 
              : 'Failed to process image "${xFile.name}": ${e.toString()}';
          errorMessages.add(errorMsg);
          print('Failed to process image ${xFile.name}: $e');
        }
      }

      if (errorMessages.isNotEmpty && base64Strings.isEmpty) {
        throw Exception(errorMessages.join('\n\n'));
      }
      
      if (errorMessages.isNotEmpty) {
        final successCount = base64Strings.length;
        final errorCount = errorMessages.length;
        final combinedMessage = errorMessages.join('\n\n') + 
            (successCount > 0 ? '\n\nNote: $successCount image(s) were added successfully, but $errorCount image(s) failed.' : '');
        throw Exception(combinedMessage);
      }

      return base64Strings;
    } catch (e) {
      print('Error picking post images: $e');
      rethrow;
    }
  }

  int _estimateDocumentSize(Map<String, dynamic> data) {
    int size = 0;
    for (final entry in data.entries) {
      size += entry.key.length;
      size += _estimateValueSize(entry.value);
    }
    size += 100;
    return size;
  }


  int _estimateValueSize(dynamic value) {
    if (value == null) return 0;
    if (value is String) return value.length;
    if (value is int) return 8; 
    if (value is double) return 8; 
    if (value is bool) return 1; 
    if (value is DateTime) return 8; 
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
        mapSize += (entry.key as String).length;
        mapSize += _estimateValueSize(entry.value); 
      }
      return mapSize;
    }
    return value.toString().length;
  }

}