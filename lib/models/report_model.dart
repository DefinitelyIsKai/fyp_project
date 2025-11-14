enum ReportType {
  jobPost,
  user,
  message,
  other,
}

enum ReportStatus {
  pending,
  underReview,
  resolved,
  dismissed,
}

class ReportModel {
  final String id;
  final String reporterId;
  final String reportedItemId;
  final ReportType reportType;
  final String reason;
  final String? description;
  final DateTime reportedAt;
  final ReportStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNotes;
  final String? actionTaken;

  ReportModel({
    required this.id,
    required this.reporterId,
    required this.reportedItemId,
    required this.reportType,
    required this.reason,
    this.description,
    required this.reportedAt,
    this.status = ReportStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNotes,
    this.actionTaken,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      reporterId: json['reporterId'] as String,
      reportedItemId: json['reportedItemId'] as String,
      reportType: ReportType.values.firstWhere(
        (e) => e.toString().split('.').last == json['reportType'],
        orElse: () => ReportType.other,
      ),
      reason: json['reason'] as String,
      description: json['description'] as String?,
      reportedAt: DateTime.parse(json['reportedAt'] as String),
      status: ReportStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => ReportStatus.pending,
      ),
      reviewedBy: json['reviewedBy'] as String?,
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'] as String)
          : null,
      reviewNotes: json['reviewNotes'] as String?,
      actionTaken: json['actionTaken'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporterId': reporterId,
      'reportedItemId': reportedItemId,
      'reportType': reportType.toString().split('.').last,
      'reason': reason,
      'description': description,
      'reportedAt': reportedAt.toIso8601String(),
      'status': status.toString().split('.').last,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewNotes': reviewNotes,
      'actionTaken': actionTaken,
    };
  }
}

