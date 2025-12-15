import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user/attendance.dart';
import '../../models/user/application.dart';
import '../../services/user/attendance_service.dart';
import '../../services/user/application_service.dart';
import '../../widgets/user/loading_indicator.dart';

class AttendanceViewDialog extends StatefulWidget {
  final String postId;
  final ApplicationService applicationService;
  final AttendanceService attendanceService;

  const AttendanceViewDialog({
    super.key,
    required this.postId,
    required this.applicationService,
    required this.attendanceService,
  });

  @override
  State<AttendanceViewDialog> createState() => _AttendanceViewDialogState();
}

class _AttendanceViewDialogState extends State<AttendanceViewDialog> {
  final Map<String, String> _jobseekerNames = {};

  Future<void> _ensureName(String userId) async {
    if (_jobseekerNames.containsKey(userId)) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      _jobseekerNames[userId] =
          userDoc.data()?['fullName'] as String? ?? 'Unknown';
    } catch (_) {
      _jobseekerNames[userId] = 'Unknown';
    }
    
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Widget _buildImagePreview({
    required String? imageBase64,
    required String label,
  }) {
    Uint8List? imageBytes;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        imageBytes = base64Decode(imageBase64);
      } catch (e) {
        debugPrint('Error decoding image: $e');
      }
    }

    return Container(
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
      child: imageBytes != null
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
                  Icons.image_not_supported,
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
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00C8A0).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C8A0).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF00C8A0),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Check Attendance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.black87,
                        size: 20,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: StreamBuilder<List<Application>>(
                stream: widget.applicationService.streamPostApplications(widget.postId),
                builder: (context, appSnapshot) {
                  if (appSnapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingIndicator.standard();
                  }

                  final applications = appSnapshot.data ?? [];
                  final approvedApplications = applications
                      .where((app) => app.status == ApplicationStatus.approved)
                      .toList();

                  if (approvedApplications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No approved applications',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  }

                  return StreamBuilder<List<Attendance>>(
                    stream: widget.attendanceService.streamAttendancesByPostId(widget.postId),
                    builder: (context, attendanceSnapshot) {
                      if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
                        return const LoadingIndicator.standard();
                      }

                      final attendances = attendanceSnapshot.data ?? [];
                      final attendanceMap = <String, Attendance>{};
                      for (final attendance in attendances) {
                        attendanceMap[attendance.applicationId] = attendance;
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: approvedApplications.length,
                        itemBuilder: (context, index) {
                          final app = approvedApplications[index];
                          final attendance = attendanceMap[app.id];
                          _ensureName(app.jobseekerId);
                          final jobseekerName = _jobseekerNames[app.jobseekerId] ?? 'Unknown';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF00C8A0).withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00C8A0).withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00C8A0).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: Color(0xFF00C8A0),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            jobseekerName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (attendance != null && attendance.isComplete)
                                            Container(
                                              margin: const EdgeInsets.only(top: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF00C8A0).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                'Complete',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF00C8A0),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Start Image',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildImagePreview(
                                  imageBase64: attendance?.startImageUrl,
                                  label: 'No start image uploaded',
                                ),
                                if (attendance?.startTime != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Start Time: ${_formatDateTime(attendance!.startTime)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Text(
                                  'End Image',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildImagePreview(
                                  imageBase64: attendance?.endImageUrl,
                                  label: 'No end image uploaded',
                                ),
                                if (attendance?.endTime != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'End Time: ${_formatDateTime(attendance!.endTime)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

