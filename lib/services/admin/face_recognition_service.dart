import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';

class FaceRecognitionService {
  static FaceRecognitionService? _instance;
  bool _isModelLoaded = false;
  final FaceDetector _faceDetector;

  FaceRecognitionService._()
      : _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableClassification: false,
            enableLandmarks: true,
            enableTracking: false,
            minFaceSize: 0.1,
          ),
        );

  factory FaceRecognitionService() {
    _instance ??= FaceRecognitionService._();
    return _instance!;
  }

  Future<bool> initialize() async {
    if (_isModelLoaded) {
      print('Service already initialized, skipping');
      return true;
    }

    try {
      print('Initializing face recognition service (using Google ML Kit + image hashing)...');
      
      _isModelLoaded = true;
      print('Service initialized successfully (using Google ML Kit + image hashing)');
      return true;
    } catch (e, stackTrace) {
      print('Service initialization failed: $e');
      print('Stack trace: $stackTrace');
      _isModelLoaded = false;
      return false;
    }
  }

  bool get isModelLoaded => _isModelLoaded;

  Future<img.Image?> decodeBase64Image(String base64String) async {
    try {
      print('Starting to decode base64 image, input length: ${base64String.length}');
      
      if (base64String.isEmpty) {
        print('Error: base64 string is empty');
        return null;
      }
      
      String cleanBase64 = base64String.trim();
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',')[1];
        print('Detected data URI format, extracting base64 part');
      }
      
      print('Cleaned base64 length: ${cleanBase64.length}');
      
      final bytes = Uint8List.fromList(
        base64Decode(cleanBase64),
      );
      
      print('Decoded byte length: ${bytes.length}');
      
      final image = img.decodeImage(bytes);
      if (image == null) {
        print('Error: img.decodeImage returned null');
        return null;
      }
      
      print('Image decoded successfully: ${image.width}x${image.height}, format: ${image.format}');
      return image;
    } catch (e, stackTrace) {
      print('Base64 image decoding failed: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<img.Image?> cameraImageToImage(CameraImage cameraImage) async {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        
        final yBuffer = cameraImage.planes[0].bytes;
        final uBuffer = cameraImage.planes[1].bytes;
        final vBuffer = cameraImage.planes[2].bytes;

        final yuvImage = img.Image(
          width: cameraImage.width,
          height: cameraImage.height,
        );

        for (int y = 0; y < cameraImage.height; y++) {
          for (int x = 0; x < cameraImage.width; x++) {
            final yIndex = y * cameraImage.width + x;
            final uvIndex = (y ~/ 2) * (cameraImage.width ~/ 2) + (x ~/ 2);

            final yValue = yBuffer[yIndex];
            final uValue = uBuffer[uvIndex] - 128;
            final vValue = vBuffer[uvIndex] - 128;

            int r = (yValue + (1.402 * vValue)).round().clamp(0, 255);
            int g = (yValue - (0.344 * uValue) - (0.714 * vValue)).round().clamp(0, 255);
            int b = (yValue + (1.772 * uValue)).round().clamp(0, 255);

            yuvImage.setPixel(x, y, img.ColorRgb8(r, g, b));
          }
        }

        return yuvImage;
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        
        final bytes = cameraImage.planes[0].bytes;
        
        final rgbImage = img.Image(width: cameraImage.width, height: cameraImage.height);
        for (int i = 0; i < bytes.length; i += 4) {
          final b = bytes[i];
          final g = bytes[i + 1];
          final r = bytes[i + 2];
          final a = bytes[i + 3];
          final x = (i ~/ 4) % cameraImage.width;
          final y = (i ~/ 4) ~/ cameraImage.width;
          if (x < cameraImage.width && y < cameraImage.height) {
            rgbImage.setPixel(x, y, img.ColorRgba8(r, g, b, a));
          }
        }
        return rgbImage;
      }
      return null;
    } catch (e) {
      print('CameraImage conversion failed: $e');
      return null;
    }
  }

  Future<List<Face>> detectFaces(InputImage inputImage) async {
    try {
      final faces = await _faceDetector.processImage(inputImage);
      return faces;
    } catch (e) {
      print('Face detection failed: $e');
      return [];
    }
  }

  img.Image? cropFace(img.Image image, Face face) {
    try {
      final boundingBox = face.boundingBox;
      
      final padding = 0.2;
      final left = (boundingBox.left * (1 - padding)).round().clamp(0, image.width);
      final top = (boundingBox.top * (1 - padding)).round().clamp(0, image.height);
      final right = (boundingBox.right * (1 + padding)).round().clamp(0, image.width);
      final bottom = (boundingBox.bottom * (1 + padding)).round().clamp(0, image.height);
      
      final width = right - left;
      final height = bottom - top;
      
      if (width <= 0 || height <= 0) return null;
      
      return img.copyCrop(image, x: left, y: top, width: width, height: height);
    } catch (e) {
      print('Failed to crop face: $e');
      return null;
    }
  }

  Future<double> compareFaces(
    String profileImageBase64,
    img.Image capturedImage,
    Face? capturedFace,
  ) async {
    print('========== compareFaces Called ==========');
    print('Profile image base64 length: ${profileImageBase64.length}');
    print('Captured image size: ${capturedImage.width}x${capturedImage.height}');
    print('Captured face provided: ${capturedFace != null}');
    if (capturedFace != null) {
      final bbox = capturedFace.boundingBox;
      print('Face bounding box: left=${bbox.left}, top=${bbox.top}, right=${bbox.right}, bottom=${bbox.bottom}');
      print('Face size: ${bbox.width}x${bbox.height}');
    }
    print('Time: ${DateTime.now()}');
    try {
      print('Starting face comparison, all processing will be executed in background thread...');
      
      print('Preparing data to pass to background thread...');
      
      Map<String, dynamic>? faceBoundingBox;
      Map<String, dynamic>? capturedImageData;
      
      try {
        if (capturedFace != null) {
          final boundingBox = capturedFace.boundingBox;
          faceBoundingBox = {
            'left': boundingBox.left,
            'top': boundingBox.top,
            'right': boundingBox.right,
            'bottom': boundingBox.bottom,
          };
          print('Face detected, will crop face region for comparison');
        } else {
          print('No face detected, using full image for comparison');
        }
        
        capturedImageData = _imageToPixelData(capturedImage);
        
        print('Executing all image processing in background thread (decode, crop, hash calculation)...');
        final result = await compute(
          _processAndCompareFaces,
          {
            'profileBase64': profileImageBase64,
            'capturedImageData': capturedImageData,
            'faceBoundingBox': faceBoundingBox,
          },
        ).timeout(
          const Duration(seconds: 30), 
          onTimeout: () {
            print('Face comparison timeout after 30 seconds - stopping to prevent closure accumulation');
            return {'success': false, 'similarity': 0.0, 'timeout': true};
          },
        );
        
        if (result['success'] == false) {
          final isTimeout = result['timeout'] == true;
          if (isTimeout) {
            print('Face comparison timed out after 30 seconds - all closures have been cleaned up');
          } else {
            print('Face comparison processing failed');
          }
          return 0.0;
        }
        
        final similarity = (result['similarity'] as num).toDouble();
        print('========== compareFaces Result ==========');
        print('Final similarity score: $similarity');
        print('Similarity percentage: ${(similarity * 100).toStringAsFixed(2)}%');
        print('Threshold check: ${similarity >= 0.96 ? "PASS" : "FAIL"} (threshold: 0.96)');
        print('=========================================');
        return similarity;
      } finally {
        
        faceBoundingBox = null;
        capturedImageData = null;
      }
    } catch (e, stackTrace) {
      print('Face comparison failed: $e');
      print('Stack trace: $stackTrace');
      return 0.0;
    }
  }

  static Map<String, dynamic> _processAndCompareFaces(Map<String, dynamic> inputData) {
    img.Image? profileImage;
    img.Image? decodedProfileImage; 
    img.Image? rebuiltCapturedImage; 
    img.Image? capturedImage;
    img.Image? capturedFaceImage;
    
    try {
      final profileBase64 = inputData['profileBase64'] as String;
      final faceBoundingBox = inputData['faceBoundingBox'] as Map<String, dynamic>?;
      
      print('Starting image processing in isolate...');
      
      print('Decoding profile photo base64...');
      decodedProfileImage = _decodeBase64ImageStatic(profileBase64);
      if (decodedProfileImage == null) {
        print('Error: Failed to decode profile photo');
        return {'success': false, 'similarity': 0.0};
      }
      print('Profile photo decoded successfully: ${decodedProfileImage.width}x${decodedProfileImage.height}');
      
      if (decodedProfileImage.width > 512 || decodedProfileImage.height > 512) {
        print('Resizing large profile image for faster processing...');
        final maxDimension = decodedProfileImage.width > decodedProfileImage.height 
            ? decodedProfileImage.width 
            : decodedProfileImage.height;
        final scale = 512.0 / maxDimension;
        final newWidth = (decodedProfileImage.width * scale).round().clamp(1, 512);
        final newHeight = (decodedProfileImage.height * scale).round().clamp(1, 512);
        profileImage = img.copyResize(
          decodedProfileImage,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
        print('Profile image resized to: ${profileImage.width}x${profileImage.height}');
      } else {
        profileImage = decodedProfileImage;
        decodedProfileImage = null; 
      }
      
      print('Rebuilding captured image...');
      final capturedImageData = inputData['capturedImageData'] as Map<String, dynamic>;
      rebuiltCapturedImage = _rebuildImageFromPixelData(capturedImageData);
      if (rebuiltCapturedImage == null) {
        print('Error: Failed to rebuild captured image');
        return {'success': false, 'similarity': 0.0};
      }
      print('Captured image rebuilt successfully: ${rebuiltCapturedImage.width}x${rebuiltCapturedImage.height}');
      
      if (rebuiltCapturedImage.width > 512 || rebuiltCapturedImage.height > 512) {
        print('Resizing large captured image for faster processing...');
        final maxDimension = rebuiltCapturedImage.width > rebuiltCapturedImage.height 
            ? rebuiltCapturedImage.width 
            : rebuiltCapturedImage.height;
        final scale = 512.0 / maxDimension;
        final newWidth = (rebuiltCapturedImage.width * scale).round().clamp(1, 512);
        final newHeight = (rebuiltCapturedImage.height * scale).round().clamp(1, 512);
        capturedImage = img.copyResize(
          rebuiltCapturedImage,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
        print('Captured image resized to: ${capturedImage.width}x${capturedImage.height}');
      } else {
        capturedImage = rebuiltCapturedImage;
        rebuiltCapturedImage = null; 
      }
      
      if (faceBoundingBox != null) {
        try {
          
          final padding = 0.2;
          final left = ((faceBoundingBox['left'] as num).toDouble() * (1 - padding)).round().clamp(0, capturedImage.width);
          final top = ((faceBoundingBox['top'] as num).toDouble() * (1 - padding)).round().clamp(0, capturedImage.height);
          final right = ((faceBoundingBox['right'] as num).toDouble() * (1 + padding)).round().clamp(0, capturedImage.width);
          final bottom = ((faceBoundingBox['bottom'] as num).toDouble() * (1 + padding)).round().clamp(0, capturedImage.height);
          
          final width = right - left;
          final height = bottom - top;
          
          if (width > 0 && height > 0) {
            final croppedFace = img.copyCrop(capturedImage, x: left, y: top, width: width, height: height);
            print('Face region cropped successfully: ${croppedFace.width}x${croppedFace.height}');
            
            if (croppedFace.width > 256 || croppedFace.height > 256) {
              print('Resizing large cropped face image for faster processing...');
              final maxDimension = croppedFace.width > croppedFace.height 
                  ? croppedFace.width 
                  : croppedFace.height;
              final scale = 256.0 / maxDimension;
              final newWidth = (croppedFace.width * scale).round().clamp(1, 256);
              final newHeight = (croppedFace.height * scale).round().clamp(1, 256);
              capturedFaceImage = img.copyResize(
                croppedFace,
                width: newWidth,
                height: newHeight,
                interpolation: img.Interpolation.linear,
              );
              print('Cropped face image resized to: ${capturedFaceImage.width}x${capturedFaceImage.height}');
            } else {
              capturedFaceImage = croppedFace;
            }
          } else {
            capturedFaceImage = capturedImage;
            print('Invalid bounding box, using full image');
          }
        } catch (e) {
          print('Error cropping face: $e, using full image');
          capturedFaceImage = capturedImage;
        }
      } else {
        capturedFaceImage = capturedImage;
        print('Using full image for comparison');
      }
      
      print('Calculating profile photo hash (${profileImage.width}x${profileImage.height})...');
      final profileHash = _calculateImageHashStatic(profileImage);
      print('Profile photo hash calculated: $profileHash');
      
      print('Calculating captured photo hash (${capturedFaceImage.width}x${capturedFaceImage.height})...');
      final capturedHash = _calculateImageHashStatic(capturedFaceImage);
      print('Captured photo hash calculated: $capturedHash');
      
      if (profileHash == 0 || capturedHash == 0) {
        print('Warning: Image hash calculation failed');
        return {'success': false, 'similarity': 0.0};
      }
      
      print('Calculating Hamming distance between hashes...');
      final hammingDist = _hammingDistanceStatic(profileHash, capturedHash);
      print('Hamming distance: $hammingDist / 256');
      print('Bit match percentage: ${((256 - hammingDist) / 256 * 100).toStringAsFixed(2)}%');
      
      double similarity = (1.0 - (hammingDist / 256.0)).clamp(0.0, 1.0);
      print('Raw similarity calculation: 1.0 - ($hammingDist / 256.0) = $similarity');
        
      const maxAllowedHammingDistance = 12;
      if (hammingDist > maxAllowedHammingDistance) {
        print('Face match REJECTED: Hamming distance $hammingDist exceeds maximum allowed $maxAllowedHammingDistance');
        print('This means less than ~95% of facial features match - likely a different person');
        
        similarity = 0.0;
        } else {
        print('Face match PASSED strict validation: Hamming distance $hammingDist <= $maxAllowedHammingDistance (~95%+ match)');
      }
      
      print('Final similarity score: $similarity (Hamming distance: $hammingDist, max allowed: $maxAllowedHammingDistance)');
      
      return {'success': true, 'similarity': similarity};
      } catch (e, stackTrace) {
      print('Failed to process and compare faces: $e');
      print('Stack trace: $stackTrace');
      return {'success': false, 'similarity': 0.0};
    } finally {
      
      try {
        if (decodedProfileImage != null && decodedProfileImage != profileImage) {
          decodedProfileImage = null;
        }
        if (rebuiltCapturedImage != null && rebuiltCapturedImage != capturedImage) {
          rebuiltCapturedImage = null;
        }
        profileImage = null;
        capturedImage = null;
        capturedFaceImage = null;

        print('All closures cleaned up in isolate - resources freed');
      } catch (cleanupError) {
        print('Warning: Error during cleanup: $cleanupError');
      }
    }
  }
  
  static img.Image? _decodeBase64ImageStatic(String base64String) {
    try {
      
      String cleanBase64 = base64String.trim();
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',')[1];
      }
      
      final bytes = Uint8List.fromList(base64Decode(cleanBase64));
      
      return img.decodeImage(bytes);
    } catch (e) {
      print('Base64 image decoding failed: $e');
          return null;
        }
  }
  
  static int _calculateImageHashStatic(img.Image image) {
    img.Image? workingImage;
    img.Image? resized;
    
    try {
      
      if (image.width > 256 || image.height > 256) {
        final maxDimension = image.width > image.height ? image.width : image.height;
        final scale = 256.0 / maxDimension;
        final newWidth = (image.width * scale).round().clamp(1, 256);
        final newHeight = (image.height * scale).round().clamp(1, 256);
        workingImage = img.copyResize(
          image, 
          width: newWidth, 
          height: newHeight, 
          interpolation: img.Interpolation.linear,
        );
        } else {
        workingImage = image;
      }
      
      resized = img.copyResize(
        workingImage, 
        width: 16, 
        height: 16, 
        interpolation: img.Interpolation.linear,
      );
      
      int sum = 0;
      final grayPixels = <int>[];
      
      for (int y = 0; y < 16; y++) {
        for (int x = 0; x < 16; x++) {
          final pixel = resized.getPixel(x, y);
          final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).round();
          grayPixels.add(gray);
          sum += gray;
        }
      }
      
      final average = sum ~/ 256; 
      
      int hash = 0;
      for (int i = 0; i < grayPixels.length; i++) {
        if (grayPixels[i] > average) {
          hash |= (1 << i);
        }
      }
      
      return hash;
    } catch (e) {
      print('Failed to calculate image hash: $e');
      return 0;
    } finally {
      
      if (workingImage != null && workingImage != image) {
        workingImage = null;
      }
      resized = null;
    }
  }
  
  static int _hammingDistanceStatic(int hash1, int hash2) {
    int distance = 0;
    int xor = hash1 ^ hash2;
    while (xor != 0) {
      distance += xor & 1;
      xor >>= 1;
    }
    return distance;
  }

  Map<String, dynamic> _imageToPixelData(img.Image image) {
    
    img.Image workingImage = image;
    if (image.width > 512 || image.height > 512) {
      final maxDimension = image.width > image.height ? image.width : image.height;
      final scale = 512.0 / maxDimension;
      final newWidth = (image.width * scale).round().clamp(1, 512);
      final newHeight = (image.height * scale).round().clamp(1, 512);
      workingImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
      print('Resized image before pixel extraction: ${image.width}x${image.height} -> ${workingImage.width}x${workingImage.height}');
    }
    
    final pixels = <int>[];
    final width = workingImage.width;
    final height = workingImage.height;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = workingImage.getPixel(x, y);
        pixels.add(pixel.r.toInt());
        pixels.add(pixel.g.toInt());
        pixels.add(pixel.b.toInt());
      }
    }
    
    return {
      'width': width,
      'height': height,
      'pixels': pixels,
    };
  }
  
  static img.Image? _rebuildImageFromPixelData(Map<String, dynamic> imageData) {
    try {
      final width = imageData['width'] as int;
      final height = imageData['height'] as int;
      final pixels = imageData['pixels'] as List;
      
      final image = img.Image(width: width, height: height);
      int pixelIndex = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final r = (pixels[pixelIndex++] as num).toInt();
          final g = (pixels[pixelIndex++] as num).toInt();
          final b = (pixels[pixelIndex++] as num).toInt();
          image.setPixel(x, y, img.ColorRgb8(r, g, b));
        }
      }
      return image;
    } catch (e) {
      print('Failed to rebuild image: $e');
      return null;
    }
  }
  
  void dispose() {
    _faceDetector.close();
    
    _isModelLoaded = false;
  }
}
