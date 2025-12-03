import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../models/user/wallet.dart';
import '../../utils/user/timestamp_utils.dart';
import 'notification_service.dart';

// Helper function to safely parse int from Firestore (handles int, double, num)
int _parseIntFromFirestore(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

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
    defaultValue: 'https://stripe-topup-worker.lowbryan022.workers.dev/createTopUpSession',
  );
  static const String _topUpVerifyEndpoint = String.fromEnvironment('TOPUP_VERIFY_ENDPOINT', defaultValue: '');

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

  DocumentReference<Map<String, dynamic>> get _walletDoc => _firestore.collection('wallets').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _txnCol => _walletDoc.collection('transactions');

  Stream<Wallet> streamWallet() {
    return _walletDoc.snapshots().map((snap) => Wallet.fromMap(snap.data(), uid: _uid));
  }

  /// Stream transactions in real-time
  /// Returns a stream of all transactions ordered by createdAt descending
  Stream<List<WalletTransaction>> streamTransactions({int limit = 50}) {
    return _txnCol
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => WalletTransaction.fromMap(<String, dynamic>{...d.data(), 'id': d.id})).toList(),
        );
  }

  Future<List<WalletTransaction>> loadInitialTransactions({int limit = 20}) async {
    try {
      final snapshot = await _txnCol.orderBy('createdAt', descending: true).limit(limit).get();

      return snapshot.docs.map((d) => WalletTransaction.fromMap(<String, dynamic>{...d.data(), 'id': d.id})).toList();
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
              .map((d) => WalletTransaction.fromMap(<String, dynamic>{...d.data(), 'id': d.id}))
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

      return snapshot.docs.map((d) => WalletTransaction.fromMap(<String, dynamic>{...d.data(), 'id': d.id})).toList();
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

      final payments = snapshot.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList();

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
        .map((snap) {
          print('Pending payments snapshot: ${snap.docs.length} documents');
          final payments = snap.docs.map((d) {
            final data = d.data();
            print('Pending payment data: $data');
            return <String, dynamic>{...data, 'id': d.id};
          }).toList();

          // Sort by createdAt manually to avoid requiring composite index
          payments.sort((a, b) {
            final aTime = TimestampUtils.parseTimestamp(a['createdAt']);
            final bTime = TimestampUtils.parseTimestamp(b['createdAt']);
            return bTime.compareTo(aTime); // descending
          });

          print('Returning ${payments.length} pending payments');
          return payments;
        });
  }

  /// Stream cancelled payments in real-time
  Stream<List<Map<String, dynamic>>> streamCancelledPayments() {
    return _firestore
        .collection('pending_payments')
        .where('uid', isEqualTo: _uid)
        .where('status', isEqualTo: 'cancelled')
        .snapshots()
        .map((snap) {
          final payments = snap.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList();

          // Sort by createdAt manually
          payments.sort((a, b) {
            final aTime = TimestampUtils.parseTimestamp(a['createdAt']);
            final bTime = TimestampUtils.parseTimestamp(b['createdAt']);
            return bTime.compareTo(aTime); // descending
          });

          return payments;
        });
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

      final payments = pendingPayments.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList();

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
      final paymentDoc = await _firestore.collection('pending_payments').doc(sessionId).get();

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
      await paymentDoc.reference.update({'status': 'cancelled', 'cancelledAt': FieldValue.serverTimestamp()});

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
        tx.set(_walletDoc, {'userId': _uid, 'balance': 0, 'heldCredits': 0, 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        // Ensure heldCredits field exists for existing wallets
        final data = doc.data();
        if (data != null && !data.containsKey('heldCredits')) {
          tx.update(_walletDoc, {'heldCredits': 0});
        }
      }
    });
  }

  Future<void> credit({required int amount, required String description, String? referenceId}) async {
    if (amount <= 0) throw ArgumentError('amount must be > 0');
    await _ensureWallet();
    final txnRef = _txnCol.doc();
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_walletDoc);
      final data = snap.data() ?? <String, dynamic>{'balance': 0};
      final int current = _parseIntFromFirestore(data['balance']);
      final int next = current + amount;
      tx.update(_walletDoc, {'balance': next, 'updatedAt': FieldValue.serverTimestamp()});
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

  

  // Hold credits when jobseeker applies to a post (credits are held, not deducted yet)
  Future<void> holdApplicationCredits({required String postId, int feeCredits = 100}) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    await _ensureWallet();
    final txnRef = _txnCol.doc();

    // Get post title for description
    final postTitle = await _getPostTitle(postId);
    final description = postTitle.isNotEmpty
        ? 'Application fee (On Hold) - $postTitle'
        : 'Application fee (On Hold)';

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_walletDoc);
      final data = snap.data() ?? <String, dynamic>{'balance': 0, 'heldCredits': 0};
      final int balance = _parseIntFromFirestore(data['balance']);
      final int heldCredits = _parseIntFromFirestore(data['heldCredits']);
      final int available = balance - heldCredits;

      if (available < feeCredits) {
        throw StateError('INSUFFICIENT_FUNDS');
      }

      // Increase held credits
      tx.update(_walletDoc, {'heldCredits': heldCredits + feeCredits, 'updatedAt': FieldValue.serverTimestamp()});

      // Create transaction record for held credits (jobseeker can create)
      tx.set(txnRef, {
        'id': txnRef.id,
        'userId': _uid,
        'type': 'debit',
        'amount': feeCredits,
        'description': description,
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
  Future<bool> releaseHeldCredits({required String postId, int feeCredits = 100}) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    await _ensureWallet();
    final txnRef = _txnCol.doc();

    bool released = false;
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_walletDoc);
      final data = snap.data() ?? <String, dynamic>{'balance': 0, 'heldCredits': 0};
      final int heldCredits = _parseIntFromFirestore(data['heldCredits']);

      if (heldCredits < feeCredits) {
        // Already processed or no credits held - silently return false
        return;
      }

      // Decrease held credits (release the hold)
      tx.update(_walletDoc, {'heldCredits': heldCredits - feeCredits, 'updatedAt': FieldValue.serverTimestamp()});

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
      // Get post title for description
      final postTitle = await getPostTitle(firestore: firestore, postId: postId);
      
      // Find the "On Hold" transaction (query outside transaction)
      // Look for transactions that contain "Application fee (On Hold)" in description
      final onHoldTransactions = await txnCol
          .where('referenceId', isEqualTo: postId)
          .where('type', isEqualTo: 'debit')
          .get();

      // Find the On Hold transaction (description may contain post title)
      String? onHoldTxnId;
      for (final doc in onHoldTransactions.docs) {
        final desc = doc.data()['description'] as String? ?? '';
        if (desc.contains('Application fee (On Hold)')) {
          onHoldTxnId = doc.id;
          break;
        }
      }

      // Check if already processed by looking for existing completed transaction (outside transaction)
      // Use simpler query to avoid needing composite index - query by referenceId and filter client-side
      if (onHoldTxnId != null) {
        // Query by referenceId (which should have an index) and filter client-side
        final allPostTransactions = await txnCol
            .where('referenceId', isEqualTo: postId)
            .get();
        final alreadyProcessed = allPostTransactions.docs.any((doc) {
          final data = doc.data();
          return data['parentTxnId'] == onHoldTxnId &&
                 data['type'] == 'credit';
        });
        if (alreadyProcessed) {
          print('Transaction already processed (released), skipping duplicate release');
          return true; // Already processed, exit early
        }
      }

      await firestore.runTransaction((tx) async {
        // ========== PHASE 1: ALL READS FIRST ==========
        // Read wallet first to get current values (needed for security rule evaluation)
        final walletSnap = await tx.get(walletDoc);
        if (!walletSnap.exists) {
          throw StateError('Wallet not found for user $userId');
        }

        final walletData = walletSnap.data()!;
        final int currentHeldCredits = _parseIntFromFirestore(walletData['heldCredits']);

        // Safety check: Ensure heldCredits is sufficient
        if (currentHeldCredits < feeCredits) {
          print('Warning: heldCredits ($currentHeldCredits) is less than feeCredits ($feeCredits). This may indicate duplicate processing.');
          // Don't throw error, but clamp to 0 to prevent negative values
        }

        // Read the "On Hold" transaction document if it exists
        DocumentReference? onHoldTxnRef;
        if (onHoldTxnId != null) {
          onHoldTxnRef = txnCol.doc(onHoldTxnId);
          final onHoldTxnSnap = await tx.get(onHoldTxnRef);
          if (!onHoldTxnSnap.exists) {
            onHoldTxnRef = null; // Transaction was deleted, create new one
          }
        }

        // ========== PHASE 2: ALL WRITES AFTER READS ==========
        // Calculate new heldCredits value, clamp to prevent negative values
        final int newHeldCredits = (currentHeldCredits - feeCredits).clamp(0, double.infinity).toInt();

        // Update wallet to release held credits
        tx.update(walletDoc, {'heldCredits': newHeldCredits, 'updatedAt': FieldValue.serverTimestamp()});

        // Create new transaction record instead of updating the old one
        final newTxnRef = txnCol.doc();
        final description = postTitle.isNotEmpty
            ? 'Application fee (Released) - $postTitle'
            : 'Application fee (Released)';
        
        print('Creating new transaction record for released credits');
        tx.set(newTxnRef, {
          'id': newTxnRef.id,
          'userId': userId,
          'type': 'credit', // Released credits should be credit type
          'amount': feeCredits,
          'description': description,
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': postId,
          if (onHoldTxnId != null) 'parentTxnId': onHoldTxnId, // Link to original On Hold transaction
        });
      });

      print("Release credits successful for user $userId");
      return true;
    } catch (e) {
      print('Error releasing held credits: $e');
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
      // Get post title for description
      final postTitle = await getPostTitle(firestore: firestore, postId: postId);
      
      // Find the "On Hold" transaction (query outside transaction)
      // Look for transactions that contain "Application fee (On Hold)" in description
      final onHoldTransactions = await txnCol
          .where('referenceId', isEqualTo: postId)
          .where('type', isEqualTo: 'debit')
          .get();

      // Find the On Hold transaction (description may contain post title)
      String? onHoldTxnId;
      for (final doc in onHoldTransactions.docs) {
        final desc = doc.data()['description'] as String? ?? '';
        if (desc.contains('Application fee (On Hold)')) {
          onHoldTxnId = doc.id;
          break;
        }
      }

      // Check if already processed by looking for existing completed transaction (outside transaction)
      // Use simpler query to avoid needing composite index - query by referenceId and filter client-side
      if (onHoldTxnId != null) {
        // Query by referenceId (which should have an index) and filter client-side
        final allPostTransactions = await txnCol
            .where('referenceId', isEqualTo: postId)
            .get();
        final alreadyProcessed = allPostTransactions.docs.any((doc) {
          final data = doc.data();
          return data['parentTxnId'] == onHoldTxnId &&
                 data['type'] == 'debit' &&
                 !(data['description'] as String? ?? '').contains('(On Hold)');
        });
        if (alreadyProcessed) {
          print('Transaction already processed, skipping duplicate deduction');
          return true; // Already processed, exit early
        }
      }

      await firestore.runTransaction((tx) async {
        // ========== PHASE 1: ALL READS FIRST ==========
        // Read wallet first to get current values (needed for security rule evaluation)
        final walletSnap = await tx.get(walletDoc);
        if (!walletSnap.exists) {
          throw StateError('Wallet not found for user $userId');
        }

        final walletData = walletSnap.data()!;
        final int currentBalance = _parseIntFromFirestore(walletData['balance']);
        final int currentHeldCredits = _parseIntFromFirestore(walletData['heldCredits']);

        // Safety check: Ensure heldCredits is sufficient
        if (currentHeldCredits < feeCredits) {
          print('Warning: heldCredits ($currentHeldCredits) is less than feeCredits ($feeCredits). This may indicate duplicate processing.');
          // Don't throw error, but clamp to 0 to prevent negative values
        }

        // Read the "On Hold" transaction document if it exists
        DocumentReference? onHoldTxnRef;
        if (onHoldTxnId != null) {
          onHoldTxnRef = txnCol.doc(onHoldTxnId);
          final onHoldTxnSnap = await tx.get(onHoldTxnRef);
          if (!onHoldTxnSnap.exists) {
            onHoldTxnRef = null; // Transaction was deleted, create new one
          }
        }

        // ========== PHASE 2: ALL WRITES AFTER READS ==========
        // Calculate new values
        final int newBalance = currentBalance - feeCredits;
        // Clamp heldCredits to prevent negative values
        final int newHeldCredits = (currentHeldCredits - feeCredits).clamp(0, double.infinity).toInt();

        // 同时减少 balance 和 heldCredits（将 hold 转换为实际扣款）
        // Use explicit values so security rules can evaluate them
        tx.update(walletDoc, {
          'balance': newBalance,
          'heldCredits': newHeldCredits,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create new transaction record instead of updating the old one
        final newTxnRef = txnCol.doc();
        final description = postTitle.isNotEmpty
            ? 'Application fee - $postTitle'
            : 'Application fee';
        
        print('➕ Creating new transaction record for deducted credits');
        tx.set(newTxnRef, {
          'id': newTxnRef.id,
          'userId': userId,
          'type': 'debit',
          'amount': feeCredits,
          'description': description,
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': postId,
          if (onHoldTxnId != null) 'parentTxnId': onHoldTxnId, // Link to original On Hold transaction
        });
      });

      print("Deduct successful for user $userId");
      return true;
    } catch (e) {
      print('Error deducting held credits: $e');
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

      
      await _notificationService.notifyWalletDebit(
        userId: userId,
        amount: feeCredits,
        reason: 'Application fee',
        metadata: {'referenceId': postId},
      );

      print("Deduct successful for user $userId");
      return true;
    } catch (e) {
      
      print('Error deducting held credits: $e');
      return false;
    }
  }

  // Legacy method - kept for backward compatibility but now uses hold
  Future<void> chargeApplication({required String postId, int feeCredits = 100}) async {
    await holdApplicationCredits(postId: postId, feeCredits: feeCredits);
  }

  

  // Hold credits when recruiter creates a post (credits are held, not deducted yet)
  // Credits will be deducted when post is approved (status changes to active)
  // Credits will be released when post is rejected
  Future<void> holdPostCreationCredits({required String postId, int feeCredits = 200}) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    await _ensureWallet();
    final txnRef = _txnCol.doc();

    // Get post title for description
    final postTitle = await _getPostTitle(postId);
    final description = postTitle.isNotEmpty
        ? 'Post creation fee (On Hold) - $postTitle'
        : 'Post creation fee (On Hold)';

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_walletDoc);
      final data = snap.data() ?? <String, dynamic>{'balance': 0, 'heldCredits': 0};
      // Helper to safely parse int from Firestore (handles int, double, num)
      int _parseInt(dynamic value) {
        if (value == null) return 0;
        if (value is int) return value;
        if (value is double) return value.toInt();
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value) ?? 0;
        return 0;
      }
      final int balance = _parseInt(data['balance']);
      final int heldCredits = _parseInt(data['heldCredits']);
      final int available = balance - heldCredits;

      if (available < feeCredits) {
        throw StateError('INSUFFICIENT_FUNDS');
      }

      // Increase held credits
      tx.update(_walletDoc, {'heldCredits': heldCredits + feeCredits, 'updatedAt': FieldValue.serverTimestamp()});

      // Create transaction record for held credits
      tx.set(txnRef, {
        'id': txnRef.id,
        'userId': _uid,
        'type': 'debit',
        'amount': feeCredits,
        'description': description,
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
      print('Error sending wallet hold notification: $e');
    }
  }

  // post creation heldCredits when rejected
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
      // Get post title for description
      final postTitle = await getPostTitle(firestore: firestore, postId: postId);
      
      // Find the "On Hold" transaction (query outside transaction)
      // Look for transactions that contain "Post creation fee (On Hold)" in description
      final onHoldTransactions = await txnCol
          .where('referenceId', isEqualTo: postId)
          .where('type', isEqualTo: 'debit')
          .get();

      // Find the On Hold transaction (description may contain post title)
      String? onHoldTxnId;
      for (final doc in onHoldTransactions.docs) {
        final desc = doc.data()['description'] as String? ?? '';
        if (desc.contains('Post creation fee (On Hold)')) {
          onHoldTxnId = doc.id;
          break;
        }
      }

      await firestore.runTransaction((tx) async {
        final walletSnap = await tx.get(walletDoc);
        if (!walletSnap.exists) {
          throw StateError('Wallet not found for user $userId');
        }

        final walletData = walletSnap.data()!;
        final int currentHeldCredits = _parseIntFromFirestore(walletData['heldCredits']);

        // Safety check: Ensure heldCredits is sufficient
        if (currentHeldCredits < feeCredits) {
          print('Warning: heldCredits ($currentHeldCredits) is less than feeCredits ($feeCredits). This may indicate duplicate processing.');
          // Don't throw error, but clamp to 0 to prevent negative values
        }

        // Read the "On Hold" transaction document if it exists
        DocumentReference? onHoldTxnRef;
        if (onHoldTxnId != null) {
          onHoldTxnRef = txnCol.doc(onHoldTxnId);
          final onHoldTxnSnap = await tx.get(onHoldTxnRef);
          if (!onHoldTxnSnap.exists) {
            onHoldTxnRef = null; // Transaction was deleted, create new one
          }
        }

        // Clamp heldCredits to prevent negative values
        final int newHeldCredits = (currentHeldCredits - feeCredits).clamp(0, double.infinity).toInt();

        // Update wallet to release held credits
        tx.update(walletDoc, {'heldCredits': newHeldCredits, 'updatedAt': FieldValue.serverTimestamp()});

        // Create new transaction record instead of updating the old one
        final newTxnRef = txnCol.doc();
        final description = postTitle.isNotEmpty
            ? 'Post creation fee (Released) - $postTitle'
            : 'Post creation fee (Released)';
        
        print('Creating new transaction record for released post creation credits');
        tx.set(newTxnRef, {
          'id': newTxnRef.id,
          'userId': userId,
          'type': 'credit', // Released credits should be credit type
          'amount': feeCredits,
          'description': description,
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': postId,
          if (onHoldTxnId != null) 'parentTxnId': onHoldTxnId, // Link to original On Hold transaction
        });
      });

      return true;
    } catch (e) {
      print('Error releasing post creation held credits: $e');
      return false;
    }
  }

  // deduct post creation heldCredits and balance when approved
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
      // Get post title for description
      final postTitle = await getPostTitle(firestore: firestore, postId: postId);
      
      // Find the "On Hold" transaction (query outside transaction)
      // Look for transactions that contain "Post creation fee (On Hold)" in description
      final onHoldTransactions = await txnCol
          .where('referenceId', isEqualTo: postId)
          .where('type', isEqualTo: 'debit')
          .get();

      // Find the On Hold transaction (description may contain post title)
      String? onHoldTxnId;
      for (final doc in onHoldTransactions.docs) {
        final desc = doc.data()['description'] as String? ?? '';
        if (desc.contains('Post creation fee (On Hold)')) {
          onHoldTxnId = doc.id;
          break;
        }
      }

      // Check if already processed by looking for existing completed transaction (outside transaction)
      // Use simpler query to avoid needing composite index - query by referenceId and filter client-side
      if (onHoldTxnId != null) {
        // Query by referenceId (which should have an index) and filter client-side
        final allPostTransactions = await txnCol
            .where('referenceId', isEqualTo: postId)
            .get();
        final alreadyProcessed = allPostTransactions.docs.any((doc) {
          final data = doc.data();
          return data['parentTxnId'] == onHoldTxnId &&
                 data['type'] == 'debit' &&
                 !(data['description'] as String? ?? '').contains('(On Hold)');
        });
        if (alreadyProcessed) {
          print('Transaction already processed, skipping duplicate deduction');
          return true; // Already processed, exit early
        }
      }

      await firestore.runTransaction((tx) async {
        // ========== PHASE 1: ALL READS FIRST ==========
        final walletSnap = await tx.get(walletDoc);
        if (!walletSnap.exists) {
          throw StateError('Wallet not found for user $userId');
        }

        final walletData = walletSnap.data()!;
        final int currentBalance = _parseIntFromFirestore(walletData['balance']);
        final int currentHeldCredits = _parseIntFromFirestore(walletData['heldCredits']);

        // Safety check: Ensure heldCredits is sufficient
        if (currentHeldCredits < feeCredits) {
          print('Warning: heldCredits ($currentHeldCredits) is less than feeCredits ($feeCredits). This may indicate duplicate processing.');
          // Don't throw error, but clamp to 0 to prevent negative values
        }

        // Read the "On Hold" transaction document if it exists
        DocumentReference? onHoldTxnRef;
        if (onHoldTxnId != null) {
          onHoldTxnRef = txnCol.doc(onHoldTxnId);
          final onHoldTxnSnap = await tx.get(onHoldTxnRef);
          if (!onHoldTxnSnap.exists) {
            onHoldTxnRef = null; // Transaction was deleted, create new one
          }
        }

        final int newBalance = currentBalance - feeCredits;
        // Clamp heldCredits to prevent negative values
        final int newHeldCredits = (currentHeldCredits - feeCredits).clamp(0, double.infinity).toInt();

        // Update wallet to deduct from both balance and heldCredits
        tx.update(walletDoc, {
          'balance': newBalance,
          'heldCredits': newHeldCredits,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create new transaction record instead of updating the old one
        final newTxnRef = txnCol.doc();
        final description = postTitle.isNotEmpty
            ? 'Post creation fee - $postTitle'
            : 'Post creation fee';
        
        print('Creating new transaction record for deducted post creation credits');
        tx.set(newTxnRef, {
          'id': newTxnRef.id,
          'userId': userId,
          'type': 'debit',
          'amount': feeCredits,
          'description': description,
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': postId,
          if (onHoldTxnId != null) 'parentTxnId': onHoldTxnId, // Link to original On Hold transaction
        });
      });

      return true;
    } catch (e) {
      print('Error deducting post creation held credits: $e');
      return false;
    }
  }

  

  Future<Uri> createTopUpCheckoutSession({required int credits, required int amountInCents}) async {
    final endpoint = _getTopUpEndpoint();
    final res = await _http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'uid': _uid, 'credits': credits, 'amount': amountInCents, 'currency': 'usd'}),
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
        final credits = _parseIntFromFirestore(data['credits']);

        if (sessionId.isNotEmpty && credits > 0) {
          try {
            print('Processing payment: sessionId=$sessionId, credits=$credits');
            // Use the new method that handles duplicate prevention
            await completePendingPayment(sessionId: sessionId);
            print('Successfully processed payment: $sessionId');
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

  // Complete a specific pending payment (verify and credit atomically)
  // This method prevents duplicate credits by using atomic status updates
  Future<void> completePendingPayment({required String sessionId}) async {
    final paymentDocRef = _firestore.collection('pending_payments').doc(sessionId);
    
    // Use transaction to atomically check status and mark as processing
    await _firestore.runTransaction((tx) async {
      final paymentSnap = await tx.get(paymentDocRef);
      
      if (!paymentSnap.exists) {
        throw StateError('Payment not found');
      }
      
      final data = paymentSnap.data()!;
      final status = data['status'] as String? ?? 'pending';
      final uid = data['uid'] as String? ?? '';
      
      // Verify it's for this user
      if (uid != _uid) {
        throw StateError('Payment belongs to different user');
      }
      
      // Check if already processed
      if (status == 'processed') {
        throw StateError('PAYMENT_ALREADY_PROCESSED');
      }
      
      // Handle processing status - check if stuck
      bool shouldProcess = false;
      if (status == 'pending') {
        shouldProcess = true;
      } else if (status == 'processing') {
        final processingStartedAt = data['processingStartedAt'] as Timestamp?;
        if (processingStartedAt != null) {
          final now = Timestamp.now();
          final duration = now.seconds - processingStartedAt.seconds;
          // If stuck in processing for more than 5 minutes, allow retry
          if (duration > 300) {
            print('Payment stuck in processing for ${duration}s, allowing retry');
            shouldProcess = true; // Allow retry by updating to processing again
          } else {
            // Still processing normally, throw error to prevent duplicate
            throw StateError('PAYMENT_ALREADY_PROCESSING');
          }
        } else {
          // No timestamp, allow retry
          print('Payment in processing state without timestamp, allowing retry');
          shouldProcess = true;
        }
      } else {
        throw StateError('PAYMENT_INVALID_STATUS: $status');
      }
      
      // Mark as processing to prevent duplicate processing
      if (shouldProcess) {
        tx.update(paymentDocRef, {
          'status': 'processing',
          'processingStartedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    
    try {
      // Get payment data again (outside transaction)
      final paymentDoc = await paymentDocRef.get();
      final data = paymentDoc.data()!;
      final credits = _parseIntFromFirestore(data['credits']);
      
      if (credits <= 0) {
        throw StateError('INVALID_CREDIT_AMOUNT');
      }
      
      // Verify and credit the payment
      await creditFromStripeSession(sessionId: sessionId, credits: credits);
      
      // Mark as processed only after successful credit
      await paymentDocRef.update({
        'status': 'processed',
        'processedAt': FieldValue.serverTimestamp(),
      });
      
      print('Successfully completed payment: $sessionId');
    } catch (e) {
      // If credit failed, reset status back to pending so user can retry
      try {
        await paymentDocRef.update({
          'status': 'pending',
          'lastError': e.toString(),
          'lastErrorAt': FieldValue.serverTimestamp(),
        });
      } catch (updateError) {
        print('Error resetting payment status: $updateError');
      }
      
      // Re-throw the original error
      rethrow;
    }
  }

  

  // Verify Stripe session with Cloudflare Worker and credit wallet
  Future<void> creditFromStripeSession({required String sessionId, required int credits}) async {
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
    // This is an additional safety check, though the status check should prevent duplicates
    final existingTxn = await _txnCol
        .where('referenceId', isEqualTo: sessionId)
        .where('type', isEqualTo: 'credit')
        .limit(1)
        .get();

    if (existingTxn.docs.isNotEmpty) {
      // Already credited, just return
      print('Payment already credited: $sessionId');
      return;
    }

    // Credit the wallet with the sessionId as reference
    // Use the verified amount, not the expected amount
    try {
      await credit(amount: amountToCredit, description: 'Top-up payment', referenceId: sessionId);

      await _notificationService.notifyTopUpStatus(userId: _uid, success: true, credits: amountToCredit);
    } catch (e) {
      await _notificationService.notifyTopUpStatus(userId: _uid, success: false, credits: amountToCredit, error: e.toString());
      rethrow;
    }
  }

 

  Uri _getVerifyEndpointUri() {
    final override = _topUpVerifyEndpoint.trim();
    if (override.isNotEmpty) {
      return Uri.parse(_normalizeEndpoint(override));
    }

    final createUri = Uri.parse(_getTopUpEndpoint());
    final createPath = createUri.path.isEmpty ? '/' : createUri.path;
    final verifyPath = createPath.endsWith('/createTopUpSession')
        ? createPath.replaceFirst(RegExp(r'/createTopUpSession$'), '/verifyTopUpSession')
        : (createPath.endsWith('/') ? '${createPath}verifyTopUpSession' : '$createPath/verifyTopUpSession');

    return createUri.replace(path: verifyPath);
  }

  Future<_StripeSessionVerification> _verifyStripeSession(String sessionId) async {
    final uri = _getVerifyEndpointUri();
    final res = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sessionId': sessionId, 'uid': _uid}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('PAYMENT_VERIFY_FAILED ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>? ?? const <String, dynamic>{};
    final metadata = data['metadata'] as Map<String, dynamic>? ?? const <String, dynamic>{};

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

  /// Helper function to get post title from postId
  /// Returns post title or empty string if not found
  Future<String> _getPostTitle(String postId) async {
    if (postId.isEmpty) return '';
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final data = postDoc.data();
        return (data?['title'] as String?) ?? '';
      }
    } catch (e) {
      print('Error fetching post title for $postId: $e');
    }
    return '';
  }

  /// Static helper function to get post title from postId
  static Future<String> getPostTitle({
    required FirebaseFirestore firestore,
    required String postId,
  }) async {
    if (postId.isEmpty) return '';
    try {
      final postDoc = await firestore.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final data = postDoc.data();
        return (data?['title'] as String?) ?? '';
      }
    } catch (e) {
      print('Error fetching post title for $postId: $e');
    }
    return '';
  }
}

class _StripeSessionVerification {
  const _StripeSessionVerification({required this.paid, this.credits, this.amountTotal, this.currency});

  final bool paid;
  final int? credits;
  final int? amountTotal;
  final String? currency;
}
