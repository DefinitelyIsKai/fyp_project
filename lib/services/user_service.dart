import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/user_model.dart';

class UserService {
  UserService() : _usersRef = FirebaseFirestore.instance.collection('users');

  final CollectionReference<Map<String, dynamic>> _usersRef;

  List<UserModel> _mapUsers(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final List<UserModel> users = [];
    for (var doc in snapshot.docs) {
      try {
        final user = UserModel.fromJson(doc.data(), doc.id);
        users.add(user);
      } catch (e) {
        print('Error parsing user document ${doc.id}: $e');
      }
    }
    return users;
  }

  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _usersRef.get();
    final users = _mapUsers(snapshot);
    users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return users;
  }
  
    Future<List<UserModel>> searchUsers(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return getAllUsers();
    }

    try {
      final snapshot = await _usersRef.get();
      final lowerQuery = trimmedQuery.toLowerCase();
      return _mapUsers(snapshot).where((user) {
        return user.fullName.toLowerCase().contains(lowerQuery) ||
            user.email.toLowerCase().contains(lowerQuery);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  Future<List<UserModel>> getSuspendedUsers() async {
    final snapshot = await _usersRef.where('status', isEqualTo: 'Suspended').get();
    final users = _mapUsers(snapshot);
    users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return users;
  }

  Future<List<UserModel>> getReportedUsers() async {
    final snapshot = await _usersRef.where('reportCount', isGreaterThan: 0).get();
    final users = _mapUsers(snapshot);
    users.sort((a, b) => b.reportCount.compareTo(a.reportCount));
    return users;
  }

  Future<void> suspendUser(String userId) async {
    try {
      await _usersRef.doc(userId).update({
        'status': 'Suspended',
      });
    } catch (e) {
      throw Exception('Failed to suspend user: $e');
    }
  }

  Future<void> unsuspendUser(String userId) async {
    try {
      await _usersRef.doc(userId).update({
        'status': 'Active',
      });
    } catch (e) {
      throw Exception('Failed to unsuspend user: $e');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _usersRef.doc(userId).update({
        'status': 'Non-active',
      });
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }
}
