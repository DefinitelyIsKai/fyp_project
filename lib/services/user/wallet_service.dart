import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../models/user/wallet.dart';
import '../../utils/user/timestamp_utils.dart';
import 'notification_service.dart';

class WalletService {
  WalletService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? httpClient,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _http = httpClient ?? http.Client(),
       _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final http.Client _http;
  final NotificationService _notificationService;

  static const String _topUpEndpoint = String.fromEnvironment(
    'TOPUP_ENDPOINT',
    defaultValue:
        'https://stripe-topup-worker.lowbryan022.workers.dev/createTopUpSession',
  );
  static const String _topUpVerifyEndpoint = String.fromEnvironment(
    'TOPUP_VERIFY_ENDPOINT',
    defaultValue: '',
  );

  String _getTopUpEndpoint() {
    final endpoint = _normalizeEndpoint(_topUpEndpoint);
    if (endpoint.isEmpty) {
      throw StateError('TOPUP_ENDPOINT not configured');
    }
    return endpoint;
  }

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user');
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _walletDoc =>
      _firestore.collection('wallets').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _txnCol =>
      _walletDoc.collection('transactions');

  Stream<Wallet> streamWallet() {
    return _walletDoc.snapshots().map(
      (snap) => Wallet.fromMap(snap.data(), uid: _uid),
    );
  }

