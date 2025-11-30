import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingRequestStatus {pending,approved,rejected}

class BookingRequest {
  final String id;
  final String slotId;
  final String recruiterId;
  final String jobseekerId;
  final String matchId; 
  final BookingRequestStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BookingRequest({
    required this.id,
    required this.slotId,
    required this.recruiterId,
    required this.jobseekerId,
    required this.matchId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory BookingRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookingRequest(
      id: doc.id,
      slotId: data['slotId'] as String,
      recruiterId: data['recruiterId'] as String,
      jobseekerId: data['jobseekerId'] as String,
      matchId: data['matchId'] as String,
      status: _statusFromString(data['status'] as String? ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'slotId': slotId,
      'recruiterId': recruiterId,
      'jobseekerId': jobseekerId,
      'matchId': matchId,
      'status': _statusToString(status),
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  static BookingRequestStatus _statusFromString(String status) {
    switch (status) {
      case 'approved':
        return BookingRequestStatus.approved;
      case 'rejected':
        return BookingRequestStatus.rejected;
      default:
        return BookingRequestStatus.pending;
    }
  }

  static String _statusToString(BookingRequestStatus status) {
    switch (status) {
      case BookingRequestStatus.approved:
        return 'approved';
      case BookingRequestStatus.rejected:
        return 'rejected';
      default:
        return 'pending';
    }
  }
}








