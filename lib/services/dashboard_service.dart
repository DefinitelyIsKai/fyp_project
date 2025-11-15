import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> getPendingPostsCount() async {
    final snapshot = await _firestore
        .collection('posts')
        .where('status', isEqualTo: 'Pending')
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
}
