import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../services/user/attendance_service.dart';
import '../../../models/user/attendance.dart';
import '../../../utils/user/dialog_utils.dart';

class AttendancePage extends StatefulWidget {
  final String applicationId;
  final String postId;
  final String recruiterId;

  const AttendancePage({
    super.key,
    required this.applicationId,
    required this.postId,
    required this.recruiterId,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final AttendanceService _attendanceService = AttendanceService();
  
  Attendance? _attendance;
  bool _isLoading = true;
  bool _isUploadingStart = false;
  bool _isUploadingEnd = false;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    try {
      setState(() => _isLoading = true);
      _attendance = await _attendanceService.getOrCreateAttendance(
        applicationId: widget.applicationId,
        postId: widget.postId,
        recruiterId: widget.recruiterId,
      );
    } catch (e) {
      if (mounted) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Failed to load attendance: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadStartImage({required bool fromCamera, String? preferredCamera}) async {
    if (_attendance == null) return;

    try {
      setState(() => _isUploadingStart = true);
      await _attendanceService.uploadStartImage(
        attendanceId: _attendance!.id,
        fromCamera: fromCamera,
        preferredCamera: preferredCamera,
      );
      
      if (mounted) {
        DialogUtils.showSuccessMessage(
          context: context,
          message: 'Start image uploaded successfully',
        );
        await _loadAttendance();
      }
    } catch (e) {
      // Silently ignore if user cancelled image selection
      final errorMessage = e.toString();
      if (errorMessage.contains('No image selected')) {
        // User cancelled - don't show any message
        return;
      }
      if (mounted) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Failed to upload start image: ${errorMessage.replaceAll('Exception: ', '').replaceAll('StateError: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingStart = false);
      }
    }
  }

  Future<void> _uploadEndImage({required bool fromCamera, String? preferredCamera}) async {
    if (_attendance == null) return;

    try {
      setState(() => _isUploadingEnd = true);
      await _attendanceService.uploadEndImage(
        attendanceId: _attendance!.id,
        fromCamera: fromCamera,
        preferredCamera: preferredCamera,
      );
      
      if (mounted) {
        DialogUtils.showSuccessMessage(
          context: context,
          message: 'End image uploaded successfully',
        );
        await _loadAttendance();
      }
    } catch (e) {
      // Silently ignore if user cancelled image selection
      final errorMessage = e.toString();
      if (errorMessage.contains('No image selected')) {
        // User cancelled - don't show any message
        return;
      }
      if (mounted) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Failed to upload end image: ${errorMessage.replaceAll('Exception: ', '').replaceAll('StateError: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingEnd = false);
      }
    }
  }

  Future<void> _showImageSourceDialog({required bool isStart}) async {
    final hasImage = isStart 
        ? (_attendance?.hasStartImage ?? false)
        : (_attendance?.hasEndImage ?? false);

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
                isStart ? 'Upload Start Image' : 'Upload End Image',
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
              if (hasImage) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove photo'),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    if (source == 'remove') {
      _removeImage(isStart: isStart);
    } else if (source == 'camera') {
      if (isStart) {
        _uploadStartImage(fromCamera: true);
      } else {
        _uploadEndImage(fromCamera: true);
      }
    } else {
      if (isStart) {
        _uploadStartImage(fromCamera: false);
      } else {
        _uploadEndImage(fromCamera: false);
      }
    }
  }

  Future<void> _removeImage({required bool isStart}) async {
    if (_attendance == null) return;

    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: isStart ? 'Remove Start Image' : 'Remove End Image',
      message: 'Are you sure you want to remove this image? This action cannot be undone.',
      icon: Icons.delete_outline,
      confirmText: 'Remove',
      cancelText: 'Cancel',
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;

    try {
      if (isStart) {
        setState(() => _isUploadingStart = true);
        await _attendanceService.removeStartImage(attendanceId: _attendance!.id);
      } else {
        setState(() => _isUploadingEnd = true);
        await _attendanceService.removeEndImage(attendanceId: _attendance!.id);
      }
      
      if (mounted) {
        DialogUtils.showSuccessMessage(
          context: context,
          message: isStart ? 'Start image removed successfully' : 'End image removed successfully',
        );
        await _loadAttendance();
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Failed to remove image: ${e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingStart = false;
          _isUploadingEnd = false;
        });
      }
    }
  }

  Widget _buildImagePreview({
    required String? imageBase64,
    required String label,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    Uint8List? imageBytes;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        imageBytes = base64Decode(imageBase64);
      } catch (e) {
        debugPrint('Error decoding image: $e');
      }
    }

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00C8A0),
                ),
              )
            : imageBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Attendance',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00C8A0),
              ),
            )
          : _attendance == null
              ? Center(
                  child: Text(
                    'Failed to load attendance',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C8A0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00C8A0).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: const Color(0xFF00C8A0),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please upload your start and end images to record your attendance',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Start Image Section
                      Text(
                        'Start Image',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildImagePreview(
                        imageBase64: _attendance!.startImageUrl,
                        label: 'Tap to upload start image',
                        onTap: () => _showImageSourceDialog(isStart: true),
                        isLoading: _isUploadingStart,
                      ),
                      if (_attendance!.startTime != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Upload Time: ${_formatDateTime(_attendance!.startTime!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // End Image Section
                      Text(
                        'End Image',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildImagePreview(
                        imageBase64: _attendance!.endImageUrl,
                        label: 'Tap to upload end image',
                        onTap: () => _showImageSourceDialog(isStart: false),
                        isLoading: _isUploadingEnd,
                      ),
                      if (_attendance!.endTime != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Upload Time: ${_formatDateTime(_attendance!.endTime!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      // Status Card
                      if (_attendance!.isComplete)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C8A0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00C8A0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Color(0xFF00C8A0),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Attendance Complete',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF00C8A0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}