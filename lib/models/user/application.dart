import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationStatus {
  pending,
  approved,
  rejected,
  deleted,
}

class Application {
  final String id;
  final String postId;
  final String jobseekerId;
  final String recruiterId;
  final ApplicationStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Application({
    required this.id,
    required this.postId,
    required this.jobseekerId,
    required this.recruiterId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory Application.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Application(
      id: doc.id,
      postId: data['postId'] as String,
      jobseekerId: data['jobseekerId'] as String,
      recruiterId: data['recruiterId'] as String,
      status: _statusFromString(data['status'] as String? ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'jobseekerId': jobseekerId,
      'recruiterId': recruiterId,
      'status': _statusToString(status),
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  static ApplicationStatus _statusFromString(String status) {
    switch (status.toLowerCase().trim()) {
      case 'approved':
        return ApplicationStatus.approved;
      case 'rejected':
        return ApplicationStatus.rejected;
      case 'deleted':
        return ApplicationStatus.deleted;
      default:
        return ApplicationStatus.pending;
    }
  }

  static String _statusToString(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.approved:
        return 'approved';
      case ApplicationStatus.rejected:
        return 'rejected';
      case ApplicationStatus.deleted:
        return 'deleted';
      default:
        return 'pending';
    }
  }
}


