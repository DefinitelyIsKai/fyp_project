import 'package:cloud_firestore/cloud_firestore.dart';

class Wallet {
  Wallet({
    required this.userId,
    required this.balance,
    required this.updatedAt,
    this.heldCredits = 0,
  });

  final String userId;
  final int balance; // stored as integer credits
  final int heldCredits; // credits on hold for pending applications
  final DateTime updatedAt;

  // Available balance = balance - heldCredits
  int get availableBalance => balance - heldCredits;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'userId': userId,
      'balance': balance,
      'heldCredits': heldCredits,
      'updatedAt': updatedAt,
    };
  }

  factory Wallet.fromMap(Map<String, dynamic>? map, {required String uid}) {
    final data = map ?? <String, dynamic>{};
    
    // Handle Firestore Timestamp conversion
    DateTime updatedAt = DateTime.now();
    final updatedAtValue = data['updatedAt'];
    if (updatedAtValue != null) {
      if (updatedAtValue is DateTime) {
        updatedAt = updatedAtValue;
      } else if (updatedAtValue is Timestamp) {
        updatedAt = updatedAtValue.toDate();
      } else if (updatedAtValue is Map) {
        // Handle server timestamp placeholder
        updatedAt = DateTime.now();
      }
    }
    
    // Helper function to safely parse int from Firestore (handles int, double, num)
    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }
    
    return Wallet(
      userId: uid,
      balance: _parseInt(data['balance']) ?? 0,
      heldCredits: _parseInt(data['heldCredits']) ?? 0,
      updatedAt: updatedAt,
    );
  }
}

enum WalletTxnType { credit, debit }

class WalletTransaction {
  WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.referenceId,
  });

  final String id;
  final String userId;
  final WalletTxnType type;
  final int amount; // positive integer credits
  final String description;
  final DateTime createdAt;
  final String? referenceId; // e.g. postId, taskId, paymentIntentId

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'type': type.name,
      'amount': amount,
      'description': description,
      'createdAt': createdAt,
      'referenceId': referenceId,
    };
  }

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    // Handle Firestore Timestamp conversion for createdAt
    DateTime createdAt = DateTime.now();
    final createdAtValue = map['createdAt'];
    if (createdAtValue != null) {
      if (createdAtValue is DateTime) {
        createdAt = createdAtValue;
      } else if (createdAtValue is Timestamp) {
        createdAt = createdAtValue.toDate();
      } else if (createdAtValue is Map) {
        // Handle server timestamp placeholder
        createdAt = DateTime.now();
      }
    }
    
    // Helper function to safely parse int from Firestore (handles int, double, num)
    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }
    
    return WalletTransaction(
      id: (map['id'] as String?) ?? '',
      userId: (map['userId'] as String?) ?? '',
      type: (map['type'] as String?) == 'debit' ? WalletTxnType.debit : WalletTxnType.credit,
      amount: _parseInt(map['amount']) ?? 0,
      description: (map['description'] as String?) ?? '',
      createdAt: createdAt,
      referenceId: map['referenceId'] as String?,
    );
  }
}


