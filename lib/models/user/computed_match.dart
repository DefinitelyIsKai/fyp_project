/// ComputedMatch represents a real-time computed match result.
/// This is used for displaying matches without storing them in Firestore.
import 'post.dart';

class ComputedMatch {
  final Post post; // The matched job post
  final String recruiterFullName; // Recruiter's full name
  final String recruiterId; // Recruiter's user ID
  final int matchPercentage; // Match score (0-100)
  final List<String> matchedSkills; // Skills that matched
  final String matchingStrategy; // Strategy used (e.g., 'embedding_ann')
  final DateTime computedAt; // When this match was computed

  ComputedMatch({
    required this.post,
    required this.recruiterFullName,
    required this.recruiterId,
    required this.matchPercentage,
    required this.matchedSkills,
    required this.matchingStrategy,
    DateTime? computedAt,
  }) : computedAt = computedAt ?? DateTime.now();

}

