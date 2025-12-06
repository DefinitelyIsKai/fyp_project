
import 'package:cloud_firestore/cloud_firestore.dart';

enum JobType { weekdays, weekends, morning, afternoon, night, fullDay, onCall }

enum PostStatus { pending, active, completed, deleted, rejected }

class Post {
  final String id;
  final String ownerId; 
  String title;
  String description;
  double? budgetMin;
  double? budgetMax;
  String location;
  double? latitude;
  double? longitude;
  String event;
  JobType jobType;
  List<String> tags;
  List<String> requiredSkills;
  int? minAgeRequirement;
  int? maxAgeRequirement;
  int? applicantQuota;
  List<String> attachments;
  bool isDraft;
  PostStatus status;
  DateTime? completedAt;
  DateTime createdAt;
  DateTime? eventStartDate;
  DateTime? eventEndDate;
  String? workTimeStart; 
  String? workTimeEnd; 
  String? genderRequirement; 
  String? rejectionReason; 
  int views;
  int applicants;

  Post({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    this.budgetMin,
    this.budgetMax,
    this.location = '',
    this.latitude,
    this.longitude,
    this.event = '',
    this.jobType = JobType.weekdays,
    List<String>? tags,
    List<String>? requiredSkills,
    this.minAgeRequirement,
    this.maxAgeRequirement,
    this.applicantQuota,
    List<String>? attachments,
    this.isDraft = false,
    this.status = PostStatus.active,
    this.completedAt,
    DateTime? createdAt,
    this.eventStartDate,
    this.eventEndDate,
    this.workTimeStart,
    this.workTimeEnd,
    this.genderRequirement,
    this.rejectionReason,
    this.views = 0,
    this.applicants = 0,
  })  : tags = tags ?? <String>[],
        attachments = attachments ?? <String>[],
        requiredSkills = requiredSkills ?? <String>[],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'event': event,
      'jobType': jobType.name,
      'tags': tags,
      'requiredSkills': requiredSkills,
      'minAgeRequirement': minAgeRequirement,
      'maxAgeRequirement': maxAgeRequirement,
      'applicantQuota': applicantQuota,
      'attachments': attachments,
      'isDraft': isDraft,
      'status': status.name,
      'completedAt': completedAt,
      'eventStartDate': eventStartDate,
      'eventEndDate': eventEndDate,
      'workTimeStart': workTimeStart,
      'workTimeEnd': workTimeEnd,
      'genderRequirement': genderRequirement,
      'rejectionReason': rejectionReason,
      'createdAt': createdAt,
      'views': views,
      'applicants': applicants,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map) {
    try {
      return Post(
        id: map['id'] as String,
        ownerId: (map['ownerId'] as String?) ?? '',
        title: (map['title'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        budgetMin: (map['budgetMin'] as num?)?.toDouble(),
        budgetMax: (map['budgetMax'] as num?)?.toDouble(),
        location: (map['location'] as String?) ?? '',
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        event: (map['event'] as String?) ?? '',
        jobType: JobType.values.firstWhere(
          (e) => e.name == (map['jobType'] as String? ?? JobType.weekdays.name),
          orElse: () => JobType.weekdays,
        ),
        tags: (map['tags'] as List?)?.cast<String>() ?? <String>[],
        requiredSkills: (map['requiredSkills'] as List?)?.cast<String>() ?? <String>[],
        minAgeRequirement: _parseInt(map['minAgeRequirement']),
        maxAgeRequirement: _parseInt(map['maxAgeRequirement']),
        applicantQuota: _parseInt(map['applicantQuota']),
        attachments: (map['attachments'] as List?)?.cast<String>() ?? <String>[],
        isDraft: (map['isDraft'] as bool?) ?? false,
        status: PostStatus.values.firstWhere(
          (e) => e.name == ((map['status'] as String?) ?? PostStatus.active.name),
          orElse: () => PostStatus.active,
        ),
        completedAt: (map['completedAt'] is Timestamp)
            ? (map['completedAt'] as Timestamp).toDate()
            : (map['completedAt'] as DateTime?),
        eventStartDate: (map['eventStartDate'] is Timestamp)
            ? (map['eventStartDate'] as Timestamp).toDate()
            : (map['eventStartDate'] as DateTime?),
        eventEndDate: (map['eventEndDate'] is Timestamp)
            ? (map['eventEndDate'] as Timestamp).toDate()
            : (map['eventEndDate'] as DateTime?),
        workTimeStart: map['workTimeStart'] as String?,
        workTimeEnd: map['workTimeEnd'] as String?,
        genderRequirement: map['genderRequirement'] as String?,
        rejectionReason: map['rejectionReason'] as String?,
        createdAt: (map['createdAt'] is Timestamp)
            ? (map['createdAt'] as Timestamp).toDate()
            : (map['createdAt'] as DateTime?) ?? DateTime.now(),
      views: _parseInt(map['views']) ?? 0,
      applicants: _parseInt(map['applicants']) ?? 0,
      );
    } catch (e) {
      throw FormatException(
        'Failed to parse Post from Firestore data: $e\n'
        'Field causing error: Check minAgeRequirement, maxAgeRequirement, applicantQuota, views, or applicants fields.\n'
        'These fields may be stored as double instead of int in Firestore.',
        e,
      );
    }
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

extension JobTypeDisplay on JobType {
  String get label {
    switch (this) {
      case JobType.weekdays:
        return 'Weekdays';
      case JobType.weekends:
        return 'Weekends';
      case JobType.morning:
        return 'Morning';
      case JobType.afternoon:
        return 'Afternoon';
      case JobType.night:
        return 'Night';
      case JobType.fullDay:
        return 'Full Day';
      case JobType.onCall:
        return 'On-Call / Short Notice';
    }
  }
}


