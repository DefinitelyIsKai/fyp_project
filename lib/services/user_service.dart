// services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/user_model.dart';

class UserService {
  UserService()
      : _usersRef = FirebaseFirestore.instance.collection('users'),
        _notificationsRef = FirebaseFirestore.instance.collection('notifications');

  final CollectionReference<Map<String, dynamic>> _usersRef;
  final CollectionReference<Map<String, dynamic>> _notificationsRef;

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

  // Get all unique roles from users collection
  Future<List<String>> getAllRoles() async {
    final snapshot = await _usersRef.get();
    final roles = snapshot.docs
        .map((doc) => doc.data()['role'] as String? ?? 'unknown')
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList();

    // Sort roles for consistent ordering
    roles.sort();
    return roles;
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

  // Warning system methods
  Future<int> getStrikeCount(String userId) async {
    try {
      final userDoc = await _usersRef.doc(userId).get();
      return userDoc.data()?['strikeCount'] ?? 0;
    } catch (e) {
      print('Error getting strike count: $e');
      return 0;
    }
  }

  // Complete warning system with notifications
  Future<Map<String, dynamic>> issueWarning({
    required String userId,
    required String violationReason,
  }) async {
    try {
      // Get user data first
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('User not found');
      }

      final currentStrikes = await getStrikeCount(userId);
      final newStrikes = currentStrikes + 1;

      // Add strike to user
      await _usersRef.doc(userId).update({
        'strikeCount': newStrikes,
        'lastStrikeReason': violationReason,
        'lastStrikeAt': FieldValue.serverTimestamp(),
      });

      // Send warning notification
      await _sendWarningNotification(
        userId: userId,
        violationReason: violationReason,
        strikeCount: newStrikes,
        userName: userData['fullName'] ?? 'User',
        userEmail: userData['email'] ?? '',
      );

      // Check if this is the 3rd strike and auto-suspend
      bool wasSuspended = false;
      if (newStrikes >= 3) {
        await suspendUser(
          userId,
          violationReason: 'Automatic suspension: Reached 3 strikes. Final violation: $violationReason',
          durationDays: 7,
        );
        wasSuspended = true;

        // Send suspension notification
        await _sendSuspensionNotification(
          userId: userId,
          violationReason: violationReason,
          durationDays: 7,
          userName: userData['fullName'] ?? 'User',
          userEmail: userData['email'] ?? '',
        );
      }

      return {
        'success': true,
        'strikeCount': newStrikes,
        'wasSuspended': wasSuspended,
        'userName': userData['fullName'] ?? 'User',
      };
    } catch (e) {
      print('Error issuing warning: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<void> resetStrikes(String userId) async {
    try {
      await _usersRef.doc(userId).update({
        'strikeCount': 0,
        'lastStrikeReason': null,
        'lastStrikeAt': null,
      });
    } catch (e) {
      print('Error resetting strikes: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>> unsuspendUserWithReset(String userId) async {
    try {
      // Get user data first
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('User not found');
      }

      // Unsuspend user
      await unsuspendUser(userId);

      // Reset strikes
      await resetStrikes(userId);

      // Send unsuspension notification
      await _sendUnsuspensionNotification(
        userId: userId,
        userName: userData['fullName'] ?? 'User',
        userEmail: userData['email'] ?? '',
      );

      return {
        'success': true,
        'userName': userData['fullName'] ?? 'User',
      };
    } catch (e) {
      print('Error unsuspending user: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<void> suspendUser(String userId, {String? violationReason, int? durationDays}) async {
    await _usersRef.doc(userId).update({
      'status': 'Suspended',
      'isActive': false,
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

  Future<Map<String, dynamic>> deleteUserWithNotification({
    required String userId,
    required String deletionReason,
  }) async {
    try {
      // Get user data first
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('User not found');
      }

      // Send deletion notification
      await _sendDeletionNotification(
        userId: userId,
        userName: userData['fullName'] ?? 'User',
        userEmail: userData['email'] ?? '',
        deletionReason: deletionReason,
      );

      // Delete the user
      await deleteUser(userId, deletionReason: deletionReason);

      return {
        'success': true,
        'userName': userData['fullName'] ?? 'User',
      };
    } catch (e) {
      print('Error deleting user: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<void> deleteUser(String userId, {String? deletionReason}) async {
    await _usersRef.doc(userId).update({
      'status': 'Deleted',
      'isActive': false,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletionReason': deletionReason,
    });
  }

  // Notification methods
  Future<void> _sendWarningNotification({
    required String userId,
    required String violationReason,
    required int strikeCount,
    required String userName,
    required String userEmail,
  }) async {
    try {
      await _notificationsRef.add({
        'body': 'You have received a warning for violating community guidelines. Reason: $violationReason. This is strike $strikeCount/3. After 3 strikes, your account will be suspended.',
        'category': 'account_warning',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'metadata': {
          'violationReason': violationReason,
          'strikeCount': strikeCount,
          'userName': userName,
          'userEmail': userEmail,
          'actionType': 'warning',
        },
        'title': 'Account Warning',
        'userId': userId,
      });
    } catch (e) {
      print('Error sending warning notification: $e');
    }
  }

  Future<void> _sendSuspensionNotification({
    required String userId,
    required String violationReason,
    required int durationDays,
    required String userName,
    required String userEmail,
  }) async {
    try {
      await _notificationsRef.add({
        'body': 'Your account has been suspended for $durationDays days due to reaching 3 strikes for violating community guidelines. Final violation: $violationReason',
        'category': 'account_suspension',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'metadata': {
          'violationReason': violationReason,
          'suspensionDuration': durationDays,
          'userName': userName,
          'userEmail': userEmail,
          'actionType': 'suspension',
        },
        'title': 'Account Suspended - 3 Strikes',
        'userId': userId,
      });
    } catch (e) {
      print('Error sending suspension notification: $e');
    }
  }

  Future<void> _sendUnsuspensionNotification({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    try {
      await _notificationsRef.add({
        'body': 'Your account suspension has been lifted. You can now access all features normally.',
        'category': 'account_unsuspension',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'metadata': {
          'userName': userName,
          'userEmail': userEmail,
          'actionType': 'unsuspension',
        },
        'title': 'Account Access Restored',
        'userId': userId,
      });
    } catch (e) {
      print('Error sending unsuspension notification: $e');
    }
  }

  Future<void> _sendDeletionNotification({
    required String userId,
    required String userName,
    required String userEmail,
    required String deletionReason,
  }) async {
    try {
      await _notificationsRef.add({
        'body': 'Your account has been permanently deleted due to severe violations of our community guidelines. Reason: $deletionReason',
        'category': 'account_deletion',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'metadata': {
          'deletionReason': deletionReason,
          'userName': userName,
          'userEmail': userEmail,
          'actionType': 'deletion',
        },
        'title': 'Account Deletion Notice',
        'userId': userId,
      });
    } catch (e) {
      print('Error sending deletion notification: $e');
    }
  }
}