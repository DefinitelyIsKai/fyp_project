import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/report_model.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream all reports in real-time
  Stream<List<ReportModel>> streamAllReports() {
    return _firestore
        .collection('reports')
        .orderBy('reportedAt', descending: true)
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
        .orderBy('reportedAt', descending: true)
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
          .orderBy('reportedAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => _mapReport(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get reports by type
  Future<List<ReportModel>> getReportsByType(ReportType type) async {
    try {
      final snapshot = await _firestore
          .collection('reports')
          .where('reportType', isEqualTo: type.toString().split('.').last)
          .orderBy('reportedAt', descending: true)
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
    
    return ReportModel(
      id: doc.id,
      reporterId: data['reporterId'] ?? '',
      reportedItemId: data['reportedItemId'] ?? '',
      reportType: _parseReportType(data['reportType']),
      reason: data['reason'] ?? '',
      description: data['description'],
      reportedAt: (data['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _parseReportStatus(data['status']),
      reviewedBy: data['reviewedBy'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewNotes: data['reviewNotes'],
      actionTaken: data['actionTaken'],
    );
  }

  ReportType _parseReportType(dynamic value) {
    if (value == null) return ReportType.other;
    final str = value.toString().toLowerCase();
    if (str.contains('job') || str.contains('post')) return ReportType.jobPost;
    if (str.contains('user')) return ReportType.user;
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
