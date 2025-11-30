import 'application.dart';

class RecruiterMatch {
  final Application application; 
  final String jobseekerName; 
  final String jobseekerId; 
  final int matchPercentage; 
  final List<String> matchedSkills; 
  final String matchingStrategy; 
  final DateTime computedAt; 

  RecruiterMatch({
    required this.application,
    required this.jobseekerName,
    required this.jobseekerId,
    required this.matchPercentage,
    required this.matchedSkills,
    required this.matchingStrategy,
    DateTime? computedAt,
  }) : computedAt = computedAt ?? DateTime.now();
}

