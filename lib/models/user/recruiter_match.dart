/// RecruiterMatch represents a real-time computed match result for recruiters.
/// This shows which applicants match a specific job post.
import 'application.dart';

class RecruiterMatch {
  final Application application; // The application from jobseeker
  final String jobseekerName; // Jobseeker's display name
  final String jobseekerId; // Jobseeker's user ID
  final int matchPercentage; // Match score (0-100)
  final List<String> matchedSkills; // Skills that matched
  final String matchingStrategy; // Strategy used (e.g., 'embedding_ann')
  final DateTime computedAt; // When this match was computed

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

