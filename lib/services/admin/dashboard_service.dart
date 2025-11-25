import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> getPendingPostsCount() async {
    final snapshot = await _firestore
        .collection('posts')
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.length;
  }

  Future<int> getActiveUsersCount() async {
    final snapshot = await _firestore
        .collection('users')
        .where('status', isEqualTo: 'Active')
        .get();
    return snapshot.docs.length;
  }

  Future<int> getMessagesCount() async {
    final snapshot = await _firestore
        .collection('messages')
        .where('needsReview', isEqualTo: true)
        .get();
    return snapshot.docs.length;
  }

  /// Get count of unresolved reports (pending + underReview)
  Future<int> getUnresolvedReportsCount() async {
    try {
      // Get pending reports
      final pendingSnapshot = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .get();
      
      // Get under review reports
      final underReviewSnapshot = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'underReview')
          .get();
      
      return pendingSnapshot.docs.length + underReviewSnapshot.docs.length;
    } catch (e) {
      // If query fails, try getting all reports and filtering
      try {
        final allReports = await _firestore.collection('reports').get();
        int count = 0;
        for (final doc in allReports.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          final status = (data['status'] as String? ?? '').toLowerCase();
          if (status == 'pending' || status == 'underreview' || status == 'under_review') {
            count++;
          }
        }
        return count;
      } catch (e2) {
        return 0;
      }
    }
  }

  /// Stream unresolved reports count in real-time
  Stream<int> streamUnresolvedReportsCount() {
    return _firestore.collection('reports').snapshots().map((snapshot) {
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final status = (data['status'] as String? ?? '').toLowerCase();
        if (status == 'pending' || status == 'underreview' || status == 'under_review') {
          count++;
        }
      }
      return count;
    });
  }
}