  Stream<List<WalletTransaction>> streamTransactions({int limit = 50}) {
    return _txnCol
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => WalletTransaction.fromMap(<String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                }),
              )
              .toList(),
        );
  }

  Future<List<WalletTransaction>> loadInitialTransactions({int limit = 20}) async {
    try {
      final snapshot = await _txnCol
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map(
            (d) => WalletTransaction.fromMap(<String, dynamic>{
              ...d.data(),
              'id': d.id,
            }),
          )
          .toList();
    } catch (e) {
      print('Error loading initial transactions: $e');
      return [];
    }
  }

  Future<List<WalletTransaction>> loadMoreTransactions({
    required DateTime lastTransactionTime,
    String? lastTransactionId,
    int limit = 20,
  }) async {
    try {
      final Timestamp timestampCursor = Timestamp.fromDate(lastTransactionTime);

      if (lastTransactionId != null) {
        try {
          final snapshot = await _txnCol
              .orderBy('createdAt', descending: true)
              .orderBy(FieldPath.documentId, descending: true)
              .startAfter([timestampCursor, lastTransactionId])
              .limit(limit)
              .get();

          return snapshot.docs
              .map(
                (d) => WalletTransaction.fromMap(<String, dynamic>{
                  ...d.data(),
                  'id': d.id,
                }),
              )
              .toList();
        } catch (e) {
          print('Composite index may be missing, using simple pagination: $e');
        }
      }

      final snapshot = await _txnCol
          .orderBy('createdAt', descending: true)
          .startAfter([timestampCursor])
          .limit(limit)
          .get();

      return snapshot.docs
          .map(
            (d) => WalletTransaction.fromMap(<String, dynamic>{
              ...d.data(),
              'id': d.id,
            }),
          )
          .toList();
    } catch (e) {
      print('Error loading more transactions: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> loadInitialCancelledPayments({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('pending_payments')
          .where('uid', isEqualTo: _uid)
          .where('status', isEqualTo: 'cancelled')
          .get();

      final payments = snapshot.docs
          .map(
            (d) => <String, dynamic>{
              ...d.data(),
              'id': d.id,
            },
          )
          .toList();

      // Sort by createdAt manually
      payments.sort((a, b) {
        final aTime = TimestampUtils.parseTimestamp(a['createdAt']);
        final bTime = TimestampUtils.parseTimestamp(b['createdAt']);
        return bTime.compareTo(aTime); // descending
      });

      // Return limited results
      if (payments.length > limit) {
        return payments.sublist(0, limit);
      }
      return payments;
    } catch (e) {
      print('Error loading initial cancelled payments: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> streamPendingPayments() {
    return _firestore
        .collection('pending_payments')
        .where('uid', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) {
            print('Pending payments snapshot: ${snap.docs.length} documents');
            final payments = snap.docs
                .map(
                  (d) {
                    final data = d.data();
                    print('Pending payment data: $data');
                    return <String, dynamic>{
                      ...data,
                      'id': d.id,
                    };
                  },
                )
                .toList();
            
            // Sort by createdAt manually to avoid requiring composite index
            payments.sort((a, b) {
              final aTime = TimestampUtils.parseTimestamp(a['createdAt']);
              final bTime = TimestampUtils.parseTimestamp(b['createdAt']);
              return bTime.compareTo(aTime); // descending
            });
            
            print('Returning ${payments.length} pending payments');
            return payments;
          },
        );
  }


  Stream<List<Map<String, dynamic>>> streamCancelledPayments() {
    return _firestore
        .collection('pending_payments')
        .where('uid', isEqualTo: _uid)
        .where('status', isEqualTo: 'cancelled')
        .snapshots()
        .map(
          (snap) {
            final payments = snap.docs
                .map(
                  (d) => <String, dynamic>{
                    ...d.data(),
                    'id': d.id,
                  },
                )
                .toList();
            
            // Sort by createdAt manually
            payments.sort((a, b) {
              final aTime = TimestampUtils.parseTimestamp(a['createdAt']);
              final bTime = TimestampUtils.parseTimestamp(b['createdAt']);
              return bTime.compareTo(aTime); // descending
            });
            
            return payments;
          },
        );
  }

  Future<bool> hasPendingPayments() async {
    final pendingPayments = await _firestore
        .collection('pending_payments')
        .where('uid', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    return pendingPayments.docs.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getPendingPayments() async {
    try {
      final pendingPayments = await _firestore
          .collection('pending_payments')
          .where('uid', isEqualTo: _uid)
          .where('status', isEqualTo: 'pending')
          .get();
      
      print('getPendingPayments: Found ${pendingPayments.docs.length} pending payments');
      
      final payments = pendingPayments.docs
          .map(
            (d) => <String, dynamic>{
              ...d.data(),
              'id': d.id,
            },
          )
          .toList();
      
      // Sort by createdAt manually
      payments.sort((a, b) {
        final aTime = TimestampUtils.parseTimestamp(a['createdAt']);
        final bTime = TimestampUtils.parseTimestamp(b['createdAt']);
        return bTime.compareTo(aTime); // descending
      });
      
      return payments;
    } catch (e) {
      print('Error in getPendingPayments: $e');
      return [];
    }
  }

  // Cancel a pending payment
  Future<void> cancelPendingPayment(String sessionId) async {
    try {
      final paymentDoc = await _firestore
          .collection('pending_payments')
          .doc(sessionId)
          .get();

      if (!paymentDoc.exists) {
        throw StateError('Payment not found');
      }

      final data = paymentDoc.data()!;
      final uid = data['uid'] as String? ?? '';

      // Verify it's for this user
      if (uid != _uid) {
        throw StateError('Payment belongs to different user');
      }

      // Mark as cancelled instead of deleting
      await paymentDoc.reference.update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      print('Successfully cancelled pending payment: $sessionId');
    } catch (e) {
      print('Error cancelling pending payment: $e');
      rethrow;
    }
  }

  Future<void> _ensureWallet() async {
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(_walletDoc);
      if (!doc.exists) {
        tx.set(_walletDoc, {
          'userId': _uid,
          'balance': 0,
          'heldCredits': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Ensure heldCredits field exists for existing wallets
        final data = doc.data();
        if (data != null && !data.containsKey('heldCredits')) {
          tx.update(_walletDoc, {
            'heldCredits': 0,
          });
        }
      }
    });
  }

  Future<void> credit({
    required int amount,
    required String description,
    String? referenceId,
  }) async {
    if (amount <= 0) throw ArgumentError('amount must be > 0');
    await _ensureWallet();
    final txnRef = _txnCol.doc();
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_walletDoc);
      final data = snap.data() ?? <String, dynamic>{'balance': 0};
      final int current = (data['balance'] as int?) ?? 0;
      final int next = current + amount;
      tx.update(_walletDoc, {
        'balance': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(txnRef, {
        'id': txnRef.id,
        'userId': _uid,
        'type': 'credit',
        'amount': amount,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': referenceId,
      });
    });

    await _notificationService.notifyWalletCredit(
      userId: _uid,
      amount: amount,
      reason: description,
      metadata: {if (referenceId != null) 'referenceId': referenceId},
    );
  }

  Future<void> debit({
    required int amount,
    required String description,
    String? referenceId,
  }) async {
    if (amount <= 0) throw ArgumentError('amount must be > 0');
    await _ensureWallet();
    final txnRef = _txnCol.doc();
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_walletDoc);
      final data = snap.data() ?? <String, dynamic>{'balance': 0};
      final int current = (data['balance'] as int?) ?? 0;
      if (current < amount) {
        throw StateError('INSUFFICIENT_FUNDS');
      }
      final int next = current - amount;
      tx.update(_walletDoc, {
        'balance': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(txnRef, {
        'id': txnRef.id,
        'userId': _uid,
        'type': 'debit',
        'amount': amount,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': referenceId,
      });
    });

    await _notificationService.notifyWalletDebit(
      userId: _uid,
      amount: amount,
      reason: description,
      metadata: {if (referenceId != null) 'referenceId': referenceId},
    );
  }

  // Hold credits when jobseeker applies to a post (credits are held, not deducted yet)
  Future<void> holdApplicationCredits({
    required String postId,
    int feeCredits = 100,
  }) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    await _ensureWallet();
    final txnRef = _txnCol.doc();
    
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_walletDoc);
      final data = snap.data() ?? <String, dynamic>{'balance': 0, 'heldCredits': 0};
      final int balance = (data['balance'] as int?) ?? 0;
      final int heldCredits = (data['heldCredits'] as int?) ?? 0;
      final int available = balance - heldCredits;
      
      if (available < feeCredits) {
        throw StateError('INSUFFICIENT_FUNDS');
      }
      
      // Increase held credits
      tx.update(_walletDoc, {
        'heldCredits': heldCredits + feeCredits,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Create transaction record for held credits (jobseeker can create)
      tx.set(txnRef, {
        'id': txnRef.id,
        'userId': _uid,
        'type': 'debit',
        'amount': feeCredits,
        'description': 'Application fee (On Hold)',
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': postId,
      });
    });

    // Send notification about credits being held
    try {
      await _notificationService.notifyWalletDebit(
        userId: _uid,
        amount: feeCredits,
        reason: 'Application fee (On Hold)',
        metadata: {'postId': postId, 'type': 'application_fee_hold'},
      );
    } catch (e) {
      // Log but don't fail - notification is not critical
      print('Error sending wallet hold notification: $e');
    }
  }

  // Release held credits when application is rejected (no deduction, credits stay)
  // Returns true if credits were released, false if already processed or no credits held
  // This is called by jobseeker, so can create transaction
  Future<bool> releaseHeldCredits({
    required String postId,
    int feeCredits = 100,
  }) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    await _ensureWallet();
    final txnRef = _txnCol.doc();
    
    bool released = false;
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_walletDoc);
      final data = snap.data() ?? <String, dynamic>{'balance': 0, 'heldCredits': 0};
      final int heldCredits = (data['heldCredits'] as int?) ?? 0;
      
      if (heldCredits < feeCredits) {
        // Already processed or no credits held - silently return false
        return;
      }
      
      // Decrease held credits (release the hold)
      tx.update(_walletDoc, {
        'heldCredits': heldCredits - feeCredits,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Create transaction record for released credits (jobseeker can create)
      tx.set(txnRef, {
        'id': txnRef.id,
        'userId': _uid,
        'type': 'credit',
        'amount': feeCredits,
        'description': 'Application fee (Released)',
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': postId,
      });
      
      released = true;
    });
    
    return released;
  }

  // 静态方法：释放指定用户的 heldCredits（用于 Application 拒绝时）
  static Future<bool> releaseHeldCreditsForUser({
    required FirebaseFirestore firestore,
    required String userId,
    required String postId,
    int feeCredits = 100,
  }) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    if (userId.isEmpty) throw ArgumentError('userId must not be empty');
    
    final walletDoc = firestore.collection('wallets').doc(userId);
    final txnCol = walletDoc.collection('transactions');
    
    try {
      // Find the "On Hold" transaction to update it (query outside transaction)
      // Note: Firestore transactions don't support queries, only document reads
      final onHoldTransactions = await txnCol
          .where('description', isEqualTo: 'Application fee (On Hold)')
          .where('referenceId', isEqualTo: postId)
          .where('type', isEqualTo: 'debit')
          .limit(1)
          .get();
      
      await firestore.runTransaction((tx) async {
        // ========== PHASE 1: ALL READS FIRST ==========
        // Read wallet first to get current values (needed for security rule evaluation)
        final walletSnap = await tx.get(walletDoc);
        if (!walletSnap.exists) {
          throw StateError('Wallet not found for user $userId');
        }
        
        final walletData = walletSnap.data()!;
        final int currentHeldCredits = (walletData['heldCredits'] as int?) ?? 0;
        
        // Read the "On Hold" transaction document if it exists
        DocumentReference? onHoldTxnRef;
        bool shouldUpdateTransaction = false;
        
        if (onHoldTransactions.docs.isNotEmpty) {
          final onHoldTxnId = onHoldTransactions.docs.first.id;
          onHoldTxnRef = txnCol.doc(onHoldTxnId);
          
          // Read the transaction document in the transaction to verify it still exists
          // This ensures Firestore can evaluate the security rules properly
          final onHoldTxnSnap = await tx.get(onHoldTxnRef);
          
          if (onHoldTxnSnap.exists) {
            final onHoldData = onHoldTxnSnap.data() as Map<String, dynamic>?;
            // Verify it's still an On Hold transaction before updating
            if (onHoldData != null &&
                onHoldData['description'] == 'Application fee (On Hold)' &&
                onHoldData['referenceId'] == postId &&
                onHoldData['type'] == 'debit') {
              shouldUpdateTransaction = true;
              print('Found On Hold transaction to update: $onHoldTxnId');
            } else {
              print('On Hold transaction found but data mismatch: $onHoldData');
            }
          } else {
            print('On Hold transaction document does not exist in transaction');
          }
        } else {
          print('No On Hold transaction found for postId: $postId');
        }
        
        // ========== PHASE 2: ALL WRITES AFTER READS ==========
        // Calculate new heldCredits value
        final int newHeldCredits = currentHeldCredits - feeCredits;
        
        // Update wallet to release held credits
        tx.update(walletDoc, {
          'heldCredits': newHeldCredits,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Update the "On Hold" transaction to "Application fee (Released)"
        if (shouldUpdateTransaction && onHoldTxnRef != null) {
          // Update description from "Application fee (On Hold)" to "Application fee (Released)"
          // Also update type from 'debit' to 'credit' since releasing credits is a credit operation
          print('🔄 Updating transaction from "On Hold" to "Released"');
          tx.update(onHoldTxnRef, {
            'description': 'Application fee (Released)',
            'type': 'credit', // Change from debit to credit when releasing
          });
        } else {
          // If no "On Hold" transaction exists, create a new one
          // This handles edge cases where the On Hold transaction might have been deleted
          print('➕ Creating new transaction record (On Hold not found)');
          final txnRef = txnCol.doc();
          tx.set(txnRef, {
            'id': txnRef.id,
            'userId': userId,
            'type': 'credit', // Released credits should be credit type
            'amount': feeCredits,
            'description': 'Application fee (Released)',
            'createdAt': FieldValue.serverTimestamp(),
            'referenceId': postId,
          });
        }
      });
      
      print("✅ Release credits successful for user $userId");
      return true;
    } catch (e) {
      print('❌ Error releasing held credits: $e');
      return false;
    }
  }

  // 静态方法：扣除指定用户的 heldCredits 和 balance（用于 Application 批准时）
  static Future<bool> deductHeldCreditsForUser({
    required FirebaseFirestore firestore,
    required String userId,
    required String postId,
    int feeCredits = 100,
  }) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    if (userId.isEmpty) throw ArgumentError('userId must not be empty');
    
    final walletDoc = firestore.collection('wallets').doc(userId);
    final txnCol = walletDoc.collection('transactions');
    
    try {
      // Find the "On Hold" transaction to update it (query outside transaction)
      final onHoldTransactions = await txnCol
          .where('description', isEqualTo: 'Application fee (On Hold)')
          .where('referenceId', isEqualTo: postId)
          .where('type', isEqualTo: 'debit')
          .limit(1)
          .get();
      
      await firestore.runTransaction((tx) async {
        // ========== PHASE 1: ALL READS FIRST ==========
        // Read wallet first to get current values (needed for security rule evaluation)
        final walletSnap = await tx.get(walletDoc);
        if (!walletSnap.exists) {
          throw StateError('Wallet not found for user $userId');
        }
        
        final walletData = walletSnap.data()!;
        final int currentBalance = (walletData['balance'] as int?) ?? 0;
        final int currentHeldCredits = (walletData['heldCredits'] as int?) ?? 0;
        
        // Read the "On Hold" transaction document if it exists
        DocumentReference? onHoldTxnRef;
        bool shouldUpdateTransaction = false;
        
        if (onHoldTransactions.docs.isNotEmpty) {
          final onHoldTxnId = onHoldTransactions.docs.first.id;
          onHoldTxnRef = txnCol.doc(onHoldTxnId);
          
          // Read the transaction document in the transaction to verify it still exists
          // This ensures Firestore can evaluate the security rules properly
          final onHoldTxnSnap = await tx.get(onHoldTxnRef);
          
          if (onHoldTxnSnap.exists) {
            final onHoldData = onHoldTxnSnap.data() as Map<String, dynamic>?;
            // Verify it's still an On Hold transaction before updating
            if (onHoldData != null &&
                onHoldData['description'] == 'Application fee (On Hold)' &&
                onHoldData['referenceId'] == postId &&
                onHoldData['type'] == 'debit') {
              shouldUpdateTransaction = true;
              print('✅ Found On Hold transaction to update: $onHoldTxnId');
            } else {
              print('⚠️ On Hold transaction found but data mismatch: $onHoldData');
            }
          } else {
            print('⚠️ On Hold transaction document does not exist in transaction');
          }
        } else {
          print('⚠️ No On Hold transaction found for postId: $postId');
        }
        
        // ========== PHASE 2: ALL WRITES AFTER READS ==========
        // Calculate new values
        final int newBalance = currentBalance - feeCredits;
        final int newHeldCredits = currentHeldCredits - feeCredits;
        
        // 同时减少 balance 和 heldCredits（将 hold 转换为实际扣款）
        // Use explicit values so security rules can evaluate them
        tx.update(walletDoc, {
          'balance': newBalance,
          'heldCredits': newHeldCredits,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Update the "On Hold" transaction to "Application fee" (completed)
        if (shouldUpdateTransaction && onHoldTxnRef != null) {
          // Update description from "Application fee (On Hold)" to "Application fee"
          print('🔄 Updating transaction from "On Hold" to "Application fee"');
          tx.update(onHoldTxnRef, {
            'description': 'Application fee',
          });
        } else {
          // If no "On Hold" transaction exists, create a new one
          // This handles edge cases where the On Hold transaction might have been deleted
          print('➕ Creating new transaction record (On Hold not found)');
          final txnRef = txnCol.doc();
          tx.set(txnRef, {
            'id': txnRef.id,
            'userId': userId,
            'type': 'debit',
            'amount': feeCredits,
            'description': 'Application fee',
            'createdAt': FieldValue.serverTimestamp(),
            'referenceId': postId,
          });
        }
      });
      
      print("✅ Deduct successful for user $userId");
      return true;
    } catch (e) {
      print('❌ Error deducting held credits: $e');
      return false;
    }
  }

  // Deduct held credits when application is approved (actual charge)
  // This is called by jobseeker, so can create transaction
  Future<bool> deductHeldCredits({
    required String postId,
    required String userId, // 必须接收 userId
    int feeCredits = 100,
  }) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    if (userId.isEmpty) throw ArgumentError('userId must not be empty');
    
    // Only allow if userId matches current user (jobseeker can only deduct their own credits)
    if (userId != _uid) {
      throw StateError('Cannot deduct credits for other users');
    }

    final walletDoc = _firestore.collection('wallets').doc(userId);
    final txnRef = _txnCol.doc();

    try {
      await _firestore.runTransaction((tx) async {
        // Update wallet
        tx.update(walletDoc, {
          'balance': FieldValue.increment(-feeCredits),
          'heldCredits': FieldValue.increment(-feeCredits),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Create transaction record (jobseeker can create)
        tx.set(txnRef, {
          'id': txnRef.id,
          'userId': userId,
          'type': 'debit',
          'amount': feeCredits,
          'description': 'Application fee',
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': postId,
        });
      });
      
      // 通知 (可选，保持不变)
      await _notificationService.notifyWalletDebit(
        userId: userId,
        amount: feeCredits,
        reason: 'Application fee',
        metadata: {'referenceId': postId},
      );
      
      print("✅ Deduct successful for user $userId");
      return true;
    } catch (e) {
      // ⚠️ 如果还是失败，请看这里的报错信息！
      print('❌ Error deducting held credits: $e');
      return false;
    }
  }

  // Legacy method - kept for backward compatibility but now uses hold
  Future<void> chargeApplication({
    required String postId,
    int feeCredits = 100,
  }) async {
    await holdApplicationCredits(postId: postId, feeCredits: feeCredits);
  }

  // Post creation fee charged to recruiters when they create a post
  // DEPRECATED: Use holdPostCreationCredits instead for pending posts
  Future<void> chargePostCreation({
    required String postId,
    int feeCredits = 200,
  }) async {
    await debit(
      amount: feeCredits,
      description: 'Post creation fee',
      referenceId: postId,
    );
  }

  // Hold credits when recruiter creates a post (credits are held, not deducted yet)
  // Credits will be deducted when post is approved (status changes to active)
  // Credits will be released when post is rejected
  Future<void> holdPostCreationCredits({
    required String postId,
    int feeCredits = 200,
  }) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    await _ensureWallet();
    final txnRef = _txnCol.doc();
    
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_walletDoc);
      final data = snap.data() ?? <String, dynamic>{'balance': 0, 'heldCredits': 0};
      final int balance = (data['balance'] as int?) ?? 0;
      final int heldCredits = (data['heldCredits'] as int?) ?? 0;
      final int available = balance - heldCredits;
      
      if (available < feeCredits) {
        throw StateError('INSUFFICIENT_FUNDS');
      }
      
      // Increase held credits
      tx.update(_walletDoc, {
        'heldCredits': heldCredits + feeCredits,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Create transaction record for held credits
      tx.set(txnRef, {
        'id': txnRef.id,
        'userId': _uid,
        'type': 'debit',
        'amount': feeCredits,
        'description': 'Post creation fee (On Hold)',
        'createdAt': FieldValue.serverTimestamp(),
        'referenceId': postId,
      });
    });

    // Send notification about credits being held
    try {
      await _notificationService.notifyWalletDebit(
        userId: _uid,
        amount: feeCredits,
        reason: 'Post creation fee (On Hold)',
        metadata: {'postId': postId, 'type': 'post_creation_fee_hold'},
      );
    } catch (e) {
      // Log but don't fail - notification is not critical
      print('Error sending wallet hold notification: $e');
    }
  }

  // 静态方法：释放指定用户的 post creation heldCredits（用于 Post 被 rejected 时）
  static Future<bool> releasePostCreationCreditsForUser({
    required FirebaseFirestore firestore,
    required String userId,
    required String postId,
    int feeCredits = 200,
  }) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    if (userId.isEmpty) throw ArgumentError('userId must not be empty');
    
    final walletDoc = firestore.collection('wallets').doc(userId);
    final txnCol = walletDoc.collection('transactions');
    
    try {
      // Find the "On Hold" transaction to update it (query outside transaction)
      final onHoldTransactions = await txnCol
          .where('description', isEqualTo: 'Post creation fee (On Hold)')
          .where('referenceId', isEqualTo: postId)
          .where('type', isEqualTo: 'debit')
          .limit(1)
          .get();
      
      await firestore.runTransaction((tx) async {
        // ========== PHASE 1: ALL READS FIRST ==========
        final walletSnap = await tx.get(walletDoc);
        if (!walletSnap.exists) {
          throw StateError('Wallet not found for user $userId');
        }
        
        final walletData = walletSnap.data()!;
        final int currentHeldCredits = (walletData['heldCredits'] as int?) ?? 0;
        
        // Read the "On Hold" transaction document if it exists
        DocumentReference? onHoldTxnRef;
        bool shouldUpdateTransaction = false;
        
        if (onHoldTransactions.docs.isNotEmpty) {
          final onHoldTxnId = onHoldTransactions.docs.first.id;
          onHoldTxnRef = txnCol.doc(onHoldTxnId);
          
          final onHoldTxnSnap = await tx.get(onHoldTxnRef);
          
          if (onHoldTxnSnap.exists) {
            final onHoldData = onHoldTxnSnap.data() as Map<String, dynamic>?;
            if (onHoldData != null &&
                onHoldData['description'] == 'Post creation fee (On Hold)' &&
                onHoldData['referenceId'] == postId &&
                onHoldData['type'] == 'debit') {
              shouldUpdateTransaction = true;
            }
          }
        }
        
        // ========== PHASE 2: ALL WRITES AFTER READS ==========
        final int newHeldCredits = currentHeldCredits - feeCredits;
        
        // Update wallet to release held credits
        tx.update(walletDoc, {
          'heldCredits': newHeldCredits,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Update the "On Hold" transaction to "Post creation fee (Released)"
        if (shouldUpdateTransaction && onHoldTxnRef != null) {
          // Update description and change type from 'debit' to 'credit' since releasing credits is a credit operation
          tx.update(onHoldTxnRef, {
            'description': 'Post creation fee (Released)',
            'type': 'credit', // Change from debit to credit when releasing
          });
        } else {
          // If no "On Hold" transaction exists, create a new one
          final txnRef = txnCol.doc();
          tx.set(txnRef, {
            'id': txnRef.id,
            'userId': userId,
            'type': 'credit', // Released credits should be credit type
            'amount': feeCredits,
            'description': 'Post creation fee (Released)',
            'createdAt': FieldValue.serverTimestamp(),
            'referenceId': postId,
          });
        }
      });
      
      return true;
    } catch (e) {
      print('❌ Error releasing post creation held credits: $e');
      return false;
    }
  }

  // 静态方法：扣除指定用户的 post creation heldCredits 和 balance（用于 Post 被 approved 时）
  static Future<bool> deductPostCreationCreditsForUser({
    required FirebaseFirestore firestore,
    required String userId,
    required String postId,
    int feeCredits = 200,
  }) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    if (userId.isEmpty) throw ArgumentError('userId must not be empty');
    
    final walletDoc = firestore.collection('wallets').doc(userId);
    final txnCol = walletDoc.collection('transactions');
    
    try {
      // Find the "On Hold" transaction to update it (query outside transaction)
      final onHoldTransactions = await txnCol
          .where('description', isEqualTo: 'Post creation fee (On Hold)')
          .where('referenceId', isEqualTo: postId)
          .where('type', isEqualTo: 'debit')
          .limit(1)
          .get();
      
      await firestore.runTransaction((tx) async {
        // ========== PHASE 1: ALL READS FIRST ==========
        final walletSnap = await tx.get(walletDoc);
        if (!walletSnap.exists) {
          throw StateError('Wallet not found for user $userId');
        }
        
        final walletData = walletSnap.data()!;
        final int currentBalance = (walletData['balance'] as int?) ?? 0;
        final int currentHeldCredits = (walletData['heldCredits'] as int?) ?? 0;
        
        // Read the "On Hold" transaction document if it exists
        DocumentReference? onHoldTxnRef;
        bool shouldUpdateTransaction = false;
        
        if (onHoldTransactions.docs.isNotEmpty) {
          final onHoldTxnId = onHoldTransactions.docs.first.id;
          onHoldTxnRef = txnCol.doc(onHoldTxnId);
          
          final onHoldTxnSnap = await tx.get(onHoldTxnRef);
          
          if (onHoldTxnSnap.exists) {
            final onHoldData = onHoldTxnSnap.data() as Map<String, dynamic>?;
            if (onHoldData != null &&
                onHoldData['description'] == 'Post creation fee (On Hold)' &&
                onHoldData['referenceId'] == postId &&
                onHoldData['type'] == 'debit') {
              shouldUpdateTransaction = true;
            }
          }
        }
        
        // ========== PHASE 2: ALL WRITES AFTER READS ==========
        // Calculate new values: reduce both balance and heldCredits
        final int newBalance = currentBalance - feeCredits;
        final int newHeldCredits = currentHeldCredits - feeCredits;
        
        // Update wallet to deduct from both balance and heldCredits
        tx.update(walletDoc, {
          'balance': newBalance,
          'heldCredits': newHeldCredits,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Update the "On Hold" transaction to "Post creation fee" (completed)
        if (shouldUpdateTransaction && onHoldTxnRef != null) {
          tx.update(onHoldTxnRef, {
            'description': 'Post creation fee',
          });
        } else {
          // If no "On Hold" transaction exists, create a new one
          final txnRef = txnCol.doc();
          tx.set(txnRef, {
            'id': txnRef.id,
            'userId': userId,
            'type': 'debit',
            'amount': feeCredits,
            'description': 'Post creation fee',
            'createdAt': FieldValue.serverTimestamp(),
            'referenceId': postId,
          });
        }
      });
      
      return true;
    } catch (e) {
      print('❌ Error deducting post creation held credits: $e');
      return false;
    }
  }

  // Reward jobseekers after task completion
  Future<void> rewardTaskCompletion({
    required String taskId,
    int rewardCredits = 200,
  }) async {
    await credit(
      amount: rewardCredits,
      description: 'Task completed',
      referenceId: taskId,
    );
  }

  // Recruiters spend credits when hiring an jobseeker
  Future<void> spendForHire({
    required String hireId,
    int spendCredits = 500,
  }) async {
    await debit(
      amount: spendCredits,
      description: 'Hire jobseeker',
      referenceId: hireId,
    );
  }

  Future<Uri> createTopUpCheckoutSession({
    required int credits,
    required int amountInCents,
  }) async {
    final endpoint = _getTopUpEndpoint();
    final res = await _http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uid': _uid,
        'credits': credits,
        'amount': amountInCents,
        'currency': 'usd',
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError(
        'TOPUP_ENDPOINT_ERROR ${res.statusCode}: ${res.body}\n'
        'Endpoint: $endpoint',
      );
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final String url = map['checkoutUrl'] as String;
    final String sessionId = map['sessionId'] as String? ?? '';

    // Store pending payment for automatic crediting
    if (sessionId.isNotEmpty) {
      await _firestore.collection('pending_payments').doc(sessionId).set({
        'uid': _uid,
        'sessionId': sessionId,
        'credits': credits,
        'amount': amountInCents,
        'checkoutUrl': url,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    }

    return Uri.parse(url);
  }

  // Check for pending payments and auto-credit
  Future<void> checkAndCreditPendingPayments() async {
    try {
      final pendingPayments = await _firestore
          .collection('pending_payments')
          .where('uid', isEqualTo: _uid)
          .where('status', isEqualTo: 'pending')
          .get();

      print('Found ${pendingPayments.docs.length} pending payments');

      for (final doc in pendingPayments.docs) {
        final data = doc.data();
        final sessionId = data['sessionId'] as String? ?? '';
        final credits = data['credits'] as int? ?? 0;

        if (sessionId.isNotEmpty && credits > 0) {
          try {
            print('Processing payment: sessionId=$sessionId, credits=$credits');
            // Try to credit (will skip if already credited)
            await creditFromStripeSession(
              sessionId: sessionId,
              credits: credits,
            );

            // Mark as processed only if credit succeeded
            await doc.reference.update({'status': 'processed'});
            print('Successfully credited and marked as processed: $sessionId');
          } catch (e) {
            // Log error but continue with other payments
            print('Error crediting payment $sessionId: $e');
            // Don't mark as processed if credit failed
          }
        }
      }
    } catch (e) {
      print('Error checking pending payments: $e');
      // Don't rethrow - fail silently so UI doesn't show errors
    }
  }

  // Manually credit a processed payment that didn't credit (for fixing stuck payments)
  Future<void> forceCreditProcessedPayment(String sessionId) async {
    try {
      // Get the payment document
      final paymentDoc = await _firestore
          .collection('pending_payments')
          .doc(sessionId)
          .get();

      if (!paymentDoc.exists) {
        throw StateError('Payment not found');
      }

      final data = paymentDoc.data()!;
      final uid = data['uid'] as String? ?? '';
      final credits = data['credits'] as int? ?? 0;

      // Verify it's for this user
      if (uid != _uid) {
        throw StateError('Payment belongs to different user');
      }

      if (credits <= 0) {
        throw StateError('Invalid credits amount');
      }

      // Force credit (will skip if already credited)
      await creditFromStripeSession(sessionId: sessionId, credits: credits);
    } catch (e) {
      print('Error force crediting payment: $e');
      rethrow;
    }
  }

  // Verify Stripe session with Cloudflare Worker and credit wallet
  Future<void> creditFromStripeSession({
    required String sessionId,
    required int credits,
  }) async {
    final verification = await _verifyStripeSession(sessionId);
    if (!verification.paid) {
      throw StateError('PAYMENT_NOT_COMPLETED');
    }

    final int amountToCredit = verification.credits ?? credits;
    if (amountToCredit <= 0) {
      throw StateError('INVALID_CREDIT_AMOUNT');
    }

    if (verification.credits != null && verification.credits != credits) {
      print(
        'Verified credits (${verification.credits}) differ from expected ($credits). '
        'Using verified amount.',
      );
    }

    // Check if already credited (prevent duplicate credits)
    final existingTxn = await _txnCol
        .where('referenceId', isEqualTo: sessionId)
        .where('type', isEqualTo: 'credit')
        .limit(1)
        .get();

    if (existingTxn.docs.isNotEmpty) {
      // Already credited, just return
      return;
    }

    // Verify session with backend (optional - for security)
    // For now, we'll trust the sessionId and credit directly
    // In production, you might want to verify with Stripe API first

    // Credit the wallet with the sessionId as reference
    try {
      await credit(
        amount: credits,
        description: 'Top-up payment',
        referenceId: sessionId,
      );

      await _notificationService.notifyTopUpStatus(
        userId: _uid,
        success: true,
        credits: credits,
      );
    } catch (e) {
      await _notificationService.notifyTopUpStatus(
        userId: _uid,
        success: false,
        credits: credits,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // Check for pending payments and credit them (call when user returns to wallet page)
  Future<void> checkPendingPayments() async {
    // This can be called periodically or when user opens wallet page
    // For now, we rely on the success page to credit
    // Future: Could query Stripe API for pending sessions
  }

  Uri _getVerifyEndpointUri() {
    final override = _topUpVerifyEndpoint.trim();
    if (override.isNotEmpty) {
      return Uri.parse(_normalizeEndpoint(override));
    }

    final createUri = Uri.parse(_getTopUpEndpoint());
    final createPath = createUri.path.isEmpty ? '/' : createUri.path;
    final verifyPath = createPath.endsWith('/createTopUpSession')
        ? createPath.replaceFirst(
            RegExp(r'/createTopUpSession$'),
            '/verifyTopUpSession',
          )
        : (createPath.endsWith('/')
            ? '${createPath}verifyTopUpSession'
            : '$createPath/verifyTopUpSession');

    return createUri.replace(path: verifyPath);
  }

  Future<_StripeSessionVerification> _verifyStripeSession(
    String sessionId,
  ) async {
    final uri = _getVerifyEndpointUri();
    final res = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sessionId': sessionId,
        'uid': _uid,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError(
        'PAYMENT_VERIFY_FAILED ${res.statusCode}: ${res.body}',
      );
    }

    final data =
        jsonDecode(res.body) as Map<String, dynamic>? ?? const <String, dynamic>{};
    final metadata =
        data['metadata'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    return _StripeSessionVerification(
      paid: data['paid'] as bool? ?? false,
      credits: _parseCredits(metadata['credits'] ?? data['credits']),
      amountTotal: _parseInt(data['amount_total']),
      currency: data['currency'] as String?,
    );
  }

  static int? _parseCredits(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _normalizeEndpoint(String endpoint) {
    String value = endpoint.trim();
    if (value.isEmpty) return value;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }
    return value;
  }
}

class _StripeSessionVerification {
  const _StripeSessionVerification({
    required this.paid,
    this.credits,
    this.amountTotal,
    this.currency,
  });

  final bool paid;
  final int? credits;
  final int? amountTotal;
  final String? currency;
}
