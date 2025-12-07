import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../models/user/wallet.dart';
import '../../utils/user/timestamp_utils.dart';
import 'notification_service.dart';

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


  //ordered createdAt descending
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

      payments.sort((a, b) {
        final aTime = TimestampUtils.parseTimestamp(a['createdAt']);
        final bTime = TimestampUtils.parseTimestamp(b['createdAt']);
        return bTime.compareTo(aTime); 
      });

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

          //sort by createdAt 
          payments.sort((a, b) {
            final aTime = TimestampUtils.parseTimestamp(a['createdAt']);
            final bTime = TimestampUtils.parseTimestamp(b['createdAt']);
            return bTime.compareTo(aTime); 
          });

          print('Returning ${payments.length} pending payments');
          return payments;
        });
  }

  Stream<List<Map<String, dynamic>>> streamCancelledPayments() {
    return _firestore
        .collection('pending_payments')
        .where('uid', isEqualTo: _uid)
        .where('status', isEqualTo: 'cancelled')
        .snapshots()
        .map((snap) {
          final payments = snap.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList();

          payments.sort((a, b) {
            final aTime = TimestampUtils.parseTimestamp(a['createdAt']);
            final bTime = TimestampUtils.parseTimestamp(b['createdAt']);
            return bTime.compareTo(aTime); 
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

      payments.sort((a, b) {
        final aTime = TimestampUtils.parseTimestamp(a['createdAt']);
        final bTime = TimestampUtils.parseTimestamp(b['createdAt']);
        return bTime.compareTo(aTime); 
      });

      return payments;
    } catch (e) {
      print('Error in getPendingPayments: $e');
      return [];
    }
  }

  Future<void> cancelPendingPayment(String sessionId) async {
    try {
      final paymentDoc = await _firestore.collection('pending_payments').doc(sessionId).get();

      if (!paymentDoc.exists) {
        throw StateError('Payment not found');
      }

      final data = paymentDoc.data()!;
      final uid = data['uid'] as String? ?? '';

      //verifyuser
      if (uid != _uid) {
        throw StateError('Payment belongs to different user');
      }

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

  Future<void> holdApplicationCredits({required String postId, int feeCredits = 100}) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    await _ensureWallet();
    final txnRef = _txnCol.doc();

    //post title for description
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

      tx.update(_walletDoc, {'heldCredits': heldCredits + feeCredits, 'updatedAt': FieldValue.serverTimestamp()});

      //crete transaction 
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

    try {
      await _notificationService.notifyWalletDebit(
        userId: _uid,
        amount: feeCredits,
        reason: 'Application fee (On Hold)',
        metadata: {'postId': postId, 'type': 'application_fee_hold'},
      );
    } catch (e) {
      print('Error sending wallet hold notification: $e');
    }
  }

  //release heldcredit when application rejected
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
        return;
      }

      tx.update(_walletDoc, {'heldCredits': heldCredits - feeCredits, 'updatedAt': FieldValue.serverTimestamp()});

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
      final postTitle = await getPostTitle(firestore: firestore, postId: postId);
      
      final onHoldTransactions = await txnCol
          .where('referenceId', isEqualTo: postId)
          .where('type', isEqualTo: 'debit')
          .get();

      String? onHoldTxnId;
      for (final doc in onHoldTransactions.docs) {
        final desc = doc.data()['description'] as String? ?? '';
        if (desc.contains('Application fee (On Hold)')) {
          onHoldTxnId = doc.id;
          break;
        }
      }

      if (onHoldTxnId != null) {
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
          return true; 
        }
      }

      await firestore.runTransaction((tx) async {
        final walletSnap = await tx.get(walletDoc);
        if (!walletSnap.exists) {
          throw StateError('Wallet not found for user $userId');
        }

        final walletData = walletSnap.data()!;
        final int currentHeldCredits = _parseIntFromFirestore(walletData['heldCredits']);

        if (currentHeldCredits < feeCredits) {
          print('Warning: heldCredits ($currentHeldCredits) is less than feeCredits ($feeCredits). This may indicate duplicate processing.');
        }

        DocumentReference? onHoldTxnRef;
        if (onHoldTxnId != null) {
          onHoldTxnRef = txnCol.doc(onHoldTxnId);
          final onHoldTxnSnap = await tx.get(onHoldTxnRef);
          if (!onHoldTxnSnap.exists) {
            onHoldTxnRef = null; 
          }
        }

        final int newHeldCredits = (currentHeldCredits - feeCredits).clamp(0, double.infinity).toInt();

       
        tx.update(walletDoc, {'heldCredits': newHeldCredits, 'updatedAt': FieldValue.serverTimestamp()});

        final newTxnRef = txnCol.doc();
        final description = postTitle.isNotEmpty
            ? 'Application fee (Released) - $postTitle'
            : 'Application fee (Released)';
        
        print('Creating new transaction record for released credits');
        tx.set(newTxnRef, {
          'id': newTxnRef.id,
          'userId': userId,
          'type': 'credit', 
          'amount': feeCredits,
          'description': description,
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': postId,
          if (onHoldTxnId != null) 'parentTxnId': onHoldTxnId, 
        });
      });

      print("Release credits successful for user $userId");
      return true;
    } catch (e) {
      print('Error releasing held credits: $e');
      return false;
    }
  }

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
      final postTitle = await getPostTitle(firestore: firestore, postId: postId);

      final onHoldTransactions = await txnCol
          .where('referenceId', isEqualTo: postId)
          .where('type', isEqualTo: 'debit')
          .get();

      String? onHoldTxnId;
      for (final doc in onHoldTransactions.docs) {
        final desc = doc.data()['description'] as String? ?? '';
        if (desc.contains('Application fee (On Hold)')) {
          onHoldTxnId = doc.id;
          break;
        }
      }

      if (onHoldTxnId != null) {
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
          return true; 
        }
      }

      await firestore.runTransaction((tx) async {

        final walletSnap = await tx.get(walletDoc);
        if (!walletSnap.exists) {
          throw StateError('Wallet not found for user $userId');
        }

        final walletData = walletSnap.data()!;
        final int currentBalance = _parseIntFromFirestore(walletData['balance']);
        final int currentHeldCredits = _parseIntFromFirestore(walletData['heldCredits']);

        if (currentHeldCredits < feeCredits) {
          print('Warning: heldCredits ($currentHeldCredits) is less than feeCredits ($feeCredits). This may indicate duplicate processing.');
        }

        DocumentReference? onHoldTxnRef;
        if (onHoldTxnId != null) {
          onHoldTxnRef = txnCol.doc(onHoldTxnId);
          final onHoldTxnSnap = await tx.get(onHoldTxnRef);
          if (!onHoldTxnSnap.exists) {
            onHoldTxnRef = null; 
          }
        }

        final int newBalance = currentBalance - feeCredits;
  
        final int newHeldCredits = (currentHeldCredits - feeCredits).clamp(0, double.infinity).toInt();

        tx.update(walletDoc, {
          'balance': newBalance,
          'heldCredits': newHeldCredits,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final newTxnRef = txnCol.doc();
        final description = postTitle.isNotEmpty
            ? 'Application fee - $postTitle'
            : 'Application fee';
        
        print('Creating new transaction record for deducted credits');
        tx.set(newTxnRef, {
          'id': newTxnRef.id,
          'userId': userId,
          'type': 'debit',
          'amount': feeCredits,
          'description': description,
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': postId,
          if (onHoldTxnId != null) 'parentTxnId': onHoldTxnId,
        });
      });

      print("Deduct successful for user $userId");
      return true;
    } catch (e) {
      print('Error deducting held credits: $e');
      return false;
    }
  }

  Future<bool> deductHeldCredits({
    required String postId,
    required String userId, 
    int feeCredits = 100,
  }) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    if (userId.isEmpty) throw ArgumentError('userId must not be empty');
    if (userId != _uid) {
      throw StateError('Cannot deduct credits for other users');
    }

    final walletDoc = _firestore.collection('wallets').doc(userId);
    final txnRef = _txnCol.doc();

    try {
      await _firestore.runTransaction((tx) async {
        tx.update(walletDoc, {
          'balance': FieldValue.increment(-feeCredits),
          'heldCredits': FieldValue.increment(-feeCredits),
          'updatedAt': FieldValue.serverTimestamp(),
        });

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

  //kept for backward compatibility but now uses hold
  Future<void> chargeApplication({required String postId, int feeCredits = 100}) async {
    await holdApplicationCredits(postId: postId, feeCredits: feeCredits);
  }

  
  Future<void> holdPostCreationCredits({required String postId, int feeCredits = 200}) async {
    if (feeCredits <= 0) throw ArgumentError('feeCredits must be > 0');
    await _ensureWallet();
    final txnRef = _txnCol.doc();

    final postTitle = await _getPostTitle(postId);
    final description = postTitle.isNotEmpty
        ? 'Post creation fee (On Hold) - $postTitle'
        : 'Post creation fee (On Hold)';

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(_walletDoc);
      final data = snap.data() ?? <String, dynamic>{'balance': 0, 'heldCredits': 0};
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

    
      tx.update(_walletDoc, {'heldCredits': heldCredits + feeCredits, 'updatedAt': FieldValue.serverTimestamp()});

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
      final postTitle = await getPostTitle(firestore: firestore, postId: postId);
      
      
      final onHoldTransactions = await txnCol
          .where('referenceId', isEqualTo: postId)
          .where('type', isEqualTo: 'debit')
          .get();
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

    
        if (currentHeldCredits < feeCredits) {
          print('Warning: heldCredits ($currentHeldCredits) is less than feeCredits ($feeCredits). This may indicate duplicate processing.');
    
        }

       
        DocumentReference? onHoldTxnRef;
        if (onHoldTxnId != null) {
          onHoldTxnRef = txnCol.doc(onHoldTxnId);
          final onHoldTxnSnap = await tx.get(onHoldTxnRef);
          if (!onHoldTxnSnap.exists) {
            onHoldTxnRef = null; 
          }
        }

  
        final int newHeldCredits = (currentHeldCredits - feeCredits).clamp(0, double.infinity).toInt();

    
        tx.update(walletDoc, {'heldCredits': newHeldCredits, 'updatedAt': FieldValue.serverTimestamp()});

        final newTxnRef = txnCol.doc();
        final description = postTitle.isNotEmpty
            ? 'Post creation fee (Released) - $postTitle'
            : 'Post creation fee (Released)';
        
        print('Creating new transaction record for released post creation credits');
        tx.set(newTxnRef, {
          'id': newTxnRef.id,
          'userId': userId,
          'type': 'credit', 
          'amount': feeCredits,
          'description': description,
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': postId,
          if (onHoldTxnId != null) 'parentTxnId': onHoldTxnId, 
        });
      });

      return true;
    } catch (e) {
      print('Error releasing post creation held credits: $e');
      return false;
    }
  }

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
      final postTitle = await getPostTitle(firestore: firestore, postId: postId);
      
 
      final onHoldTransactions = await txnCol
          .where('referenceId', isEqualTo: postId)
          .where('type', isEqualTo: 'debit')
          .get();


      String? onHoldTxnId;
      for (final doc in onHoldTransactions.docs) {
        final desc = doc.data()['description'] as String? ?? '';
        if (desc.contains('Post creation fee (On Hold)')) {
          onHoldTxnId = doc.id;
          break;
        }
      }

    
      if (onHoldTxnId != null) {
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
          return true;
        }
      }

      await firestore.runTransaction((tx) async {
        final walletSnap = await tx.get(walletDoc);
        if (!walletSnap.exists) {
          throw StateError('Wallet not found for user $userId');
        }

        final walletData = walletSnap.data()!;
        final int currentBalance = _parseIntFromFirestore(walletData['balance']);
        final int currentHeldCredits = _parseIntFromFirestore(walletData['heldCredits']);

        //ensure heldCredits sufficient
        if (currentHeldCredits < feeCredits) {
          print('Warning: heldCredits ($currentHeldCredits) is less than feeCredits ($feeCredits). This may indicate duplicate processing.');
        }
        DocumentReference? onHoldTxnRef;
        if (onHoldTxnId != null) {
          onHoldTxnRef = txnCol.doc(onHoldTxnId);
          final onHoldTxnSnap = await tx.get(onHoldTxnRef);
          if (!onHoldTxnSnap.exists) {
            onHoldTxnRef = null;
          }
        }

        final int newBalance = currentBalance - feeCredits;
        final int newHeldCredits = (currentHeldCredits - feeCredits).clamp(0, double.infinity).toInt();

        // Update wallet to deduct from both balance and heldCredits
        tx.update(walletDoc, {
          'balance': newBalance,
          'heldCredits': newHeldCredits,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        //cretae new transaction record
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
          if (onHoldTxnId != null) 'parentTxnId': onHoldTxnId, 
          //link original On Hold transaction
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
      body: jsonEncode({'uid': _uid, 'credits': credits, 'amount': amountInCents, 'currency': 'myr'}),
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

    //store pending payment automatic crediting
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

  //check pending payments  auto-credit
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
            await completePendingPayment(sessionId: sessionId);
            print('Successfully processed payment: $sessionId');
          } catch (e) {
            print('Error crediting payment $sessionId: $e');
          }
        }
      }
    } catch (e) {
      print('Error checking pending payments: $e');
    }
  }

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
      
      if (uid != _uid) {
        throw StateError('Payment belongs to different user');
      }
      
      if (status == 'processed') {
        throw StateError('PAYMENT_ALREADY_PROCESSED');
      }
      
      bool shouldProcess = false;
      if (status == 'pending') {
        shouldProcess = true;
      } else if (status == 'processing') {
        final processingStartedAt = data['processingStartedAt'] as Timestamp?;
        if (processingStartedAt != null) {
          final now = Timestamp.now();
          final duration = now.seconds - processingStartedAt.seconds;
          //5 minute retyr
          if (duration > 300) {
            print('Payment stuck in processing for ${duration}s, allowing retry');
            shouldProcess = true;
          } else {
            throw StateError('PAYMENT_ALREADY_PROCESSING');
          }
        } else {
          print('Payment in processing state without timestamp, allowing retry');
          shouldProcess = true;
        }
      } else {
        throw StateError('PAYMENT_INVALID_STATUS: $status');
      }
      
      //prevent duplicate processing
      if (shouldProcess) {
        tx.update(paymentDocRef, {
          'status': 'processing',
          'processingStartedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    
    try {
      //get payment data again
      final paymentDoc = await paymentDocRef.get();
      final data = paymentDoc.data()!;
      final credits = _parseIntFromFirestore(data['credits']);
      
      if (credits <= 0) {
        throw StateError('INVALID_CREDIT_AMOUNT');
      }
      
      await creditFromStripeSession(sessionId: sessionId, credits: credits);
      await paymentDocRef.update({
        'status': 'processed',
        'processedAt': FieldValue.serverTimestamp(),
      });
      
      print('Successfully completed payment: $sessionId');
    } catch (e) {
      try {
        await paymentDocRef.update({
          'status': 'pending',
          'lastError': e.toString(),
          'lastErrorAt': FieldValue.serverTimestamp(),
        });
      } catch (updateError) {
        print('Error resetting payment status: $updateError');
      }
      rethrow;
    }
  }

  

  //verify Stripe session with Cloudflare Worker and credit wallet
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

    //prevent duplicate credits
    final existingTxn = await _txnCol
        .where('referenceId', isEqualTo: sessionId)
        .where('type', isEqualTo: 'credit')
        .limit(1)
        .get();

    if (existingTxn.docs.isNotEmpty) {
      print('Payment already credited: $sessionId');
      return;
    }

    //credit the wallet sessionId reference
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
