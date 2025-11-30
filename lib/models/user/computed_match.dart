import 'post.dart';

class ComputedMatch {
  final Post post; 
  final String recruiterFullName; 
  final String recruiterId; 
  final int matchPercentage;
  final List<String> matchedSkills;
  final String matchingStrategy;
  final DateTime computedAt;

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

