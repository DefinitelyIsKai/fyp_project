import 'package:cloud_firestore/cloud_firestore.dart';

class JobPostModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final String category;
  final String location;
  final String industry;
  final String jobType;
  final double? budgetMin;
  final double? budgetMax;
  final DateTime createdAt;
  final String? submitterName;
  final List<String> tags;
  final List<String> requiredSkills;
  final String? rejectionReason;

  JobPostModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.category,
    required this.location,
    required this.industry,
    required this.jobType,
    this.budgetMin,
    this.budgetMax,
    required this.createdAt,
    this.submitterName,
    required this.tags,
    required this.requiredSkills,
    this.rejectionReason,
  });

  factory JobPostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobPostModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? 'pending',
      category: data['category'] ?? '',
      location: data['location'] ?? '',
      industry: data['industry'] ?? '',
      jobType: data['jobType'] ?? '',
      budgetMin: data['budgetMin'] != null
          ? (data['budgetMin'] as num).toDouble()
          : null,
      budgetMax: data['budgetMax'] != null
          ? (data['budgetMax'] as num).toDouble()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),

      submitterName: data['ownerId'],

      tags: List<String>.from(data['tags'] ?? []),
      requiredSkills: List<String>.from(data['requiredSkills'] ?? []),

      rejectionReason: data['rejectionReason'],
    );
  }
}
