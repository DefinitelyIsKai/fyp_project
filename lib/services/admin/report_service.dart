import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/report_model.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream all reports in real-time
  Stream<List<ReportModel>> streamAllReports() {
    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return _mapReport(doc);
      }).toList();
    });
  }

  /// Stream reports filtered by status
  Stream<List<ReportModel>> streamReportsByStatus(String status) {
    return _firestore
        .collection('reports')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => _mapReport(doc)).toList();
    });
  }

  /// Get all reports
  Future<List<ReportModel>> getAllReports() async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => _mapReport(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get reports by type
  Future<List<ReportModel>> getReportsByType(ReportType type) async {
    try {
      // Map ReportType to Firestore type values
      String firestoreType;
      if (type == ReportType.user) {
        firestoreType = 'jobseeker'; // Use 'jobseeker' as per Firebase structure
      } else if (type == ReportType.jobPost) {
        firestoreType = 'post';
      } else {
        firestoreType = type.toString().split('.').last;
      }
      
      final snapshot = await _firestore
          .collection('reports')
          .where('type', isEqualTo: firestoreType)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => _mapReport(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Update report status
  Future<void> updateReportStatus(
    String reportId,
    ReportStatus status, {
    String? notes,
    String? reviewedBy,
    String? actionTaken,
  }) async {
    final data = <String, dynamic>{
      'status': status.toString().split('.').last,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (notes != null) 'reviewNotes': notes,
      if (actionTaken != null) 'actionTaken': actionTaken,
    };

    await _firestore.collection('reports').doc(reportId).update(data);
  }

  /// Resolve report
  Future<void> resolveReport(
    String reportId, {
    required String action,
    String? notes,
    String? reviewedBy,
  }) async {
    await updateReportStatus(
      reportId,
      ReportStatus.resolved,
      notes: notes,
      reviewedBy: reviewedBy,
      actionTaken: action,
    );
  }

  /// Dismiss report
  Future<void> dismissReport(
    String reportId, {
    String? notes,
    String? reviewedBy,
  }) async {
    await updateReportStatus(
      reportId,
      ReportStatus.dismissed,
      notes: notes,
      reviewedBy: reviewedBy,
      actionTaken: 'Dismissed',
    );
  }

  /// Map Firestore document to ReportModel
  ReportModel _mapReport(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Determine the reported item ID based on report type
    String reportedItemId = '';
    final reportType = data['type']?.toString().toLowerCase() ?? '';
    
    if (reportType == 'employee' || reportType == 'jobseeker') {
      // For employee/jobseeker reports, the reported item is the jobseeker
      reportedItemId = data['reportedJobseekerId']?.toString() ?? 
                      data['reportedEmployeeId']?.toString() ?? '';
    } else if (reportType == 'post') {
      // For post reports, the reported item is the post
      reportedItemId = data['reportedPostId']?.toString() ?? '';
    } else {
      // Fallback to old structure if it exists
      reportedItemId = data['reportedItemId']?.toString() ?? 
                      data['reportedPostId']?.toString() ?? 
                      data['reportedEmployeeId']?.toString() ?? '';
    }
    
    return ReportModel(
      id: doc.id,
      reporterId: data['reporterId']?.toString() ?? '',
      reportedItemId: reportedItemId,
      reportType: _parseReportType(data['type'] ?? data['reportType']),
      reason: data['reason']?.toString() ?? '',
      description: data['description']?.toString(),
      reportedAt: () {
        final timestamp = (data['createdAt'] as Timestamp?) ?? (data['reportedAt'] as Timestamp?);
        if (timestamp != null) {
          // Firestore Timestamp stores time in UTC
          // Convert to local time explicitly
          // Use seconds since epoch to create UTC DateTime, then convert to local
          return DateTime.fromMillisecondsSinceEpoch(
            timestamp.millisecondsSinceEpoch,
            isUtc: true,
          ).toLocal();
        }
        return DateTime.now();
      }(),
      status: _parseReportStatus(data['status']),
      reviewedBy: data['reviewedBy']?.toString(),
      reviewedAt: () {
        final timestamp = data['reviewedAt'] as Timestamp?;
        if (timestamp != null) {
          // Firestore Timestamp stores time in UTC
          // Convert to local time explicitly
          return DateTime.fromMillisecondsSinceEpoch(
            timestamp.millisecondsSinceEpoch,
            isUtc: true,
          ).toLocal();
        }
        return null;
      }(),
      reviewNotes: data['reviewNotes']?.toString(),
      actionTaken: data['actionTaken']?.toString(),
      reportedEmployeeId: data['reportedEmployeeId']?.toString(),
      reportedEmployerId: data['reportedEmployerId']?.toString(),
      reportedPostId: data['reportedPostId']?.toString(),
    );
  }

  ReportType _parseReportType(dynamic value) {
    if (value == null) return ReportType.other;
    final str = value.toString().toLowerCase();
    
    // Map Firestore type values to ReportType enum
    if (str == 'post') return ReportType.jobPost;
    if (str == 'employee' || str == 'jobseeker') return ReportType.user;
    if (str.contains('job') || str.contains('post')) return ReportType.jobPost;
    if (str.contains('user') || str.contains('employee') || str.contains('jobseeker')) return ReportType.user;
    if (str.contains('message')) return ReportType.message;
    return ReportType.other;
  }

  ReportStatus _parseReportStatus(dynamic value) {
    if (value == null) return ReportStatus.pending;
    final str = value.toString().toLowerCase();
    if (str.contains('pending')) return ReportStatus.pending;
    if (str.contains('review')) return ReportStatus.underReview;
    if (str.contains('resolved')) return ReportStatus.resolved;
    if (str.contains('dismissed')) return ReportStatus.dismissed;
    return ReportStatus.pending;
  }
}
