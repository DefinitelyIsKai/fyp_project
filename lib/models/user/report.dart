import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportType {post, jobseeker}

enum ReportStatus {pending,reviewed,resolved,dismissed}

class Report {
  final String id;
  final ReportType type;
  final String reporterId; 
  final String reportedPostId; 
  final String? reportedJobseekerId;
  final String? reportedRecruiterId;
  final String reason;
  final String description; 
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy; 
  final String? adminNotes;

  Report({
    required this.id,
    required this.type,
    required this.reporterId,
    required this.reportedPostId,
    this.reportedJobseekerId,
    this.reportedRecruiterId,
    required this.reason,
    required this.description,
    this.status = ReportStatus.pending,
    DateTime? createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.adminNotes,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Report(
      id: doc.id,
      type: _typeFromString(data['type'] as String? ?? 'post'),
      reporterId: data['reporterId'] as String,
      reportedPostId: data['reportedPostId'] as String,
      reportedJobseekerId: data['reportedJobseekerId'] as String?,
      reportedRecruiterId: data['reportedRecruiterId'] as String?,
      reason: data['reason'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: _statusFromString(data['status'] as String? ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      adminNotes: data['adminNotes'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': _typeToString(type),
      'reporterId': reporterId,
      'reportedPostId': reportedPostId,
      if (reportedJobseekerId != null) 'reportedJobseekerId': reportedJobseekerId,
      if (reportedRecruiterId != null) 'reportedRecruiterId': reportedRecruiterId,
      'reason': reason,
      'description': description,
      'status': _statusToString(status),
      'createdAt': Timestamp.fromDate(createdAt),
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (adminNotes != null) 'adminNotes': adminNotes,
    };
  }

  static ReportType _typeFromString(String value) {
    switch (value) {
      case 'post':
        return ReportType.post;
      case 'jobseeker':
        return ReportType.jobseeker;
      default:
        return ReportType.post;
    }
  }

  static String _typeToString(ReportType type) {
    switch (type) {
      case ReportType.post:
        return 'post';
      case ReportType.jobseeker:
        return 'jobseeker';
    }
  }

  static ReportStatus _statusFromString(String value) {
    switch (value) {
      case 'pending':
        return ReportStatus.pending;
      case 'reviewed':
        return ReportStatus.reviewed;
      case 'resolved':
        return ReportStatus.resolved;
      case 'dismissed':
        return ReportStatus.dismissed;
      default:
        return ReportStatus.pending;
    }
  }

  static String _statusToString(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return 'pending';
      case ReportStatus.reviewed:
        return 'reviewed';
      case ReportStatus.resolved:
        return 'resolved';
      case ReportStatus.dismissed:
        return 'dismissed';
    }
  }
}

