import 'package:cloud_firestore/cloud_firestore.dart';

class Wallet {
  Wallet({
    required this.userId,
    required this.balance,
    required this.updatedAt,
    this.heldCredits = 0,
  });

  final String userId;
  final int balance; 
  final int heldCredits; 
  final DateTime updatedAt;

  
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
    
    DateTime updatedAt = DateTime.now();
    final updatedAtValue = data['updatedAt'];
    if (updatedAtValue != null) {
      if (updatedAtValue is DateTime) {
        updatedAt = updatedAtValue;
      } else if (updatedAtValue is Timestamp) {
        updatedAt = updatedAtValue.toDate();
      } else if (updatedAtValue is Map) {
        updatedAt = DateTime.now();
      }
    }
    
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
    this.parentTxnId, 
  });

  final String id;
  final String userId;
  final WalletTxnType type;
  final int amount; 
  final String description;
  final DateTime createdAt;
  final String? referenceId; 
  final String? parentTxnId; 

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'userId': userId,
      'type': type.name,
      'amount': amount,
      'description': description,
      'createdAt': createdAt,
      'referenceId': referenceId,
      if (parentTxnId != null) 'parentTxnId': parentTxnId,
    };
  }

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    DateTime createdAt = DateTime.now();
    final createdAtValue = map['createdAt'];
    if (createdAtValue != null) {
      if (createdAtValue is DateTime) {
        createdAt = createdAtValue;
      } else if (createdAtValue is Timestamp) {
        createdAt = createdAtValue.toDate();
      } else if (createdAtValue is Map) {
        createdAt = DateTime.now();
      }
    }
    
    //Parsing 
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
      parentTxnId: map['parentTxnId'] as String?,
    );
  }
}


