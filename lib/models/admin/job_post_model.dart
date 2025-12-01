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
  final String? ownerId;
  final List<String> tags;
  final List<String> requiredSkills;
  final String? rejectionReason;
  
  final int? applicantQuota;
  final int? applicants;
  final int? approvedApplicants;
  final List<String>? attachments;
  final DateTime? completedAt;
  final String? event;
  final DateTime? eventStartDate;
  final DateTime? eventEndDate;
  final bool? isDraft;
  final double? latitude;
  final double? longitude;
  final int? minAgeRequirement;
  final int? maxAgeRequirement;
  final String? workTimeStart;
  final String? workTimeEnd;
  final String? genderRequirement;
  final int? views;

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
    this.ownerId,
    required this.tags,
    required this.requiredSkills,
    this.rejectionReason,
    this.applicantQuota,
    this.applicants,
    this.approvedApplicants,
    this.attachments,
    this.completedAt,
    this.event,
    this.eventStartDate,
    this.eventEndDate,
    this.isDraft,
    this.latitude,
    this.longitude,
    this.minAgeRequirement,
    this.maxAgeRequirement,
    this.workTimeStart,
    this.workTimeEnd,
    this.genderRequirement,
    this.views,
  });

  factory JobPostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    DateTime? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }
    
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
      createdAt: parseTimestamp(data['createdAt']) ?? DateTime.now(),
      submitterName: data['submitterName'],
      ownerId: data['ownerId'],
      tags: List<String>.from(data['tags'] ?? []),
      requiredSkills: List<String>.from(data['requiredSkills'] ?? []),
      rejectionReason: data['rejectionReason'],
      applicantQuota: data['applicantQuota'] != null ? (data['applicantQuota'] as num).toInt() : null,
      applicants: data['applicants'] != null ? (data['applicants'] as num).toInt() : null,
      approvedApplicants: data['approvedApplicants'] != null ? (data['approvedApplicants'] as num).toInt() : null,
      attachments: data['attachments'] != null ? List<String>.from(data['attachments']) : null,
      completedAt: parseTimestamp(data['completedAt']),
      event: data['event'],
      eventStartDate: parseTimestamp(data['eventStartDate']),
      eventEndDate: parseTimestamp(data['eventEndDate']),
      isDraft: data['isDraft'] as bool?,
      latitude: data['latitude'] != null ? (data['latitude'] as num).toDouble() : null,
      longitude: data['longitude'] != null ? (data['longitude'] as num).toDouble() : null,
      minAgeRequirement: data['minAgeRequirement'] != null ? (data['minAgeRequirement'] as num).toInt() : null,
      maxAgeRequirement: data['maxAgeRequirement'] != null ? (data['maxAgeRequirement'] as num).toInt() : null,
      workTimeStart: data['workTimeStart'] as String?,
      workTimeEnd: data['workTimeEnd'] as String?,
      genderRequirement: data['genderRequirement'] as String?,
      views: data['views'] != null ? (data['views'] as num).toInt() : null,
    );
  }
}
