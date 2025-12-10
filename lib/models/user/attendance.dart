import 'package:cloud_firestore/cloud_firestore.dart';

class Attendance {
  final String id;
  final String applicationId;
  final String postId;
  final String jobseekerId;
  final String recruiterId;
  final String? startImageUrl;
  final String? endImageUrl;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Attendance({
    required this.id,
    required this.applicationId,
    required this.postId,
    required this.jobseekerId,
    required this.recruiterId,
    this.startImageUrl,
    this.endImageUrl,
    this.startTime,
    this.endTime,
    required this.createdAt,
    this.updatedAt,
  });

  factory Attendance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Attendance(
      id: doc.id,
      applicationId: data['applicationId'] as String,
      postId: data['postId'] as String,
      jobseekerId: data['jobseekerId'] as String,
      recruiterId: data['recruiterId'] as String,
      startImageUrl: data['startImageUrl'] as String?,
      endImageUrl: data['endImageUrl'] as String?,
      startTime: (data['startTime'] as Timestamp?)?.toDate(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'applicationId': applicationId,
      'postId': postId,
      'jobseekerId': jobseekerId,
      'recruiterId': recruiterId,
      if (startImageUrl != null) 'startImageUrl': startImageUrl,
      if (endImageUrl != null) 'endImageUrl': endImageUrl,
      if (startTime != null) 'startTime': Timestamp.fromDate(startTime!),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime!),
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  bool get hasStartImage => startImageUrl != null && startImageUrl!.isNotEmpty;
  bool get hasEndImage => endImageUrl != null && endImageUrl!.isNotEmpty;
  bool get isComplete => hasStartImage && hasEndImage;
}

