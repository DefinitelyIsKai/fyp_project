import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image/image.dart' as img;
import '../../services/admin/face_recognition_service.dart';

class FaceScanWidget extends StatefulWidget {
  final Function(img.Image image, Face? face)? onImageCaptured;
  final String? instructionText;
  final bool showFaceDetection; 

  const FaceScanWidget({
    super.key,
    this.onImageCaptured,
    this.instructionText,
    this.showFaceDetection = true,
  });

  @override
  State<FaceScanWidget> createState() => _FaceScanWidgetState();
}

class _FaceScanWidgetState extends State<FaceScanWidget> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isCapturing = false;
  bool _isDisposing = false;
  Face? _detectedFace;
  final FaceRecognitionService _faceService = FaceRecognitionService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到可用相机')),
          );
        }
        return;
      }

      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high, 
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        
        if (widget.showFaceDetection) {
          _startImageStream();
        }
      }
    } catch (e) {
      print('相机初始化失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('相机初始化失败: $e')),
        );
      }
    }
  }

  void _startImageStream() async {
    if (!widget.showFaceDetection || _isCapturing || _isDisposing) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (!mounted) return;
    
    if (_cameraController!.value.isStreamingImages) {
      return; 
    }
    
    try {
      await _cameraController!.startImageStream((CameraImage image) {
        if (!_isProcessing && !_isCapturing && !_isDisposing && mounted) {
          _processImageForDetection(image);
        }
      });
    } catch (e) {
      print('Failed to start image stream: $e');
    }
  }

  Future<void> _processImageForDetection(CameraImage cameraImage) async {
    if (_isProcessing || _isCapturing) return;
    if (!mounted) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      
      final inputImage = _cameraImageToInputImage(cameraImage);
      if (inputImage == null) {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
        return;
      }

      final faces = await _faceService.detectFaces(inputImage);

      if (!mounted) return;
      
      final currentFace = faces.isNotEmpty ? faces.first : null;
      
      setState(() {
        _detectedFace = currentFace;
        _isProcessing = false;
      });
    } catch (e) {
      print('人脸检测失败: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Camera not initialized');
      return;
    }

    if (_isCapturing) {
      print('Already capturing, please wait...');
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      
      if (widget.showFaceDetection && _cameraController!.value.isStreamingImages) {
        try {
          await _cameraController!.stopImageStream();
          
          await Future.delayed(const Duration(milliseconds: 150));
        } catch (e) {
          print('Error stopping image stream: $e');
        }
      }

      final XFile photo = await _cameraController!.takePicture();
      
      final bytes = await photo.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        print('无法解码照片');
        if (mounted) {
          setState(() => _isCapturing = false);
          
          if (widget.showFaceDetection) {
            _startImageStream();
          }
        }
        return;
      }

      Face? detectedFace;
      if (widget.showFaceDetection) {
        try {
          
          final inputImage = _imageToInputImage(image);
          if (inputImage != null) {
            final faces = await _faceService.detectFaces(inputImage);
            if (faces.isNotEmpty) {
              detectedFace = faces.first;
            }
          }
        } catch (e) {
          print('人脸检测失败: $e');
          
        }
      }

      if (mounted && widget.onImageCaptured != null) {
        widget.onImageCaptured!(image, detectedFace);
      }

      if (widget.showFaceDetection && mounted) {
        
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted && _cameraController?.value.isInitialized == true) {
          _startImageStream();
        }
      }

      if (mounted) {
        setState(() => _isCapturing = false);
      }
    } catch (e) {
      print('Capture failed: $e');
      if (mounted) {
        setState(() => _isCapturing = false);
        
        if (widget.showFaceDetection) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted && _cameraController?.value.isInitialized == true) {
            _startImageStream();
          }
        }
      }
    }
  }

  InputImage? _imageToInputImage(img.Image image) {
    try {
      
      final bytes = image.getBytes();
      
      final bytesPerRow = image.width * 4;
      
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.bgra8888, 
        bytesPerRow: bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: metadata,
      );
    } catch (e) {
      print('InputImage 转换失败: $e');
      
      return null;
    }
  }

  InputImage? _cameraImageToInputImage(CameraImage cameraImage) {
    try {
      final imageRotation = InputImageRotation.rotation0deg;
      
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        
        final yPlane = cameraImage.planes[0];
        final uPlane = cameraImage.planes.length > 1 ? cameraImage.planes[1] : null;
        final vPlane = cameraImage.planes.length > 2 ? cameraImage.planes[2] : null;

        final yBytes = yPlane.bytes;
        final uvBytes = WriteBuffer();
        
        if (uPlane != null && vPlane != null) {
          
          final uBytes = uPlane.bytes;
          final vBytes = vPlane.bytes;
          final uvLength = uBytes.length;
          for (int i = 0; i < uvLength; i++) {
            uvBytes.putUint8(vBytes[i]);
            uvBytes.putUint8(uBytes[i]);
          }
        }
        
        final nv21Bytes = WriteBuffer();
        nv21Bytes.putUint8List(yBytes);
        nv21Bytes.putUint8List(uvBytes.done().buffer.asUint8List());
        final bytes = nv21Bytes.done().buffer.asUint8List();

        final metadata = InputImageMetadata(
          size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          rotation: imageRotation,
          format: InputImageFormat.nv21,
          bytesPerRow: yPlane.bytesPerRow,
        );

        return InputImage.fromBytes(
          bytes: bytes,
          metadata: metadata,
        );
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        
        final format = InputImageFormat.bgra8888;
        final plane = cameraImage.planes[0];
        
        final metadata = InputImageMetadata(
          size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          rotation: imageRotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        );

        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: metadata,
        );
      } else {
        print('不支持的图像格式: ${cameraImage.format.group}');
        return null;
      }
    } catch (e) {
      print('InputImage 创建失败: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    
    if (_cameraController?.value.isStreamingImages == true) {
      try {
        _cameraController?.stopImageStream();
        
      } catch (e) {
        print('Error stopping image stream in dispose: $e');
      }
    }
    
    _cameraController?.dispose();
    _cameraController = null;
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: CameraPreview(_cameraController!),
        ),
        
        if (widget.showFaceDetection && _detectedFace != null)
          _buildFaceBox(_detectedFace!),
        
        Positioned(
          top: 40,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.instructionText ??
                  (_detectedFace != null
                      ? '✓ 检测到人脸，点击拍照按钮'
                      : '请将脸部对准相机，然后点击拍照'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _isCapturing ? null : captureImage,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isCapturing ? Colors.grey : Colors.white,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: _isCapturing
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt,
                        size: 40,
                        color: Colors.black,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFaceBox(Face face) {
    final size = MediaQuery.of(context).size;
    final cameraSize = _cameraController!.value.previewSize!;
    
    final scaleX = size.width / cameraSize.height;
    final scaleY = size.height / cameraSize.width;
    
    final boundingBox = face.boundingBox;
    
    final left = boundingBox.top * scaleX;
    final top = (cameraSize.width - boundingBox.right) * scaleY;
    final width = boundingBox.height * scaleX;
    final height = boundingBox.width * scaleY;
    
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.green,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
