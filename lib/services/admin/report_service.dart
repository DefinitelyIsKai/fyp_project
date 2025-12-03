import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project/models/admin/report_model.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference<Map<String, dynamic>> _notificationsRef =
      FirebaseFirestore.instance.collection('notifications');
  final CollectionReference<Map<String, dynamic>> _logsRef =
      FirebaseFirestore.instance.collection('logs');

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

  Future<List<ReportModel>> getReportsByType(ReportType type) async {
    try {
      
      String firestoreType;
      if (type == ReportType.user) {
        firestoreType = 'jobseeker'; 
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

  Future<void> updateReportStatus(
    String reportId,
    ReportStatus status, {
    String? notes,
    String? reviewedBy,
    String? actionTaken,
  }) async {
    
    final reportDoc = await _firestore.collection('reports').doc(reportId).get();
    final reportData = reportDoc.data();
    final reporterId = reportData?['reporterId']?.toString() ?? '';
    final reportReason = reportData?['reason']?.toString() ?? '';
    
    final data = <String, dynamic>{
      'status': status.toString().split('.').last,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
      if (notes != null) 'reviewNotes': notes,
      if (actionTaken != null) 'actionTaken': actionTaken,
    };

    await _firestore.collection('reports').doc(reportId).update(data);
    
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      final reportType = reportData?['type']?.toString() ?? 'unknown';
      
      await _logsRef.add({
        'actionType': status == ReportStatus.resolved ? 'report_resolved' : 'report_dismissed',
        'reportId': reportId,
        'reportType': reportType,
        'reportReason': reportReason,
        'status': status.toString().split('.').last,
        'reporterId': reporterId,
        if (notes != null) 'notes': notes,
        if (actionTaken != null) 'actionTaken': actionTaken,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminId,
      });
    } catch (logError) {
      print('Error creating report status log entry: $logError');
      
    }
    
    if (reporterId.isNotEmpty) {
      await _sendReportStatusNotification(
        reporterId: reporterId,
        reportId: reportId,
        status: status,
        reason: reportReason,
        actionTaken: actionTaken,
      );
    }
  }
  
  Future<void> _sendReportStatusNotification({
    required String reporterId,
    required String reportId,
    required ReportStatus status,
    required String reason,
    String? actionTaken,
  }) async {
    try {
      String title;
      String body;
      String category;
      
      if (status == ReportStatus.resolved) {
        title = 'Report Resolved';
        body = 'Your report regarding "$reason" has been resolved. Appropriate action has been taken against the violation.';
        category = 'report_resolved';
      } else if (status == ReportStatus.dismissed) {
        title = 'Report Dismissed';
        body = 'Your report regarding "$reason" has been reviewed and dismissed. No action was taken as the report was found to be invalid or no violation was found.';
        category = 'report_dismissed';
      } else {
        
        return;
      }
      
      await _notificationsRef.add({
        'userId': reporterId,
        'title': title,
        'body': body,
        'category': category,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': {
          'reportId': reportId,
          'reportReason': reason,
          'status': status.toString().split('.').last,
          if (actionTaken != null) 'actionTaken': actionTaken,
        },
      });
    } catch (e) {
      print('Error sending report status notification: $e');
      
    }
  }

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

  ReportModel _mapReport(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    String reportedItemId = '';
    final reportType = data['type']?.toString().toLowerCase() ?? '';
    
    if (reportType == 'employee' || reportType == 'jobseeker') {
      
      reportedItemId = data['reportedJobseekerId']?.toString() ?? 
                      data['reportedEmployeeId']?.toString() ?? '';
    } else if (reportType == 'post') {
      
      reportedItemId = data['reportedPostId']?.toString() ?? '';
    } else {
      
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
