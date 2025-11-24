import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;

  final String email;
  final String fullName;
  final String? phoneNumber;
  final String location;
  final String role;

  final String status;
  final bool isActive;
  final bool isSuspended;

  final bool profileCompleted;
  final bool acceptedTerms;
  final String? photoUrl;
  final String? cvUrl;

  final String professionalSummary;
  final String professionalProfile;
  final String workExperience;
  final String seeking;

  final Map<String, dynamic>? image;
  final Map<String, dynamic>? resume;

  final int reportCount;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.location,
    required this.role,

    required this.status,
    required this.isActive,
    required this.isSuspended,

    required this.profileCompleted,
    required this.acceptedTerms,
    required this.professionalSummary,
    required this.professionalProfile,
    required this.workExperience,
    required this.seeking,
    required this.reportCount,
    required this.createdAt,
    this.photoUrl,
    this.cvUrl,
    this.image,
    this.resume,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String docId) {
    String status = json['status'] ?? 'Active';
    
    // Check if user is deleted
    bool isDeleted = status == 'Deleted';
    
    // Get isActive from JSON, but if status is 'Deleted', force it to false
    bool isActive = isDeleted ? false : (json['isActive'] ?? (status != 'Non-active'));

    DateTime parseCreatedAt(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return UserModel(
      id: docId,
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      phoneNumber: json['phoneNumber'],
      location: json['location'] ?? '',
      role: json['role'] ?? 'employee',

      status: status,
      isActive: isActive,
      isSuspended: status == 'Suspended',

      profileCompleted: json['profileCompleted'] ?? false,
      acceptedTerms: json['acceptedTerms'] ?? false,

      photoUrl: json['photoUrl'],
      cvUrl: json['cvUrl'],

      professionalSummary: json['professionalSummary'] ?? '',
      professionalProfile: json['professionalProfile'] ?? '',
      workExperience: json['workExperience'] ?? '',
      seeking: json['seeking'] ?? '',
      reportCount: (json['reportCount'] ?? 0).toInt(),

      createdAt: parseCreatedAt(json['createdAt']),

      image: json['image'],
      resume: json['resume'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'location': location,
      'role': role,

      'status': status,

      'profileCompleted': profileCompleted,
      'acceptedTerms': acceptedTerms,

      'photoUrl': photoUrl,
      'cvUrl': cvUrl,

      'professionalSummary': professionalSummary,
      'professionalProfile': professionalProfile,
      'workExperience': workExperience,
      'seeking': seeking,

      'reportCount': reportCount,
      'createdAt': createdAt,

      'image': image,
      'resume': resume,
    };
  }

}
