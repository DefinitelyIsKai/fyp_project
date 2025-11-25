import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
    try {
      // Query for users with status 'Active'
      final snapshot = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'Active')
          .get();
      
      // Filter to ensure isActive is also true (in case some have status Active but isActive false)
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final isActive = data['isActive'] as bool?;
        // Count only if status is Active AND isActive is true
        if (isActive == true) {
          count++;
        }
      }
      return count;
    } catch (e) {
      // If query fails, try fallback: Get all users and filter in memory
      try {
        final allUsers = await _firestore.collection('users').get();
        int count = 0;
        for (final doc in allUsers.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          final status = data['status'] as String?;
          final isActive = data['isActive'] as bool?;
          // Count users that are both Active status and isActive true
          if (status == 'Active' && isActive == true) {
            count++;
          }
        }
        return count;
      } catch (e2) {
        // Handle permission errors gracefully
        debugPrint('Error getting active users count: $e2');
        return 0;
      }
    }
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
    }).handleError((error) {
      // Handle permission errors gracefully
      // Return 0 if permission is denied
      return 0;
    });
  }
}
