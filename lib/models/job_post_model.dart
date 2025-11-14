enum JobPostStatus {
  pending,
  approved,
  rejected,
  flagged,
  expired,
}

class JobPostModel {
  final String id;
  final String employerId;
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final String location;
  final double? salary;
  final String salaryType; // 'hourly', 'daily', 'weekly', 'monthly'
  final DateTime postedAt;
  final DateTime? expiresAt;
  final JobPostStatus status;
  final String? rejectionReason;
  final int applicationCount;
  final int viewCount;
  final int flagCount;
  final String? submitterName;
  final String? submitterId;
  final Map<String, dynamic>? additionalInfo;

  JobPostModel({
    required this.id,
    required this.employerId,
    required this.title,
    required this.description,
    required this.category,
    required this.tags,
    required this.location,
    this.salary,
    required this.salaryType,
    required this.postedAt,
    this.expiresAt,
    required this.status,
    this.rejectionReason,
    this.applicationCount = 0,
    this.viewCount = 0,
    this.flagCount = 0,
    this.submitterName,
    this.submitterId,
    this.additionalInfo,
  });

  factory JobPostModel.fromJson(Map<String, dynamic> json) {
    return JobPostModel(
      id: json['id'] as String,
      employerId: json['employerId'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      tags: List<String>.from(json['tags'] as List),
      location: json['location'] as String,
      salary: json['salary'] as double?,
      salaryType: json['salaryType'] as String,
      postedAt: DateTime.parse(json['postedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      status: JobPostStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => JobPostStatus.pending,
      ),
      rejectionReason: json['rejectionReason'] as String?,
      applicationCount: json['applicationCount'] as int? ?? 0,
      viewCount: json['viewCount'] as int? ?? 0,
      flagCount: json['flagCount'] as int? ?? 0,
      submitterName: json['submitterName'] as String?,
      submitterId: json['submitterId'] as String?,
      additionalInfo: json['additionalInfo'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employerId': employerId,
      'title': title,
      'description': description,
      'category': category,
      'tags': tags,
      'location': location,
      'salary': salary,
      'salaryType': salaryType,
      'postedAt': postedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'status': status.toString().split('.').last,
      'rejectionReason': rejectionReason,
      'applicationCount': applicationCount,
      'viewCount': viewCount,
      'flagCount': flagCount,
      'submitterName': submitterName,
      'submitterId': submitterId,
      'additionalInfo': additionalInfo,
    };
  }
}

