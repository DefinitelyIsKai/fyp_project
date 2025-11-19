import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/user_model.dart';

class UserService {
  UserService() : _usersRef = FirebaseFirestore.instance.collection('users');

  final CollectionReference<Map<String, dynamic>> _usersRef;

  List<UserModel> _mapUsers(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs
        .map((doc) => UserModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _usersRef.get();
    final users = _mapUsers(snapshot);
    users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return users;
  }

  Future<List<UserModel>> searchUsers(String query) async {
    query = query.trim();
    if (query.isEmpty) return getAllUsers();

    final snapshot = await _usersRef.get();
    final lower = query.toLowerCase();

    return _mapUsers(snapshot).where((u) {
      return u.fullName.toLowerCase().contains(lower) ||
          u.email.toLowerCase().contains(lower);
    }).toList();
  }

  Future<List<UserModel>> getSuspendedUsers() async {
    final snap = await _usersRef.where('status', isEqualTo: 'Suspended').get();
    final users = _mapUsers(snap);
    users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return users;
  }

  Future<List<UserModel>> getReportedUsers() async {
    final snap = await _usersRef.where('reportCount', isGreaterThan: 0).get();
    final users = _mapUsers(snap);
    users.sort((a, b) => b.reportCount.compareTo(a.reportCount));
    return users;
  }

  Future<void> suspendUser(String userId, {String? violationReason, int? durationDays}) async {
    await _usersRef.doc(userId).update({
      'status': 'Suspended',
      'suspendedAt': FieldValue.serverTimestamp(),
      'suspensionReason': violationReason,
      'suspensionDuration': durationDays,
    });
  }

  Future<void> unsuspendUser(String userId) async {
    await _usersRef.doc(userId).update({
      'status': 'Active',
      'isActive': true,
      'suspendedAt': null,
      'suspensionReason': null,
      'suspensionDuration': null,
    });
  }

  Future<void> deleteUser(String userId, {String? deletionReason}) async {
    await _usersRef.doc(userId).update({
      'status': 'Deleted',
      'isActive': false,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletionReason': deletionReason,
    });
  }
}