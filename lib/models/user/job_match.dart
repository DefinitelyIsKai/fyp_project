/// JobMatch model used as an adapter between Application and booking system.
/// Note: This system uses 'applications' collection, not 'job_matches'.
/// JobMatch is created from Application objects for compatibility with booking system.
class JobMatch {
  // Fields used in booking system (when created from Application)
  final String id; // Used for matchId in booking requests
  final String jobTitle; // Used in booking dialog and header
  final String companyName; // Used in slot display
  final String recruiterId; // Used for filtering slots
  final String status; // Used for filtering (always 'accepted' when from Application)
  
  // Optional fields only used in matching_interaction_page (which shows empty results)
  final int? matchPercentage; // Only for matching engine display
  final List<String>? matchedSkills; // Only for matching engine display
  final String? candidateName; // Only for matching engine display
  final String? matchingStrategy; // Only for matching engine display
  final DateTime? createdAt; // Only for matching engine display

  JobMatch({
    required this.id,
    required this.jobTitle,
    required this.companyName,
    required this.recruiterId,
    required this.status,
    this.matchPercentage,
    this.matchedSkills,
    this.candidateName,
    this.matchingStrategy,
    this.createdAt,
  });

}
