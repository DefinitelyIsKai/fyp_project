// services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project/models/admin/user_model.dart';
import 'package:fyp_project/models/admin/admin_model.dart';
import 'package:fyp_project/services/admin/auth_service.dart';

class UserService {
  UserService()
      : _usersRef = FirebaseFirestore.instance.collection('users'),
        _notificationsRef = FirebaseFirestore.instance.collection('notifications'),
        _walletsRef = FirebaseFirestore.instance.collection('wallets'),
        _logsRef = FirebaseFirestore.instance.collection('logs');

  final CollectionReference<Map<String, dynamic>> _usersRef;
  final CollectionReference<Map<String, dynamic>> _notificationsRef;
  final CollectionReference<Map<String, dynamic>> _walletsRef;
  final CollectionReference<Map<String, dynamic>> _logsRef;

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

  // Wallet methods
  Future<double> getWalletBalance(String userId) async {
    try {
      print('Fetching wallet balance for userId: $userId');
      
      // First, try to get by document ID (userId)
      var walletDoc = await _walletsRef.doc(userId).get();
      print('Wallet document exists (by doc ID): ${walletDoc.exists}');
      
      // If not found by document ID, try querying by userId field
      if (!walletDoc.exists) {
        print('Document not found by ID, querying by userId field...');
        final querySnapshot = await _walletsRef.where('userId', isEqualTo: userId).limit(1).get();
        if (querySnapshot.docs.isNotEmpty) {
          walletDoc = querySnapshot.docs.first;
          print('Found wallet document by userId field query');
        }
      }
      
      if (walletDoc.exists) {
        final data = walletDoc.data();
        print('Wallet data: $data');
        
        // Handle both int and double types for balance
        final balanceValue = data?['balance'];
        print('Balance value (raw): $balanceValue, type: ${balanceValue.runtimeType}');
        
        double balance = 0.0;
        if (balanceValue != null) {
          if (balanceValue is num) {
            balance = balanceValue.toDouble();
          } else if (balanceValue is String) {
            balance = double.tryParse(balanceValue) ?? 0.0;
          }
        }
        
        print('Parsed balance: $balance');
        return balance;
      }
      
      print('Wallet document does not exist for userId: $userId');
      // If wallet doesn't exist, create it with 0 balance and return 0.0
      await _walletsRef.doc(userId).set({
        'userId': userId,
        'balance': 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return 0.0;
    } catch (e, stackTrace) {
      print('Error getting wallet balance: $e');
      print('Stack trace: $stackTrace');
      return 0.0;
    }
  }

  Future<Map<String, dynamic>> deductCredit({
    required String userId,
    required double amount,
    required String reason,
    String? actionType,
    String? reportId,
    bool skipLogging = false, // Skip creating log entry (used when called from issueWarning)
  }) async {
    try {
      // Get current admin user ID for logging
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      
      // Get user info for logging
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      final userName = userData?['fullName'] ?? 'Unknown User';
      
      // Ensure wallet exists first
      final walletDoc = await _walletsRef.doc(userId).get();
      double currentBalance = 0.0;
      double currentHeldCredits = 0.0;
      
      if (walletDoc.exists) {
        final data = walletDoc.data();
        currentBalance = (data?['balance'] as num?)?.toDouble() ?? 0.0;
        currentHeldCredits = (data?['heldCredits'] as num?)?.toDouble() ?? 0.0;
      } else {
        // Create wallet with 0 balance if it doesn't exist
        await _walletsRef.doc(userId).set({
          'userId': userId,
          'balance': 0.0,
          'heldCredits': 0.0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        currentBalance = 0.0;
        currentHeldCredits = 0.0;
      }

      // Calculate available balance (balance - heldCredits)
      final availableBalance = currentBalance - currentHeldCredits;
      final amountInt = amount.toInt();
      
      // Validate that deduction doesn't exceed available balance
      if (amountInt > availableBalance) {
        return {
          'success': false,
          'error': 'Cannot deduct ${amountInt} credits. Available balance is only ${availableBalance.toInt()} credits (Total: ${currentBalance.toInt()}, Held: ${currentHeldCredits.toInt()})',
        };
      }
      
      final walletRef = _walletsRef.doc(userId);
      final transactionsRef = walletRef.collection('transactions');
      final txnRef = transactionsRef.doc();
      
      // Use Firestore transaction to atomically update balance and create transaction record
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(walletRef);
        final data = snap.data() ?? <String, dynamic>{'balance': 0, 'heldCredits': 0};
        final int current = (data['balance'] as num?)?.toInt() ?? 0;
        final int next = current - amountInt;
        
        // Update wallet balance
        tx.update(walletRef, {
          'balance': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Create transaction record in subcollection
        tx.set(txnRef, {
          'id': txnRef.id,
          'userId': userId,
          'type': 'debit',
          'amount': amountInt,
          'description': reason,
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': null,
        });
      });

      // Get final balance after transaction
      final finalWalletDoc = await walletRef.get();
      final finalData = finalWalletDoc.data();
      final finalBalance = (finalData?['balance'] as num?)?.toDouble() ?? 0.0;

      // Create log entry only if not skipping (skip when called from issueWarning)
      if (!skipLogging) {
        try {
          final logData = <String, dynamic>{
            'actionType': actionType ?? 'deduct_credit',
            'userId': userId,
            'userName': userName,
            'amount': amount,
            'previousBalance': currentBalance,
            'newBalance': finalBalance,
            'reason': reason,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': currentAdminId,
          };
          
          // Add report ID if provided
          if (reportId != null && reportId.isNotEmpty) {
            logData['reportId'] = reportId;
          }
          
          await _logsRef.add(logData);
        } catch (logError) {
          print('Error creating log entry: $logError');
          // Don't fail the operation if logging fails
        }
      }

      return {
        'success': true,
        'amountDeducted': amount,
        'previousBalance': currentBalance,
        'newBalance': finalBalance,
      };
    } catch (e) {
      print('Error deducting credit: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Complete warning system with notifications
  Future<Map<String, dynamic>> issueWarning({
    required String userId,
    required String violationReason,
    double? deductMarksAmount,
    String? reportId,
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

      // Get current admin user ID for logging
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;

      // Deduct marks if specified (skip logging - will be included in warning log)
      Map<String, dynamic>? deductionResult;
      if (deductMarksAmount != null && deductMarksAmount > 0) {
        deductionResult = await deductCredit(
          userId: userId,
          amount: deductMarksAmount,
          reason: 'Warning issued: $violationReason',
          skipLogging: true, // Skip creating separate log - warning log will include deduction info
          reportId: reportId,
        );
      }

      // Create log entry for warning
      try {
        await _logsRef.add({
          'actionType': 'warning_issued',
          'userId': userId,
          'userName': userData['fullName'] ?? 'User',
          'violationReason': violationReason,
          'description': violationReason, // Save violation reason as description field
          'strikeCount': newStrikes,
          'wasSuspended': false, // Will be updated if suspended
          'deductedMarks': deductMarksAmount,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentAdminId,
        });
      } catch (logError) {
        print('Error creating warning log entry: $logError');
        // Don't fail the operation if logging fails
      }

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

        // Update log entry to reflect suspension
        try {
          final logsQuery = await _logsRef
              .where('actionType', isEqualTo: 'warning_issued')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();
          
          if (logsQuery.docs.isNotEmpty) {
            await logsQuery.docs.first.reference.update({
              'wasSuspended': true,
              'suspensionReason': 'Automatic suspension: Reached 3 strikes',
            });
          }
        } catch (logError) {
          print('Error updating warning log entry: $logError');
        }

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
        'deductionResult': deductionResult,
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

      final userName = userData['fullName'] ?? 'User';
      final userEmail = userData['email'] ?? '';
      final previousStatus = userData['status'] ?? 'unknown';
      final previousStrikeCount = userData['strikeCount'] ?? 0;
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;

      // Unsuspend user
      await unsuspendUser(userId);

      // Reset strikes
      await resetStrikes(userId);

      // Create log entry
      try {
        await _logsRef.add({
          'actionType': 'user_unsuspended',
          'userId': userId,
          'userName': userName,
          'userEmail': userEmail,
          'previousStatus': previousStatus,
          'newStatus': 'Active',
          'previousStrikeCount': previousStrikeCount,
          'newStrikeCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentAdminId,
        });
      } catch (logError) {
        print('Error creating unsuspend log entry: $logError');
        // Don't fail the operation if logging fails
      }

      // Send unsuspension notification
      await _sendUnsuspensionNotification(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
      );

      return {
        'success': true,
        'userName': userName,
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
    // Get user data for logging
    final userDoc = await _usersRef.doc(userId).get();
    final userData = userDoc.data();
    final userName = userData?['fullName'] ?? 'User';
    final userEmail = userData?['email'] ?? '';
    final previousStatus = userData?['status'] ?? 'unknown';
    final currentAdminId = FirebaseAuth.instance.currentUser?.uid;

    await _usersRef.doc(userId).update({
      'status': 'Suspended',
      'isActive': false,
      'suspendedAt': FieldValue.serverTimestamp(),
      'suspensionReason': violationReason,
      'suspensionDuration': durationDays,
    });

    // Create log entry
    try {
      await _logsRef.add({
        'actionType': 'user_suspended',
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'previousStatus': previousStatus,
        'newStatus': 'Suspended',
        'reason': violationReason,
        'durationDays': durationDays,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentAdminId,
      });
    } catch (logError) {
      print('Error creating suspend log entry: $logError');
      // Don't fail the operation if logging fails
    }
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

  /// Check and automatically unsuspend users whose suspension period has expired
  Future<Map<String, dynamic>> checkAndAutoUnsuspendExpiredUsers() async {
    try {
      final now = DateTime.now();
      int unsuspendedCount = 0;
      List<String> unsuspendedUserNames = [];

      // Get all suspended users
      final suspendedUsersQuery = await _usersRef
          .where('status', isEqualTo: 'Suspended')
          .where('isActive', isEqualTo: false)
          .get();

        print('Auto unsuspend check: Found ${suspendedUsersQuery.docs.length} suspended users');

      for (var doc in suspendedUsersQuery.docs) {
        final userData = doc.data();
        final suspendedAt = userData['suspendedAt'] as Timestamp?;
        final suspensionDuration = userData['suspensionDuration'] as int?;
        final userId = doc.id;
        final userName = userData['fullName'] ?? 'User';
        final userEmail = userData['email'] ?? '';

        // Skip if no suspension date or if indefinite suspension (duration is null)
        if (suspendedAt == null || suspensionDuration == null) {
          print('Auto unsuspend check: Skipping user $userId - missing suspendedAt or suspensionDuration');
          continue;
        }

        // Calculate expiration date
        final expirationDate = suspendedAt.toDate().add(Duration(days: suspensionDuration));
        
        print('Auto unsuspend check: User $userName - suspendedAt: ${suspendedAt.toDate()}, duration: $suspensionDuration days, expires: $expirationDate, now: $now');

        // Check if suspension has expired (using !isBefore to handle exact expiration time)
        if (!now.isBefore(expirationDate)) {
          print('Auto unsuspend check: Unsuspending user $userName - expiration time reached');

          // Auto unsuspend the user
          await unsuspendUser(userId);

          // Send unsuspension notification
          try {
            await _sendUnsuspensionNotification(
              userId: userId,
              userName: userName,
              userEmail: userEmail,
            );
          } catch (notifError) {
            print('Error sending auto unsuspend notification: $notifError');
            // Don't fail the operation if notification fails
          }

          // Create log entry for auto unsuspension
          try {
            await _logsRef.add({
              'actionType': 'user_unsuspended',
              'userId': userId,
              'userName': userName,
              'previousStatus': 'Suspended',
              'newStatus': 'Active',
              'reason': 'Automatic unsuspension: Suspension period expired',
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': 'system', // System action
            });
          } catch (logError) {
            print('Error creating auto unsuspend log entry: $logError');
          }

          unsuspendedCount++;
          unsuspendedUserNames.add(userName);
        } else {
          final hoursRemaining = expirationDate.difference(now).inHours;
          print('Auto unsuspend check: User $userName - suspension not yet expired (expires in $hoursRemaining hours)');
        }
      }

      print('Auto unsuspend check: Completed - unsuspended $unsuspendedCount user(s)');
      return {
        'success': true,
        'unsuspendedCount': unsuspendedCount,
        'unsuspendedUserNames': unsuspendedUserNames,
      };
    } catch (e) {
      print('Error checking and auto unsuspending expired users: $e');
      return {
        'success': false,
        'error': e.toString(),
        'unsuspendedCount': 0,
        'unsuspendedUserNames': [],
      };
    }
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

      final userName = userData['fullName'] ?? 'User';
      final userEmail = userData['email'] ?? '';
      final previousStatus = userData['status'] ?? 'unknown';
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;

      // Send deletion notification
      await _sendDeletionNotification(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        deletionReason: deletionReason,
      );

      // Delete the user
      await deleteUser(userId, deletionReason: deletionReason);

      // Create log entry
      try {
        await _logsRef.add({
          'actionType': 'user_deleted',
          'userId': userId,
          'userName': userName,
          'userEmail': userEmail,
          'previousStatus': previousStatus,
          'newStatus': 'Inactive',
          'reason': deletionReason,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentAdminId,
        });
      } catch (logError) {
        print('Error creating delete log entry: $logError');
        // Don't fail the operation if logging fails
      }

      return {
        'success': true,
        'userName': userName,
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
      'status': 'Inactive',
      'isActive': false,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletionReason': deletionReason,
    });
  }

  Future<Map<String, dynamic>> reactivateUser(String userId) async {
    try {
      // Get user data first
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('User not found');
      }

      final userName = userData['fullName'] ?? 'User';
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;

      // Reactivate the user
      await _usersRef.doc(userId).update({
        'status': 'Active',
        'isActive': true,
        'deletedAt': null,
        'deletionReason': null,
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': currentAdminId,
      });

      // Create log entry
      try {
        await _logsRef.add({
          'actionType': 'user_reactivated',
          'userId': userId,
          'userName': userName,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentAdminId,
        });
      } catch (logError) {
        print('Error creating reactivation log entry: $logError');
        // Don't fail the operation if logging fails
      }

      return {
        'success': true,
        'userName': userName,
      };
    } catch (e) {
      print('Error reactivating user: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
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

  /// Update user information (excluding email and role)
  Future<Map<String, dynamic>> updateUserInfo({
    required String userId,
    String? fullName,
    String? phoneNumber,
    String? location,
    String? professionalSummary,
    String? professionalProfile,
    String? workExperience,
    String? seeking,
  }) async {
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      
      // Get user data for logging
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('User not found');
      }

      final userName = userData['fullName'] ?? 'User';
      
      // Build update map with only provided fields
      Map<String, dynamic> updateData = {};
      if (fullName != null) updateData['fullName'] = fullName;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (location != null) updateData['location'] = location;
      if (professionalSummary != null) updateData['professionalSummary'] = professionalSummary;
      if (professionalProfile != null) updateData['professionalProfile'] = professionalProfile;
      if (workExperience != null) updateData['workExperience'] = workExperience;
      if (seeking != null) updateData['seeking'] = seeking;
      
      // Add updated timestamp
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      updateData['lastUpdatedBy'] = currentAdminId;

      // Update user document
      await _usersRef.doc(userId).update(updateData);

      // Create log entry
      try {
        await _logsRef.add({
          'actionType': 'user_info_updated',
          'userId': userId,
          'userName': userName,
          'updatedFields': updateData.keys.toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentAdminId,
        });
      } catch (logError) {
        print('Error creating update log entry: $logError');
        // Don't fail the operation if logging fails
      }

      return {
        'success': true,
        'userName': userName,
      };
    } catch (e) {
      print('Error updating user info: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create a new admin user
  /// This method delegates to AuthService.register to handle the actual user creation
  Future<RegisterResult> createAdminUser({
    required AuthService authService,
    required String name,
    required String email,
    required String password,
    required String role,
    String? location,
    int? age,
    String? phoneNumber,
    String? imageBase64,
    String? imageFileType,
    String? originalUserPassword,
  }) async {
    return await authService.register(
      name,
      email,
      password,
      role: role,
      originalUserPassword: originalUserPassword,
      location: location?.isEmpty == true ? null : location,
      age: age,
      phoneNumber: phoneNumber?.isEmpty == true ? null : phoneNumber,
      imageBase64: imageBase64,
      imageFileType: imageFileType,
    );
  }

  /// Get display name for a role (converts snake_case to Title Case)
  static String getRoleDisplayName(String role) {
    return role.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Format date as "Jan 1, 2024"
  static String formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Check if current admin can add new admin users
  bool canAddAdmin(AdminModel? currentAdmin) {
    if (currentAdmin == null) return false;
    final currentRole = currentAdmin.role.toLowerCase();
    return currentRole == 'manager' || currentRole == 'hr';
  }

  /// Check if current admin is HR
  bool isHR(AdminModel? currentAdmin) {
    if (currentAdmin == null) return false;
    return currentAdmin.role.toLowerCase() == 'hr';
  }

  /// Check if current admin is Staff
  bool isStaff(AdminModel? currentAdmin) {
    if (currentAdmin == null) return false;
    return currentAdmin.role.toLowerCase() == 'staff';
  }

  /// Check if current admin can perform actions on a user
  bool canPerformActionsOnUser(AdminModel? currentAdmin, UserModel user) {
    // Cannot perform actions on yourself (view only)
    if (currentAdmin != null && currentAdmin.id == user.id) {
      return false;
    }
    
    final userRole = user.role.toLowerCase();
    
    // If current user is HR and target user is Manager, cannot perform actions (only view)
    if (isHR(currentAdmin)) {
      if (userRole == 'manager') {
        return false;
      }
    }
    
    // If current user is Staff, can only perform actions on Jobseeker and Recruiter
    // Other roles (Manager, HR, Staff, etc.) are view only
    if (isStaff(currentAdmin)) {
      // Only allow actions on Jobseeker and Recruiter
      if (userRole == 'jobseeker' || userRole == 'recruiter') {
        return true;
      }
      // All other roles are view only
      return false;
    }
    
    // Manager can perform actions on all users (except themselves)
    return true;
  }
}