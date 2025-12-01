import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../../../services/admin/face_recognition_service.dart';
import '../../../widgets/admin/face_scan_widget.dart';

/// Face verification page
/// Verifies user identity during login
class FaceVerificationPage extends StatefulWidget {
  final String profileImageBase64;
  final VoidCallback onVerificationSuccess;
  final VoidCallback? onVerificationFailed;
  final VoidCallback? onCancel;

  const FaceVerificationPage({
    super.key,
    required this.profileImageBase64,
    required this.onVerificationSuccess,
    this.onVerificationFailed,
    this.onCancel,
  });

  @override
  State<FaceVerificationPage> createState() => _FaceVerificationPageState();
}

class _FaceVerificationPageState extends State<FaceVerificationPage> {
  final FaceRecognitionService _faceService = FaceRecognitionService();
  bool _isModelLoaded = false;
  bool _isVerifying = false;
  bool _isInitializing = true;
  String _statusMessage = '正在初始化...';
  int _attemptCount = 0;
  static const int _maxAttempts = 3;
  img.Image? _capturedImage;
  Face? _capturedFace;
  Face? _detectedFace; // Currently detected face (used to display button)

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      setState(() {
        _statusMessage = '正在初始化人脸识别服务...';
      });

      final success = await _faceService.initialize();
      if (!success) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _statusMessage = '初始化失败';
          });
          _showErrorDialog('初始化失败', '无法初始化人脸识别服务，请重试');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isModelLoaded = true;
          _isInitializing = false;
          _statusMessage = '请将脸部对准相机';
        });
      }
    } catch (e) {
      print('Initialization failed: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = 'Initialization failed';
        });
        _showErrorDialog('Initialization failed', 'Unable to start face recognition service: $e');
      }
    }
  }

  /// Handle captured image after photo taken
  Future<void> _handleImageCaptured(img.Image image, Face? face) async {
    if (_isVerifying || _attemptCount >= _maxAttempts) {
      print('Skipping verification: isVerifying=$_isVerifying, attemptCount=$_attemptCount');
      return;
    }

    print('Received photo capture callback');

    if (!mounted) return;
    
    setState(() {
      _capturedImage = image;
      _capturedFace = face;
      _statusMessage = '正在验证身份...';
    });

    // Automatically start verification
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _isVerifying) return;
    
    if (_capturedImage != null && mounted) {
      print('Starting verification...');
      await _verifyFace();
    }
  }

  Future<void> _verifyFace() async {
    if (_capturedImage == null) return;
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _statusMessage = '正在验证身份...';
    });

    try {
      // If face detected, use face region; otherwise use full image
      final similarity = await _faceService.compareFaces(
        widget.profileImageBase64,
        _capturedImage!,
        _capturedFace, // May be null
      );

      print('Similarity score: $similarity');

      // Similarity threshold (0.95 for strict matching)
      // Very high threshold to prevent false positives (other faces being accepted)
      // If legitimate users are rejected, lower this value slightly
      const threshold = 0.96;

      if (similarity >= threshold) {
        // Verification successful
        if (mounted) {
          setState(() {
            _statusMessage = 'Verification successful!';
          });
          await Future.delayed(const Duration(milliseconds: 500));
          widget.onVerificationSuccess();
        }
      } else {
        // Verification failed
        _attemptCount++;
        if (mounted) {
          if (_attemptCount >= _maxAttempts) {
            setState(() {
              _statusMessage = 'Verification failed, maximum attempts reached';
            });
            await Future.delayed(const Duration(milliseconds: 1500));
            if (mounted) {
              widget.onVerificationFailed?.call();
              Navigator.of(context).pop();
            }
          } else {
            setState(() {
              _statusMessage = 'Verification failed, please try again (${_maxAttempts - _attemptCount} attempts remaining)';
              _isVerifying = false;
              _capturedImage = null;
              _capturedFace = null;
            });
            await Future.delayed(const Duration(milliseconds: 2000));
            if (mounted) {
              setState(() {
                _statusMessage = 'Please align your face with the camera';
              });
            }
          }
        }
      }
    } catch (e, stackTrace) {
      print('Verification process error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _statusMessage = '验证出错，请重试';
          _capturedImage = null;
          _capturedFace = null;
          _detectedFace = null;
        });
        // Don't show error dialog, directly allow retry
        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) {
          setState(() {
            _statusMessage = '请将脸部对准相机';
          });
        }
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
              if (mounted) {
                widget.onCancel?.call();
              }
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
              if (mounted) {
                _initializeService();
              }
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            widget.onCancel?.call();
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          '人脸验证',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isInitializing
          ? _buildLoadingState()
          : _isModelLoaded
              ? _buildScanningState()
              : _buildErrorState(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            _statusMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningState() {
    return Stack(
      children: [
        // Face scan widget
        FaceScanWidget(
          onImageCaptured: _handleImageCaptured,
          instructionText: _statusMessage,
          showFaceDetection: true,
        ),
        // Top tip
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  '请确保：',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• 光线充足\n• 脸部清晰可见\n• 正对相机',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                if (_attemptCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '尝试次数: $_attemptCount/$_maxAttempts',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        // Manual verification button (displayed when face is detected)
        if (_detectedFace != null && !_isVerifying && _attemptCount < _maxAttempts)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (_capturedImage != null && _capturedFace != null) {
                    await _verifyFace();
                  }
                },
                icon: const Icon(Icons.face, color: Colors.white),
                label: const Text(
                  '验证身份',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ),
        // Verification overlay
        if (_isVerifying)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  SizedBox(height: 24),
                  Text(
                    '正在验证身份...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 24),
            const Text(
              '初始化失败',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                _initializeService();
              },
              child: const Text('重试'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                widget.onCancel?.call();
                Navigator.of(context).pop();
              },
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }
}

