import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> getPendingPostsCount() async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('status', isEqualTo: 'pending')
          .get();
      
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final isDraft = data['isDraft'] as bool?;
        
        if (isDraft != true) {
          count++;
        }
      }
      return count;
    } catch (e) {
      debugPrint('Error getting pending posts count: $e');
      return 0;
    }
  }

  Future<int> getActiveUsersCount() async {
    try {
      
      final snapshot = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'Active')
          .get();
      
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final isActive = data['isActive'] as bool?;
        
        if (isActive == true) {
          count++;
        }
      }
      return count;
    } catch (e) {
      
      try {
        final allUsers = await _firestore.collection('users').get();
        int count = 0;
        for (final doc in allUsers.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;
          final status = data['status'] as String?;
          final isActive = data['isActive'] as bool?;
          
          if (status == 'Active' && isActive == true) {
            count++;
          }
        }
        return count;
      } catch (e2) {
        
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

  Future<int> getUnresolvedReportsCount() async {
    try {
      
      final pendingSnapshot = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .get();
      
      final underReviewSnapshot = await _firestore
          .collection('reports')
          .where('status', isEqualTo: 'underReview')
          .get();
      
      return pendingSnapshot.docs.length + underReviewSnapshot.docs.length;
    } catch (e) {
      
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
      
      return 0;
    });
  }

  Stream<int> streamPendingPostsCount() {
    return _firestore
        .collection('posts')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final isDraft = data['isDraft'] as bool?;
        
        if (isDraft != true) {
          count++;
        }
      }
      return count;
    }).handleError((error) {
      
      debugPrint('Error streaming pending posts count: $error');
      return 0;
    });
  }
}
