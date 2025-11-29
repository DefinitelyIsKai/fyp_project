import 'package:cloud_firestore/cloud_firestore.dart';

class AvailabilitySlot {
  final String id;
  final String recruiterId;
  final DateTime date;
  final String startTime; // Format: "HH:mm" (e.g., "09:00")
  final String endTime; // Format: "HH:mm" (e.g., "10:00")
  final bool isAvailable;
  final String? bookedBy; // jobseekerId if booked
  final String? matchId; // jobMatchId if booked
  final DateTime createdAt;

  AvailabilitySlot({
    required this.id,
    required this.recruiterId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    this.bookedBy,
    this.matchId,
    required this.createdAt,
  });

  factory AvailabilitySlot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AvailabilitySlot(
      id: doc.id,
      recruiterId: data['recruiterId'] as String,
      date: (data['date'] as Timestamp).toDate(),
      startTime: data['startTime'] as String,
      endTime: data['endTime'] as String,
      isAvailable: data['isAvailable'] as bool? ?? true,
      bookedBy: data['bookedBy'] as String?,
      matchId: data['matchId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'recruiterId': recruiterId,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'isAvailable': isAvailable,
      if (bookedBy != null) 'bookedBy': bookedBy,
      if (matchId != null) 'matchId': matchId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String get timeDisplay => '$startTime - $endTime';
}

