
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project/models/admin/user_model.dart';
import 'package:fyp_project/models/admin/admin_model.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:fyp_project/services/user/notification_service.dart';

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

  Future<List<String>> getAllRoles() async {
    final snapshot = await _usersRef.get();
    final roles = snapshot.docs
        .map((doc) => doc.data()['role'] as String? ?? 'unknown')
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList();

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

  Future<List<UserModel>> getPendingVerificationUsers() async {
    final snap = await _usersRef
        .where('verificationStatus', isEqualTo: 'pending')
        .get();
    final users = _mapUsers(snap);
    users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return users;
  }

  Future<Map<String, dynamic>?> getVerificationRequest(String userId) async {
    try {
      final verificationDoc = await FirebaseFirestore.instance
          .collection('verificationRequests')
          .doc(userId)
          .get();
      
      if (!verificationDoc.exists) return null;
      
      return verificationDoc.data();
    } catch (e) {
      print('Error getting verification request: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> approveUserVerification(String userId) async {
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('User not found');
      }

      final userName = userData['fullName'] ?? 'User';
      
      await FirebaseFirestore.instance
          .collection('verificationRequests')
          .doc(userId)
          .update({
        'status': 'approved',
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': currentAdminId,
      });
      
      await _usersRef.doc(userId).update({
        'verificationStatus': 'approved',
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': currentAdminId,
      });

      try {
        await _logsRef.add({
          'actionType': 'user_verification_approved',
          'userId': userId,
          'userName': userName,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentAdminId,
        });
      } catch (logError) {
        print('Error creating verification approval log entry: $logError');
      }

      try {
        final notificationService = NotificationService();
        await notificationService.notifyVerificationApproved(userId: userId);
      } catch (notifError) {
        print('Error sending verification approval notification: $notifError');
      }

      return {
        'success': true,
        'userName': userName,
      };
    } catch (e) {
      print('Error approving user verification: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> rejectUserVerification(
    String userId, {
    String? rejectionReason,
  }) async {
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('User not found');
      }

      final userName = userData['fullName'] ?? 'User';
      
      await FirebaseFirestore.instance
          .collection('verificationRequests')
          .doc(userId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': currentAdminId,
        'rejectionReason': rejectionReason,
      });
      
      await _usersRef.doc(userId).update({
        'verificationStatus': 'rejected',
        'isVerified': false,
        'verificationRejectedAt': FieldValue.serverTimestamp(),
        'verificationRejectedBy': currentAdminId,
        'verificationRejectionReason': rejectionReason,
      });

      try {
        await _logsRef.add({
          'actionType': 'user_verification_rejected',
          'userId': userId,
          'userName': userName,
          'rejectionReason': rejectionReason,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentAdminId,
        });
      } catch (logError) {
        print('Error creating verification rejection log entry: $logError');
      }

      try {
        final notificationService = NotificationService();
        await notificationService.notifyVerificationRejected(
          userId: userId,
          rejectionReason: rejectionReason,
        );
      } catch (notifError) {
        print('Error sending verification rejection notification: $notifError');
      }

      return {
        'success': true,
        'userName': userName,
      };
    } catch (e) {
      print('Error rejecting user verification: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<List<UserModel>> getReportedUsers() async {
    final snap = await _usersRef.where('reportCount', isGreaterThan: 0).get();
    final users = _mapUsers(snap);
    users.sort((a, b) => b.reportCount.compareTo(a.reportCount));
    return users;
  }

  Future<int> getStrikeCount(String userId) async {
    try {
      final userDoc = await _usersRef.doc(userId).get();
      return userDoc.data()?['strikeCount'] ?? 0;
    } catch (e) {
      print('Error getting strike count: $e');
      return 0;
    }
  }

  Future<double> getWalletBalance(String userId) async {
    try {
      print('Fetching wallet balance for userId: $userId');
      
      var walletDoc = await _walletsRef.doc(userId).get();
      print('Wallet document exists (by doc ID): ${walletDoc.exists}');
      
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
    bool skipLogging = false, 
  }) async {
    try {
      
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      final userName = userData?['fullName'] ?? 'Unknown User';
      
      final walletDoc = await _walletsRef.doc(userId).get();
      double currentBalance = 0.0;
      double currentHeldCredits = 0.0;
      
      if (walletDoc.exists) {
        final data = walletDoc.data();
        currentBalance = (data?['balance'] as num?)?.toDouble() ?? 0.0;
        currentHeldCredits = (data?['heldCredits'] as num?)?.toDouble() ?? 0.0;
      } else {
        
        await _walletsRef.doc(userId).set({
          'userId': userId,
          'balance': 0.0,
          'heldCredits': 0.0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        currentBalance = 0.0;
        currentHeldCredits = 0.0;
      }

      final availableBalance = currentBalance - currentHeldCredits;
      final amountInt = amount.toInt();
      
      if (amountInt > availableBalance) {
        return {
          'success': false,
          'error': 'Cannot deduct ${amountInt} credits. Available balance is only ${availableBalance.toInt()} credits (Total: ${currentBalance.toInt()}, Held: ${currentHeldCredits.toInt()})',
        };
      }
      
      final walletRef = _walletsRef.doc(userId);
      final transactionsRef = walletRef.collection('transactions');
      final txnRef = transactionsRef.doc();
      
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(walletRef);
        final data = snap.data() ?? <String, dynamic>{'balance': 0, 'heldCredits': 0};
        final int current = (data['balance'] as num?)?.toInt() ?? 0;
        final int next = current - amountInt;
        
        tx.update(walletRef, {
          'balance': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
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

      final finalWalletDoc = await walletRef.get();
      final finalData = finalWalletDoc.data();
      final finalBalance = (finalData?['balance'] as num?)?.toDouble() ?? 0.0;

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
          
          if (reportId != null && reportId.isNotEmpty) {
            logData['reportId'] = reportId;
          }
          
          await _logsRef.add(logData);
        } catch (logError) {
          print('Error creating log entry: $logError');
          
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

  Future<Map<String, dynamic>> issueWarning({
    required String userId,
    required String violationReason,
    double? deductMarksAmount,
    String? reportId,
  }) async {
    try {
      
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('User not found');
      }

      final currentStrikes = await getStrikeCount(userId);
      final newStrikes = currentStrikes + 1;

      await _usersRef.doc(userId).update({
        'strikeCount': newStrikes,
        'lastStrikeReason': violationReason,
        'lastStrikeAt': FieldValue.serverTimestamp(),
      });

      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;

      Map<String, dynamic>? deductionResult;
      if (deductMarksAmount != null && deductMarksAmount > 0) {
        deductionResult = await deductCredit(
          userId: userId,
          amount: deductMarksAmount,
          reason: 'Warning issued: $violationReason',
          skipLogging: true, 
          reportId: reportId,
        );
      }

      try {
        await _logsRef.add({
          'actionType': 'warning_issued',
          'userId': userId,
          'userName': userData['fullName'] ?? 'User',
          'violationReason': violationReason,
          'description': violationReason, 
          'strikeCount': newStrikes,
          'wasSuspended': false, 
          'deductedMarks': deductMarksAmount,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentAdminId,
        });
      } catch (logError) {
        print('Error creating warning log entry: $logError');
        
      }

      await _sendWarningNotification(
        userId: userId,
        violationReason: violationReason,
        strikeCount: newStrikes,
        userName: userData['fullName'] ?? 'User',
        userEmail: userData['email'] ?? '',
      );

      bool wasSuspended = false;
      if (newStrikes >= 3) {
        await suspendUser(
          userId,
          violationReason: 'Automatic suspension: Reached 3 strikes. Final violation: $violationReason',
          durationDays: 7,
        );
        wasSuspended = true;

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

      await unsuspendUser(userId);

      await resetStrikes(userId);

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
        
      }

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

  Future<Map<String, dynamic>> checkAndAutoUnsuspendExpiredUsers() async {
    try {
      final now = DateTime.now();
      int unsuspendedCount = 0;
      List<String> unsuspendedUserNames = [];

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

        if (suspendedAt == null || suspensionDuration == null) {
          print('Auto unsuspend check: Skipping user $userId - missing suspendedAt or suspensionDuration');
          continue;
        }

        final expirationDate = suspendedAt.toDate().add(Duration(days: suspensionDuration));
        
        print('Auto unsuspend check: User $userName - suspendedAt: ${suspendedAt.toDate()}, duration: $suspensionDuration days, expires: $expirationDate, now: $now');

        if (!now.isBefore(expirationDate)) {
          print('Auto unsuspend check: Unsuspending user $userName - expiration time reached');

          await unsuspendUser(userId);

          try {
            await _sendUnsuspensionNotification(
              userId: userId,
              userName: userName,
              userEmail: userEmail,
            );
          } catch (notifError) {
            print('Error sending auto unsuspend notification: $notifError');
            
          }

          try {
            await _logsRef.add({
              'actionType': 'user_unsuspended',
              'userId': userId,
              'userName': userName,
              'previousStatus': 'Suspended',
              'newStatus': 'Active',
              'reason': 'Automatic unsuspension: Suspension period expired',
              'createdAt': FieldValue.serverTimestamp(),
              'createdBy': 'system', 
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
      
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('User not found');
      }

      final userName = userData['fullName'] ?? 'User';
      final userEmail = userData['email'] ?? '';
      final previousStatus = userData['status'] ?? 'unknown';
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;

      await _sendDeletionNotification(
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        deletionReason: deletionReason,
      );

      await deleteUser(userId, deletionReason: deletionReason);

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
      
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('User not found');
      }

      final userName = userData['fullName'] ?? 'User';
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;

      await _usersRef.doc(userId).update({
        'status': 'Active',
        'isActive': true,
        'deletedAt': null,
        'deletionReason': null,
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': currentAdminId,
      });

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

  Future<Map<String, dynamic>> updateUserInfo({
    required String userId,
    String? fullName,
    String? phoneNumber,
    String? location,
    String? professionalSummary,
    String? professionalProfile,
    String? workExperience,
    String? seeking,
    int? age,
    String? gender,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? image,
    Map<String, dynamic>? resume,
  }) async {
    try {
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      
      final userDoc = await _usersRef.doc(userId).get();
      final userData = userDoc.data();
      if (userData == null) {
        throw Exception('User not found');
      }

      final userName = userData['fullName'] ?? 'User';
      
      Map<String, dynamic> updateData = {};
      if (fullName != null) updateData['fullName'] = fullName;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (location != null) updateData['location'] = location;
      if (professionalSummary != null) updateData['professionalSummary'] = professionalSummary;
      if (professionalProfile != null) updateData['professionalProfile'] = professionalProfile;
      if (workExperience != null) updateData['workExperience'] = workExperience;
      if (seeking != null) updateData['seeking'] = seeking;
      if (age != null) updateData['age'] = age;
      if (gender != null) updateData['gender'] = gender;
      if (latitude != null) updateData['latitude'] = latitude;
      if (longitude != null) updateData['longitude'] = longitude;
      if (image != null) updateData['image'] = image;
      if (resume != null) updateData['resume'] = resume;
      
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      updateData['lastUpdatedBy'] = currentAdminId;

      await _usersRef.doc(userId).update(updateData);

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

  static String getRoleDisplayName(String role) {
    return role.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  bool canAddAdmin(AdminModel? currentAdmin) {
    if (currentAdmin == null) return false;
    final currentRole = currentAdmin.role.toLowerCase();
    return currentRole == 'manager' || currentRole == 'hr';
  }

  bool isHR(AdminModel? currentAdmin) {
    if (currentAdmin == null) return false;
    return currentAdmin.role.toLowerCase() == 'hr';
  }

  bool isStaff(AdminModel? currentAdmin) {
    if (currentAdmin == null) return false;
    return currentAdmin.role.toLowerCase() == 'staff';
  }

  bool canPerformActionsOnUser(AdminModel? currentAdmin, UserModel user) {
    
    if (currentAdmin != null && currentAdmin.id == user.id) {
      return false;
    }
    
    final userRole = user.role.toLowerCase();
    
    if (isHR(currentAdmin)) {
      if (userRole == 'manager') {
        return false;
      }
    }
    
    if (isStaff(currentAdmin)) {
      
      if (userRole == 'jobseeker' || userRole == 'recruiter') {
        return true;
      }
      
      return false;
    }
    
    return true;
  }
}