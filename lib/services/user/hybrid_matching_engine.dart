import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../../models/user/post.dart';
import '../../models/user/tag.dart';
import '../../models/user/tag_category.dart';
import '../../models/user/computed_match.dart';
import '../../models/user/recruiter_match.dart';
import '../../models/user/application.dart';
import 'auth_service.dart';
import 'tag_service.dart';
import 'application_service.dart';
import '../../utils/user/tag_definitions.dart';

/// Matching strategy enum
enum MatchingStrategy {
  embeddingsAnn,      // Strategy A: Quick recommendation (many-to-many)
  stableOptimal,      // Strategy B: Precise matching (one-to-one)
}

/// Matching weights configuration class
class _MatchingWeights {
  const _MatchingWeights({
    required this.textSimilarity,
    required this.tagMatching,
    required this.requiredSkills,
    required this.distance,
    required this.jobTypePreference,
    required this.maxDistanceKm,
    required this.decayFactor,
  });

  final double textSimilarity;
  final double tagMatching;
  final double requiredSkills;
  final double distance;
  final double jobTypePreference;
  final double maxDistanceKm;
  final double decayFactor;
}

// Default weights (fallback if rules not found or disabled)
const _defaultWeights = _MatchingWeights(
  textSimilarity: 0.35,
  tagMatching: 0.35,
  requiredSkills: 0.15,
  distance: 0.10,
  jobTypePreference: 0.02,
  maxDistanceKm: 50.0,
  decayFactor: 3.0,
);

/// A hybrid matching engine that supports Content-Based Filtering:
/// - Embeddings + ANN: Fast similarity search
/// - Weighted Sorting: Optimal ranking based on bidirectional preferences
class HybridMatchingEngine {
  HybridMatchingEngine({
    FirebaseFirestore? firestore,
    AuthService? authService,
    TagService? tagService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authService = authService ?? AuthService(),
        _tagService = tagService ?? TagService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final AuthService _authService;
  final TagService _tagService;

  // Cache for tag categories and tags
  Map<TagCategory, List<Tag>>? _cachedTagData;
  DateTime? _cacheTimestamp;
  static const _cacheExpiryDuration = Duration(minutes: 30);
  static const int _maxJobsPerRecruiter = 25;
  static const int _maxCandidatesPerRecruiter = 60;

  // Cache for matching rule weights (static to share across all instances)
  static _MatchingWeights? _cachedWeights;
  static DateTime? _weightsCacheTimestamp;
  static const _weightsCacheExpiryDuration = Duration(minutes: 15);

  // Cache for candidate reliability scores
  final Map<String, _CachedReliability> _reliabilityCache = {};
  static const _reliabilityCacheExpiryDuration = Duration(minutes: 30);

  /// Fetch tag categories and tags from Firestore with caching
  Future<Map<TagCategory, List<Tag>>> _getTagData() async {
    final now = DateTime.now();
    if (_cachedTagData != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!) < _cacheExpiryDuration) {
      return _cachedTagData!;
    }

    try {
      final tagData = await _tagService.getActiveTagCategoriesWithTags();
      _cachedTagData = tagData;
      _cacheTimestamp = now;
      return tagData;
    } catch (e) {
      // Return cached data if available, otherwise empty map
      return _cachedTagData ?? {};
    }
  }

  /// Fetch matching rule weights from Firestore with caching
  Future<_MatchingWeights> _getMatchingWeights() async {
    final now = DateTime.now();
    
    // Safety check: ensure _weightsCacheTimestamp is a valid DateTime
    if (_cachedWeights != null &&
        _weightsCacheTimestamp != null) {
      try {
        // Verify timestamp is actually a DateTime
        if (_weightsCacheTimestamp is! DateTime) {
          debugPrint('Warning: _weightsCacheTimestamp is not DateTime, clearing cache');
          _cachedWeights = null;
          _weightsCacheTimestamp = null;
        } else if (now.difference(_weightsCacheTimestamp!) < _weightsCacheExpiryDuration) {
          debugPrint('Using cached weights (age: ${now.difference(_weightsCacheTimestamp!).inSeconds}s)');
          debugPrint('Cached weights: textSimilarity=${_cachedWeights!.textSimilarity}, tagMatching=${_cachedWeights!.tagMatching}, requiredSkills=${_cachedWeights!.requiredSkills}, distance=${_cachedWeights!.distance}');
          return _cachedWeights!;
        } else {
          debugPrint('Cache expired (age: ${now.difference(_weightsCacheTimestamp!).inSeconds}s), fetching fresh weights');
        }
      } catch (e) {
        debugPrint('Error checking cache timestamp: $e, clearing cache');
        _cachedWeights = null;
        _weightsCacheTimestamp = null;
      }
    }

    try {
      debugPrint('=== Fetching weights from Firestore ===');
      // Get ALL rules (both enabled and disabled) to check their status
      final snapshot = await _firestore
          .collection('matching_rules')
          .get();

      debugPrint('Found ${snapshot.docs.length} total rules in Firestore');

      // Initialize all weights to 0 (disabled by default)
      // Only enabled rules will have their weights applied
      double textSimilarity = 0.0;
      double tagMatching = 0.0;
      double requiredSkills = 0.0;
      double distance = 0.0;
      double jobTypePreference = 0.0;
      double maxDistanceKm = _defaultWeights.maxDistanceKm;
      double decayFactor = _defaultWeights.decayFactor;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final ruleId = doc.id;
        final isEnabled = data['isEnabled'] as bool? ?? false;
        final weight = (data['weight'] as num?)?.toDouble() ?? 0.0;
        final parameters = Map<String, dynamic>.from(data['parameters'] ?? {});

        // Only apply weight if rule is enabled
        if (!isEnabled) {
          debugPrint('Rule $ruleId: DISABLED (weight=0.0)');
          continue;
        }

        debugPrint('Rule $ruleId: ENABLED, weight=$weight (from Firestore)');

        switch (ruleId) {
          case 'text_similarity':
            textSimilarity = weight;
            break;
          case 'tag_matching':
            tagMatching = weight;
            break;
          case 'required_skills':
            requiredSkills = weight;
            break;
          case 'distance':
            distance = weight;
            maxDistanceKm = (parameters['maxDistanceKm'] as num?)?.toDouble() ?? maxDistanceKm;
            decayFactor = (parameters['decayFactor'] as num?)?.toDouble() ?? decayFactor;
            break;
          case 'job_type_preference':
            jobTypePreference = weight;
            break;
        }
      }

      final weights = _MatchingWeights(
        textSimilarity: textSimilarity,
        tagMatching: tagMatching,
        requiredSkills: requiredSkills,
        distance: distance,
        jobTypePreference: jobTypePreference,
        maxDistanceKm: maxDistanceKm,
        decayFactor: decayFactor,
      );

      // Debug: Log loaded weights
      debugPrint('=== Matching Weights Loaded ===');
      debugPrint('textSimilarity: ${weights.textSimilarity}');
      debugPrint('tagMatching: ${weights.tagMatching}');
      debugPrint('requiredSkills: ${weights.requiredSkills}');
      debugPrint('distance: ${weights.distance}');
      debugPrint('jobTypePreference: ${weights.jobTypePreference}');
      debugPrint('maxDistanceKm: ${weights.maxDistanceKm}');
      debugPrint('decayFactor: ${weights.decayFactor}');
      debugPrint('================================');

      _cachedWeights = weights;
      _weightsCacheTimestamp = now;
      return weights;
    } catch (e) {
      // Return cached weights if available, otherwise defaults
      return _cachedWeights ?? _defaultWeights;
    }
  }

  /// Clear the cached matching weights to force refresh from Firestore
  /// This is useful when matching rules are updated and you want immediate effect
  /// Static method to clear cache across ALL instances
  static void clearWeightsCache() {
    final hadCache = _cachedWeights != null;
    _cachedWeights = null;
    _weightsCacheTimestamp = null;
    debugPrint('=== Matching Weights Cache Cleared ===');
    debugPrint('Had cached weights: $hadCache');
    debugPrint('Cache cleared at: ${DateTime.now()}');
    debugPrint('Next _getMatchingWeights() call will fetch from Firestore');
    debugPrint('======================================');
  }
  
  /// Reset all static caches (for debugging/recovery)
  static void resetAllCaches() {
    _cachedWeights = null;
    _weightsCacheTimestamp = null;
    debugPrint('All matching caches reset');
  }

  /// Get category IDs that represent skill-related tags
  Future<Set<String>> _getSkillCategoryIds() async {
    final tagData = await _getTagData();
    final skillKeywords = ['skill', 'technical', 'soft skill'];
    return tagData.keys
        .where((category) => skillKeywords.any(
            (keyword) => category.title.toLowerCase().contains(keyword)))
        .map((category) => category.id)
        .toSet();
  }

  /// Get category IDs that represent job preference tags
  Future<Set<String>> _getJobPreferenceCategoryIds() async {
    final tagData = await _getTagData();
    final prefKeywords = ['preference', 'job type', 'work type'];
    return tagData.keys
        .where((category) => prefKeywords.any(
            (keyword) => category.title.toLowerCase().contains(keyword)))
        .map((category) => category.id)
        .toSet();
  }

  /// Get category IDs that represent location tags
  Future<Set<String>> _getLocationCategoryIds() async {
    final tagData = await _getTagData();
    final locationKeywords = ['location', 'place'];
    return tagData.keys
        .where((category) => locationKeywords.any(
            (keyword) => category.title.toLowerCase().contains(keyword)))
        .map((category) => category.id)
        .toSet();
  }

  Future<void> recomputeMatches({
    String? explicitRole,
    MatchingStrategy strategy = MatchingStrategy.embeddingsAnn,
  }) async {
    final userDoc = await _authService.getUserDoc();
    final userId = userDoc.id;
    final data = userDoc.data() ?? <String, dynamic>{};
    final role = explicitRole ?? (data['role'] as String? ?? 'jobseeker');

    if (role == 'recruiter') {
      await _runRecruiterPipeline(userId, strategy);
    } else {
      await _runJobseekerPipeline(userId, data);
    }
  }

  Future<void> _runJobseekerPipeline(
    String userId,
    Map<String, dynamic> data,
  ) async {
    // Fetch matching weights from Firestore
    final weights = await _getMatchingWeights();
    
    // Fetch tag data for matching
    final tagData = await _getTagData();
    final skillCategoryIds = await _getSkillCategoryIds();
    final jobPreferenceCategoryIds = await _getJobPreferenceCategoryIds();
    final locationCategoryIds = await _getLocationCategoryIds();

    final candidate = await _CandidateProfile.fromUserDataWithTagData(
      userId,
      data,
      tagData,
      skillCategoryIds,
      jobPreferenceCategoryIds,
      locationCategoryIds,
    );
    if (!candidate.isMatchable) return;

    final jobs = await _loadActiveJobs();
    if (jobs.isEmpty) return;

    // filter ages
    final ageFilteredJobs = jobs.where((job) {
      if (candidate.age == null) {
        // If candidate age is not set, only include jobs without age requirements
        return job.minAgeRequirement == null && job.maxAgeRequirement == null;
      }
      final candidateAge = candidate.age!;
      // Job must not have age requirements, or candidate age must be within range
      if (job.minAgeRequirement != null && candidateAge < job.minAgeRequirement!) {
        return false;
      }
      if (job.maxAgeRequirement != null && candidateAge > job.maxAgeRequirement!) {
        return false;
      }
      return true;
    }).toList();

    if (ageFilteredJobs.isEmpty) return;

    //filter genderss
    final genderFilteredJobs = ageFilteredJobs.where((job) {
      return _meetsGenderRequirement(candidate, job);
    }).toList();

    if (genderFilteredJobs.isEmpty) return;

    final recruiterLabels = await _fetchUserLabels(
      genderFilteredJobs.map((job) => job.ownerId).toSet(),
    );

    final jobVectors = genderFilteredJobs
        .map(
          (job) => _JobVector.fromPost(
            job,
            recruiterLabels[job.ownerId] ?? 'Hiring Company',
          ),
        )
        .toList();

    // Step 2: Use Embeddings + ANN for initial filtering based on tags/skills similarity
    final annMatcher = _EmbeddingAnnMatcher<_JobVector>();
    final annNeighbors = annMatcher.findNearest(
      query: candidate.featureVector,
      items: jobVectors,
      topK: 32,
    );

    final pendingMatches = <_PendingMatch>[];
    for (final neighbor in annNeighbors) {
      final similarity = neighbor.similarity;
      final jobVector = neighbor.payload;
      final score = await _scoreJobseekerMatch(candidate, jobVector, similarity, weights);
      if (score <= 0.05) continue;

      final matchedSkills = _matchedSkills(
        candidate.skillSet,
        jobVector.requiredSkills,
      );

      pendingMatches.add(
        _PendingMatch(
          job: jobVector.post,
          recruiterLabel: jobVector.recruiterLabel,
          candidateId: candidate.id,
          candidateName: candidate.displayName,
          matchedSkills: matchedSkills,
          score: score,
          strategy: 'embedding_ann',
        ),
      );
    }

    // No longer persisting to job_matches - using real-time computation instead
    // The matches are computed on-demand via computeMatchesForJobseeker()
  }

  /// Compute matches in real-time without persisting to Firestore.
  /// Returns list of ComputedMatch objects for display.
  Future<List<ComputedMatch>> computeMatchesForJobseeker({
    required String userId,
    Map<String, dynamic>? userData,
  }) async {
    // Fetch user data if not provided
    Map<String, dynamic> data;
    if (userData != null) {
      data = userData;
    } else {
      final userDoc = await _authService.getUserDoc();
      data = userDoc.data() ?? <String, dynamic>{};
    }

    // Fetch matching weights from Firestore
    final weights = await _getMatchingWeights();
    
    // Fetch tag data for matching
    final tagData = await _getTagData();
    final skillCategoryIds = await _getSkillCategoryIds();
    final jobPreferenceCategoryIds = await _getJobPreferenceCategoryIds();
    final locationCategoryIds = await _getLocationCategoryIds();

    final candidate = await _CandidateProfile.fromUserDataWithTagData(
      userId,
      data,
      tagData,
      skillCategoryIds,
      jobPreferenceCategoryIds,
      locationCategoryIds,
    );
    if (!candidate.isMatchable) return [];

    final jobs = await _loadActiveJobs();
    if (jobs.isEmpty) return [];

    // Filter out jobs created by the jobseeker themselves
    final filteredJobs = jobs.where((job) => job.ownerId != userId).toList();
    if (filteredJobs.isEmpty) return [];

    // Get all pending applications for this jobseeker
    final allApplications = await FirebaseFirestore.instance
        .collection('applications')
        .where('jobseekerId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    
    final appliedPostIds = allApplications.docs
        .map((doc) => doc.data()['postId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    // Filter out jobs that the jobseeker has already applied to (pending status)
    final availableJobs = filteredJobs.where((job) => !appliedPostIds.contains(job.id)).toList();
    if (availableJobs.isEmpty) return [];

    // Filter out quota-full posts (batch fetch quota data)
    final postIdsWithQuota = availableJobs
        .where((job) => job.applicantQuota != null)
        .map((job) => job.id)
        .toList();
    
    final quotaData = <String, int>{};
    if (postIdsWithQuota.isNotEmpty) {
      final postDocs = await Future.wait(
        postIdsWithQuota.map((id) => 
          FirebaseFirestore.instance.collection('posts').doc(id).get()
        ),
      );
      
      for (final doc in postDocs) {
        if (doc.exists) {
          final data = doc.data() ?? {};
          final approvedApplicants = data['approvedApplicants'] as int? ?? 0;
          quotaData[doc.id] = approvedApplicants;
        }
      }
    }

    // Filter out quota-full posts
    final validJobs = availableJobs.where((job) {
      // Double-check status (should already be filtered by _loadActiveJobs)
      if (job.status != PostStatus.active) return false;
      
      // Check quota if applicable
      if (job.applicantQuota != null) {
        final approvedCount = quotaData[job.id] ?? 0;
        if (approvedCount >= job.applicantQuota!) {
          return false; // Quota is full
        }
      }
      
      return true;
    }).toList();
    
    if (validJobs.isEmpty) return [];

    // Step 1: Filter jobs by age requirement (hard filter - must pass)
    final ageFilteredJobs = validJobs.where((job) {
      if (candidate.age == null) {
        return job.minAgeRequirement == null && job.maxAgeRequirement == null;
      }
      final candidateAge = candidate.age!;
      if (job.minAgeRequirement != null && candidateAge < job.minAgeRequirement!) {
        return false;
      }
      if (job.maxAgeRequirement != null && candidateAge > job.maxAgeRequirement!) {
        return false;
      }
      return true;
    }).toList();

    if (ageFilteredJobs.isEmpty) return [];

    // Step 1.5: Filter jobs by gender requirement (hard filter - must pass)
    final genderFilteredJobs = ageFilteredJobs.where((job) {
      return _meetsGenderRequirement(candidate, job);
    }).toList();

    if (genderFilteredJobs.isEmpty) return [];

    final recruiterLabels = await _fetchUserLabels(
      genderFilteredJobs.map((job) => job.ownerId).toSet(),
    );

    final jobVectors = genderFilteredJobs
        .map(
          (job) => _JobVector.fromPost(
            job,
            recruiterLabels[job.ownerId] ?? 'Hiring Company',
          ),
        )
        .toList();

    // Step 2: Use weighted sorting for optimal matching (Jobseeker perspective)
    final optimalMatches = await _runJobseekerOptimalMatching(
      candidate,
      jobVectors,
      weights,
    );

    // Convert to ComputedMatch list
    final computedMatches = <ComputedMatch>[];
    for (final match in optimalMatches) {
      final matchedSkills = _matchedSkills(
        candidate.skillSet,
        match.job.requiredSkills,
      );

      computedMatches.add(
        ComputedMatch(
          post: match.job.post,
          recruiterFullName: match.job.recruiterLabel,
          recruiterId: match.job.post.ownerId,
          matchPercentage: (match.score * 100).clamp(1, 100).round(),
          matchedSkills: matchedSkills,
          matchingStrategy: 'cbf_topk',
        ),
      );
    }

    // Sort by match percentage (descending)
    computedMatches.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
    return computedMatches;
  }

  /// Compute matches for a specific job post and its applicants.
  /// Returns list of RecruiterMatch objects showing which applicants match the post.
  Future<List<RecruiterMatch>> computeMatchesForRecruiterPost({
    required String postId,
    required String recruiterId,
    MatchingStrategy strategy = MatchingStrategy.embeddingsAnn,
  }) async {
    // Load the post
    final postDoc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
    if (!postDoc.exists) return [];
    
    final postData = postDoc.data() ?? {};
    final post = Post(
      id: postId,
      ownerId: recruiterId,
      title: postData['title'] as String? ?? '',
      description: postData['description'] as String? ?? '',
      budgetMin: (postData['budgetMin'] as num?)?.toDouble(),
      budgetMax: (postData['budgetMax'] as num?)?.toDouble(),
      location: postData['location'] as String? ?? '',
      latitude: (postData['latitude'] as num?)?.toDouble(),
      longitude: (postData['longitude'] as num?)?.toDouble(),
      event: postData['event'] as String? ?? '',
      jobType: _parseJobType(postData['jobType'] as String?),
      tags: (postData['tags'] as List?)?.cast<String>() ?? [],
      requiredSkills: (postData['requiredSkills'] as List?)?.cast<String>() ?? [],
      minAgeRequirement: postData['minAgeRequirement'] as int?,
      maxAgeRequirement: postData['maxAgeRequirement'] as int?,
      applicantQuota: postData['applicantQuota'] as int?,
      attachments: (postData['attachments'] as List?)?.cast<String>() ?? [],
      isDraft: postData['isDraft'] as bool? ?? false,
      status: _parsePostStatus(postData['status'] as String?),
      createdAt: (postData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      eventStartDate: (postData['eventStartDate'] as Timestamp?)?.toDate(),
      eventEndDate: (postData['eventEndDate'] as Timestamp?)?.toDate(),
      genderRequirement: postData['genderRequirement'] as String?,
      views: postData['views'] as int? ?? 0,
      applicants: postData['applicants'] as int? ?? 0,
    );

    // Get all applications for this post
    final applicationService = ApplicationService();
    final allApplications = await applicationService.getApplicationsByPostId(
      postId: postId,
      recruiterId: recruiterId,
    );
    
    debugPrint('Total applications found: ${allApplications.length}');
    debugPrint('Application statuses: ${allApplications.map((a) => a.status.toString()).join(", ")}');
    
    // Filter to show pending and approved applications (exclude rejected and deleted)
    final applications = allApplications.where((app) => 
      app.status == ApplicationStatus.pending || 
      app.status == ApplicationStatus.approved
    ).toList();
    
    debugPrint('Filtered applications (pending/approved): ${applications.length}');

    if (applications.isEmpty) {
      debugPrint('No applications found for post $postId');
      return [];
    }

    // Fetch matching weights
    final weights = await _getMatchingWeights();
    
    // Fetch tag data for matching
    final tagData = await _getTagData();
    final skillCategoryIds = await _getSkillCategoryIds();
    final jobPreferenceCategoryIds = await _getJobPreferenceCategoryIds();
    final locationCategoryIds = await _getLocationCategoryIds();

    // Load recruiter label
    final recruiterLabels = await _fetchUserLabels({recruiterId});
    final recruiterLabel = recruiterLabels[recruiterId] ?? 'Hiring Company';

    // Create job vector
    final jobVector = _JobVector.fromPost(post, recruiterLabel);

    // Load candidate profiles for all applicants
    final candidateProfiles = <_CandidateProfile>[];
    final jobseekerDataMap = <String, Map<String, dynamic>>{};
    
    for (final application in applications) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(application.jobseekerId)
            .get();
        final userData = userDoc.data() ?? {};
        jobseekerDataMap[application.jobseekerId] = userData;
        
        final candidate = await _CandidateProfile.fromUserDataWithTagData(
          application.jobseekerId,
          userData,
          tagData,
          skillCategoryIds,
          jobPreferenceCategoryIds,
          locationCategoryIds,
        );
        if (candidate.isMatchable) {
          candidateProfiles.add(candidate);
        } else {
          debugPrint('Candidate ${application.jobseekerId} is not matchable');
        }
      } catch (e) {
        debugPrint('Error loading candidate profile for ${application.jobseekerId}: $e');
      }
    }

    debugPrint('Matchable candidates: ${candidateProfiles.length}');
    if (candidateProfiles.isEmpty) {
      debugPrint('No matchable candidates found');
      return [];
    }

    // Filter candidates by age requirement
    final ageFilteredCandidates = candidateProfiles.where((candidate) {
      if (candidate.age == null) {
        return post.minAgeRequirement == null && post.maxAgeRequirement == null;
      }
      final candidateAge = candidate.age!;
      if (post.minAgeRequirement != null && candidateAge < post.minAgeRequirement!) {
        return false;
      }
      if (post.maxAgeRequirement != null && candidateAge > post.maxAgeRequirement!) {
        return false;
      }
      return true;
    }).toList();

    debugPrint('Age-filtered candidates: ${ageFilteredCandidates.length}');
    if (ageFilteredCandidates.isEmpty) {
      debugPrint('No candidates passed age filter');
      return [];
    }

    // Filter candidates by gender requirement
    final genderFilteredCandidates = ageFilteredCandidates.where((candidate) {
      return _meetsGenderRequirement(candidate, post);
    }).toList();

    debugPrint('Gender-filtered candidates: ${genderFilteredCandidates.length}');
    if (genderFilteredCandidates.isEmpty) {
      debugPrint('No candidates passed gender filter');
      return [];
    }

    // Use Embeddings + ANN for matching
    debugPrint('Job vector tokens: ${jobVector.featureVector.tokens.length}');
    debugPrint('Job vector tokens sample: ${jobVector.featureVector.tokens.take(5).join(", ")}');
    if (genderFilteredCandidates.isNotEmpty) {
      debugPrint('Candidate vector tokens: ${genderFilteredCandidates.first.featureVector.tokens.length}');
      debugPrint('Candidate vector tokens sample: ${genderFilteredCandidates.first.featureVector.tokens.take(5).join(", ")}');
    }
    
    final annMatcher = _EmbeddingAnnMatcher<_CandidateProfile>();
    final annNeighbors = annMatcher.findNearest(
      query: jobVector.featureVector,
      items: genderFilteredCandidates,
      topK: genderFilteredCandidates.length, // Match all candidates
    );

    debugPrint('ANN neighbors found: ${annNeighbors.length}');
    
    // If ANN returns no results, fallback to direct matching
    if (annNeighbors.isEmpty && genderFilteredCandidates.isNotEmpty) {
      debugPrint('ANN returned no results, using fallback direct matching');
      // Direct cosine similarity calculation as fallback
      for (final candidate in genderFilteredCandidates) {
        final similarity = jobVector.featureVector.cosine(candidate.featureVector);
        debugPrint('Direct similarity for candidate ${candidate.id}: $similarity');
        if (!similarity.isNaN && similarity > 0) {
          annNeighbors.add(_AnnNeighbor(payload: candidate, similarity: similarity));
        }
      }
      debugPrint('Fallback neighbors found: ${annNeighbors.length}');
    }
    // Calculate scores for all candidates
    final candidateScores = <_CandidateProfile, double>{};
    for (final neighbor in annNeighbors) {
      final candidate = neighbor.payload;
      final similarity = neighbor.similarity;
      var score = await _scoreRecruiterMatch(jobVector, candidate, similarity, weights);
      
      // Apply reliability coefficient for stableOptimal strategy
      if (strategy == MatchingStrategy.stableOptimal) {
        final reliabilityScore = await _getReliabilityScore(candidate.id);
        score = score * reliabilityScore;
        debugPrint('Candidate ${candidate.id} - Base Score: ${score / reliabilityScore}, Reliability: $reliabilityScore, Final Score: $score');
      } else {
        debugPrint('Candidate ${candidate.id} - Score: $score, Similarity: $similarity');
      }
      
      // Use different thresholds based on strategy
      final minScore = strategy == MatchingStrategy.stableOptimal ? 0.20 : 0.05;
      if (score > minScore) {
        candidateScores[candidate] = score;
      } else {
        debugPrint('Candidate ${candidate.id} score too low (${score.toStringAsFixed(3)} < $minScore), skipping');
      }
    }

    // Apply strategy-based filtering
    List<_CandidateProfile> selectedCandidates;
    if (strategy == MatchingStrategy.stableOptimal) {
      // One candidate per job: select the highest scoring candidate
      if (candidateScores.isEmpty) {
        debugPrint('No candidates with valid scores for stable optimal matching');
        return [];
      }
      final sortedCandidates = candidateScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      selectedCandidates = [sortedCandidates.first.key];
      debugPrint('Stable optimal: Selected 1 candidate (score: ${sortedCandidates.first.value})');
    } else {
      // Multiple candidates per job: include all candidates with valid scores
      selectedCandidates = candidateScores.keys.toList();
      debugPrint('Embeddings ANN: Selected ${selectedCandidates.length} candidates');
    }

    // Build RecruiterMatch list
    final recruiterMatches = <RecruiterMatch>[];
    for (final candidate in selectedCandidates) {
      final score = candidateScores[candidate]!;

      // Find the application for this candidate
      final application = applications.firstWhere(
        (app) => app.jobseekerId == candidate.id,
        orElse: () => applications.first, // Fallback (shouldn't happen)
      );

      final matchedSkills = _matchedSkills(
        candidate.skillSet,
        jobVector.requiredSkills,
      );

      // Get jobseeker name
      final jobseekerData = jobseekerDataMap[candidate.id] ?? {};
      final jobseekerName = (jobseekerData['fullName'] as String?) ??
          (jobseekerData['professionalProfile'] as String?) ??
          'Jobseeker';

      recruiterMatches.add(
        RecruiterMatch(
          application: application,
          jobseekerName: jobseekerName,
          jobseekerId: candidate.id,
          matchPercentage: (score * 100).clamp(1, 100).round(),
          matchedSkills: matchedSkills,
          matchingStrategy: strategy == MatchingStrategy.stableOptimal
              ? 'stable_optimal'
              : 'embedding_ann',
        ),
      );
    }

    // Sort by match percentage (descending)
    recruiterMatches.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
    return recruiterMatches;
  }

  /// Get count of matched applicants for a specific post (lightweight version).
  /// This is faster than computeMatchesForRecruiterPost as it only returns the count.
  /// Uses the same filtering logic (age, gender, score thresholds).
  Future<int> getMatchedApplicantCount({
    required String postId,
    required String recruiterId,
    MatchingStrategy strategy = MatchingStrategy.embeddingsAnn,
  }) async {
    // Reuse the same logic but only return count
    final matches = await computeMatchesForRecruiterPost(
      postId: postId,
      recruiterId: recruiterId,
      strategy: strategy,
    );
    return matches.length;
  }

  JobType _parseJobType(String? type) {
    if (type == null) return JobType.weekdays;
    try {
      return JobType.values.firstWhere((e) => e.name == type);
    } catch (e) {
      return JobType.weekdays;
    }
  }

  PostStatus _parsePostStatus(String? status) {
    if (status == null) return PostStatus.active;
    try {
      return PostStatus.values.firstWhere((e) => e.name == status);
    } catch (e) {
      return PostStatus.active;
    }
  }

  Future<void> _runRecruiterPipeline(
    String userId,
    MatchingStrategy strategy,
  ) async {
    // Fetch matching weights from Firestore
    final weights = await _getMatchingWeights();
    
    final jobs = await _loadRecruiterJobs(userId);
    if (jobs.isEmpty) return;

    final recruiterLabels = await _fetchUserLabels({userId});
    final jobVectors = jobs
        .map(
          (job) => _JobVector.fromPost(
            job,
            recruiterLabels[job.ownerId] ?? 'My Posting',
          ),
        )
        .toList();

    final candidateProfiles = await _loadCandidateProfiles();
    if (candidateProfiles.isEmpty) return;

    final annMatcher = _EmbeddingAnnMatcher<_CandidateProfile>();
    final compatibility = <String, Map<String, double>>{};

    for (final job in jobVectors) {
      // Step 1: Filter candidates by age requirement (hard filter)
      final ageFilteredCandidates = candidateProfiles.where((candidate) {
        if (candidate.age == null) {
          return job.post.minAgeRequirement == null && job.post.maxAgeRequirement == null;
        }
        final candidateAge = candidate.age!;
        if (job.post.minAgeRequirement != null && candidateAge < job.post.minAgeRequirement!) {
          return false;
        }
        if (job.post.maxAgeRequirement != null && candidateAge > job.post.maxAgeRequirement!) {
          return false;
        }
        return true;
      }).toList();

      if (ageFilteredCandidates.isEmpty) continue;

      // Step 1.5: Filter candidates by gender requirement (hard filter)
      final genderFilteredCandidates = ageFilteredCandidates.where((candidate) {
        return _meetsGenderRequirement(candidate, job.post);
      }).toList();

      if (genderFilteredCandidates.isEmpty) continue;

      // Step 2: Use Embeddings + ANN for initial filtering
      final annResults = annMatcher.findNearest(
        query: job.featureVector,
        items: genderFilteredCandidates,
        topK: 20,
      );

      if (annResults.isEmpty) continue;

      final scores = <String, double>{};
      for (final neighbor in annResults) {
        final candidate = neighbor.payload;
        final score = await _scoreRecruiterMatch(job, candidate, neighbor.similarity, weights);
        if (score <= 0.05) continue;
        scores[candidate.id] = score;
      }

      if (scores.isEmpty) continue;
      compatibility[job.post.id] = scores;
    }

    if (compatibility.isEmpty) return;

    final resolvedPairs = <String, String>{};

    // Simple score-based selection (all strategies use the same approach)
    for (final jobId in compatibility.keys) {
      final scores = compatibility[jobId]!;
      final sortedCandidates = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sortedCandidates.isNotEmpty && sortedCandidates.first.value > 0) {
        resolvedPairs[jobId] = sortedCandidates.first.key;
      }
    }

    if (resolvedPairs.isEmpty) return;

    final candidateById = {
      for (final candidate in candidateProfiles) candidate.id: candidate,
    };
    final jobById = {for (final job in jobVectors) job.post.id: job};

    final pendingMatches = <_PendingMatch>[];
    resolvedPairs.forEach((jobId, candidateId) {
      final candidate = candidateById[candidateId];
      final job = jobById[jobId];
      if (candidate == null || job == null) return;

      final score = compatibility[jobId]?[candidateId] ?? 0;
      if (score <= 0) return;

      pendingMatches.add(
        _PendingMatch(
          job: job.post,
          recruiterLabel: job.recruiterLabel,
          candidateId: candidate.id,
          candidateName: candidate.displayName,
          matchedSkills: _matchedSkills(candidate.skillSet, job.requiredSkills),
          score: score,
          strategy: strategy == MatchingStrategy.stableOptimal
              ? 'stable_optimal'
              : 'embedding_ann',
        ),
      );
    });

    // No longer persisting to job_matches - using real-time computation instead
    // await _persistMatches(pendingMatches);
  }

  /// Run optimal matching for a single jobseeker using weighted sorting
  /// This function uses Content-Based Filtering with bidirectional preferences
  Future<List<_JobseekerOptimalMatch>> _runJobseekerOptimalMatching(
    _CandidateProfile candidate,
    List<_JobVector> jobVectors,
    _MatchingWeights weights,
  ) async {
    if (jobVectors.isEmpty) return [];

    // Step 1: Use ANN for initial filtering (performance optimization)
    final annMatcher = _EmbeddingAnnMatcher<_JobVector>();
    final annResults = annMatcher.findNearest(
      query: candidate.featureVector,
      items: jobVectors,
      topK: min(50, jobVectors.length), // Limit to top 50 for performance
    );

    if (annResults.isEmpty) return [];

    // Step 2: Calculate bidirectional preferences and weighted compatibility
    final weightedCompatibility = <String, double>{};

    for (final neighbor in annResults) {
      final job = neighbor.payload;
      
      // Hard filters
      if (!_meetsAgeRequirement(candidate, job.post)) continue;
      if (!_meetsGenderRequirement(candidate, job.post)) continue;
      
      // Calculate score from jobseeker's perspective
      // Debug: Log weights before scoring
      debugPrint('Before _scoreJobseekerMatch: weights.tagMatching=${weights.tagMatching}, weights.textSimilarity=${weights.textSimilarity}');
      final jobseekerScore = await _scoreJobseekerMatch(
        candidate,
        job,
        neighbor.similarity,
        weights,
      );
      
      // Calculate score from job's perspective (recruiter's perspective)
      final jobScore = await _scoreRecruiterMatch(
        job,
        candidate,
        neighbor.similarity,
        weights,
      );
      
      // Weighted compatibility: 60% jobseeker preference, 40% job preference
      // This ensures jobseeker gets what they want, while considering mutual fit
      final weightedScore = (jobseekerScore * 0.6) + (jobScore * 0.4);
      
      // Debug: Log scoring details for first few jobs
      if (weightedCompatibility.length < 3) {
        debugPrint('Job ${job.post.id}: jobseekerScore=$jobseekerScore, jobScore=$jobScore, weightedScore=$weightedScore');
      }
      
      if (weightedScore > 0.05) {
        weightedCompatibility[job.post.id] = weightedScore;
      } else {
        debugPrint('Job ${job.post.id} filtered out: weightedScore=$weightedScore <= 0.05');
      }
    }

    if (weightedCompatibility.isEmpty) return [];

    // Step 3: Use TopK algorithm to get top 20 (more efficient than full sort)
    const k = 20;
    final topKEntries = _getTopK(
      weightedCompatibility.entries.toList(),
      k,
      (entry) => entry.value,
    );
    
    // Step 4: Build result list (top 20)
    final results = <_JobseekerOptimalMatch>[];
    final jobById = {for (final job in jobVectors) job.post.id: job};
    
    for (final entry in topKEntries) {
      final jobId = entry.key;
      final score = entry.value;
      final job = jobById[jobId];
      if (job != null) {
        results.add(_JobseekerOptimalMatch(
          job: job,
          score: score,
        ));
      }
    }

    return results;
  }

  /// TopK algorithm: Efficiently get top K elements using heap-based approach
  /// Time Complexity: O(n log k) where n = total items, k = top K
  /// Space Complexity: O(k)
  /// 
  /// Algorithm: Maintain a min-heap of size k to track top K largest elements
  List<T> _getTopK<T>(
    List<T> items,
    int k,
    double Function(T) getValue,
  ) {
    if (items.isEmpty || k <= 0) return [];
    if (k >= items.length) {
      // If k >= n, sort all items (no need for TopK optimization)
      final sorted = items.toList()
        ..sort((a, b) => getValue(b).compareTo(getValue(a)));
      return sorted;
    }

    // Heap-based TopK: Maintain a min-heap of size k
    // The heap stores the top K largest elements, with the smallest at the top
    final heap = <T>[];
    
    for (final item in items) {
      final value = getValue(item);
      
      if (heap.length < k) {
        // Heap not full, add item
        heap.add(item);
        _heapifyUp(heap, heap.length - 1, getValue, ascending: true);
      } else {
        // Heap is full, compare with smallest element
        final smallestValue = getValue(heap[0]);
        if (value > smallestValue) {
          // Replace smallest element with current item
          heap[0] = item;
          _heapifyDown(heap, 0, getValue, ascending: true);
        }
      }
    }
    
    // Sort the heap to get descending order (largest first)
    heap.sort((a, b) => getValue(b).compareTo(getValue(a)));
    
    return heap;
  }

  /// Helper: Heapify up (bubble up) for min-heap
  void _heapifyUp<T>(List<T> heap, int index, double Function(T) getValue, {required bool ascending}) {
    while (index > 0) {
      final parentIndex = (index - 1) ~/ 2;
      final currentValue = getValue(heap[index]);
      final parentValue = getValue(heap[parentIndex]);
      
      final shouldSwap = ascending
          ? currentValue < parentValue
          : currentValue > parentValue;
      
      if (!shouldSwap) break;
      
      // Swap with parent
      final temp = heap[index];
      heap[index] = heap[parentIndex];
      heap[parentIndex] = temp;
      
      index = parentIndex;
    }
  }

  /// Helper: Heapify down (bubble down) for min-heap
  void _heapifyDown<T>(List<T> heap, int index, double Function(T) getValue, {required bool ascending}) {
    while (true) {
      int smallest = index;
      final left = 2 * index + 1;
      final right = 2 * index + 2;
      
      if (left < heap.length) {
        final leftValue = getValue(heap[left]);
        final smallestValue = getValue(heap[smallest]);
        if (ascending ? leftValue < smallestValue : leftValue > smallestValue) {
          smallest = left;
        }
      }
      
      if (right < heap.length) {
        final rightValue = getValue(heap[right]);
        final smallestValue = getValue(heap[smallest]);
        if (ascending ? rightValue < smallestValue : rightValue > smallestValue) {
          smallest = right;
        }
      }
      
      if (smallest == index) break;
      
      // Swap with smallest child
      final temp = heap[index];
      heap[index] = heap[smallest];
      heap[smallest] = temp;
      
      index = smallest;
    }
  }

  /// Removed _runStableOptimalMatching - no longer needed
  /// Recruiter matching now uses simple score-based sorting

  /// Check if candidate meets age requirement for a job
  bool _meetsAgeRequirement(_CandidateProfile candidate, Post job) {
    if (candidate.age == null) {
      return job.minAgeRequirement == null && job.maxAgeRequirement == null;
    }
    final candidateAge = candidate.age!;
    if (job.minAgeRequirement != null && candidateAge < job.minAgeRequirement!) {
      return false;
    }
    if (job.maxAgeRequirement != null && candidateAge > job.maxAgeRequirement!) {
      return false;
    }
    return true;
  }

  /// Check if candidate meets gender requirement for a job
  /// Returns true if:
  /// - Job has no gender requirement (null or "any")
  /// - Candidate gender matches job requirement
  /// - Candidate has no gender but job requirement is "any"
  bool _meetsGenderRequirement(_CandidateProfile candidate, Post job) {
    final jobGenderRequirement = job.genderRequirement?.toLowerCase().trim();
    
    // If job has no gender requirement or "any", all candidates pass
    if (jobGenderRequirement == null || 
        jobGenderRequirement.isEmpty || 
        jobGenderRequirement == 'any') {
      return true;
    }

    // If candidate has no gender set, only match jobs with "any" requirement
    // (Already handled above, so if we reach here, job has specific requirement)
    final candidateGender = candidate.gender?.toLowerCase().trim();
    if (candidateGender == null || candidateGender.isEmpty) {
      // Conservative approach: candidate without gender can't match specific requirements
      return false;
    }

    // Check if candidate gender matches job requirement
    return candidateGender == jobGenderRequirement;
  }

  Future<List<Post>> _loadActiveJobs() async {
    final snapshot = await _firestore
        .collection('posts')
        .where('isDraft', isEqualTo: false)
        .where('status', isEqualTo: PostStatus.active.name)
        .get();

    return snapshot.docs.map(_postFromDoc).toList();
  }

  Future<List<Post>> _loadRecruiterJobs(String ownerId) async {
    final snapshot = await _firestore
        .collection('posts')
        .where('ownerId', isEqualTo: ownerId)
        .where('isDraft', isEqualTo: false)
        .limit(_maxJobsPerRecruiter)
        .get();

    return snapshot.docs.map(_postFromDoc).toList();
  }

  Future<List<_CandidateProfile>> _loadCandidateProfiles() async {
    // Fetch tag data once for all candidates
    final tagData = await _getTagData();
    final skillCategoryIds = await _getSkillCategoryIds();
    final jobPreferenceCategoryIds = await _getJobPreferenceCategoryIds();
    final locationCategoryIds = await _getLocationCategoryIds();

    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'jobseeker')
        .where('profileCompleted', isEqualTo: true)
        .limit(_maxCandidatesPerRecruiter)
        .get();

    final profiles = <_CandidateProfile>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final profile = await _CandidateProfile.fromUserDataWithTagData(
        doc.id,
        data,
        tagData,
        skillCategoryIds,
        jobPreferenceCategoryIds,
        locationCategoryIds,
      );
      if (profile.isMatchable) {
        profiles.add(profile);
      }
    }
    return profiles;
  }

  Future<Map<String, String>> _fetchUserLabels(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final result = <String, String>{};
    final ids = userIds.toList();
    const chunkSize = 10;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(i, min(i + chunkSize, ids.length));
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final label =
            (data['fullName'] as String?) ??
            (data['professionalProfile'] as String?) ??
            'Hiring Company';
        result[doc.id] = label;
      }
    }
    return result;
  }

  // Removed _persistMatches and _persistMatchesForJobseeker methods
  // No longer writing to job_matches collection - using real-time computation instead

  /// Get reliability score for a candidate (with caching)
  /// Returns a coefficient between 0.8 and 1.2 that adjusts the match score
  Future<double> _getReliabilityScore(String candidateId) async {
    // Check cache first
    final cached = _reliabilityCache[candidateId];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp) < _reliabilityCacheExpiryDuration) {
      return cached.score;
    }

    // Calculate reliability score
    final score = await _calculateReliabilityScore(candidateId);
    
    // Cache the result
    _reliabilityCache[candidateId] = _CachedReliability(score, DateTime.now());
    
    return score;
  }

  /// Calculate reliability score based on candidate's history
  /// Considers: application approval rate, average rating, completion rate
  /// Returns a coefficient between 0.8 and 1.2
  Future<double> _calculateReliabilityScore(String candidateId) async {
    try {
      // 1. Query application history
      final applicationsSnapshot = await _firestore
          .collection('applications')
          .where('jobseekerId', isEqualTo: candidateId)
          .get();

      final totalApplications = applicationsSnapshot.docs.length;
      final approvedApplications = applicationsSnapshot.docs
          .where((doc) => (doc.data()['status'] as String?) == 'approved')
          .length;
      
      // Calculate approval rate (default to 0.5 if no applications)
      final approvalRate = totalApplications > 0 
          ? approvedApplications / totalApplications 
          : 0.5;

      // 2. Query average rating from reviews collection
      double ratingScore = 0.8; // Default to 0.8 (neutral)
      try {
        final ratingsSnapshot = await _firestore
            .collection('reviews')
            .where('employeeId', isEqualTo: candidateId)
            .where('status', isEqualTo: 'active')
            .get();

        if (ratingsSnapshot.docs.isNotEmpty) {
          final ratings = ratingsSnapshot.docs
              .map((doc) => (doc.data()['rating'] as num?)?.toDouble() ?? 0.0)
              .where((r) => r > 0)
              .toList();
          
          if (ratings.isNotEmpty) {
            final avgRating = ratings.reduce((a, b) => a + b) / ratings.length;
            // Normalize rating (1-5 scale) to 0-1 scale, then map to 0.8-1.2
            ratingScore = 0.8 + (avgRating / 5.0) * 0.4; // Maps 1.0→0.8, 5.0→1.2
          }
        }
      } catch (e) {
        debugPrint('Error fetching ratings for candidate $candidateId: $e');
        // Use default ratingScore
      }

      // 3. Calculate completion rate (if we have completed posts)
      double completionRate = 0.8; // Default
      try {
        // Get approved applications
        final approvedAppIds = applicationsSnapshot.docs
            .where((doc) => (doc.data()['status'] as String?) == 'approved')
            .map((doc) => doc.data()['postId'] as String?)
            .where((id) => id != null && id.isNotEmpty)
            .toList();

        if (approvedAppIds.isNotEmpty) {
          // Check how many of these posts were completed
          // Limit to 10 to avoid Firestore 'whereIn' limit
          final limitedIds = approvedAppIds.take(10).toList();
          final postsSnapshot = await _firestore
              .collection('posts')
              .where(FieldPath.documentId, whereIn: limitedIds)
              .get();

          final totalApproved = postsSnapshot.docs.length;
          final completed = postsSnapshot.docs
              .where((doc) => doc.data()['completedAt'] != null)
              .length;

          if (totalApproved > 0) {
            final completionRatio = completed / totalApproved;
            // Map to 0.8-1.2 range
            completionRate = 0.8 + completionRatio * 0.4;
          }
        }
      } catch (e) {
        debugPrint('Error calculating completion rate for candidate $candidateId: $e');
        // Use default completionRate
      }

      // 4. Combine factors with weights
      // Approval rate: 40%, Rating: 40%, Completion rate: 20%
      final approvalComponent = 0.8 + approvalRate * 0.4; // Maps 0→0.8, 1→1.2
      final reliabilityScore = (approvalComponent * 0.4) + 
                                (ratingScore * 0.4) + 
                                (completionRate * 0.2);

      // Clamp to 0.8-1.2 range
      return reliabilityScore.clamp(0.8, 1.2);
    } catch (e) {
      debugPrint('Error calculating reliability score for candidate $candidateId: $e');
      // Return neutral score on error
      return 1.0;
    }
  }
}

/// Cached reliability data structure
class _CachedReliability {
  final double score;
  final DateTime timestamp;
  _CachedReliability(this.score, this.timestamp);
}

/// Internal class to store optimal match result for a jobseeker
class _JobseekerOptimalMatch {
  _JobseekerOptimalMatch({
    required this.job,
    required this.score,
  });

  final _JobVector job;
  final double score;
}

class _PendingMatch {
  _PendingMatch({
    required this.job,
    required this.recruiterLabel,
    required this.candidateId,
    required this.candidateName,
    required this.matchedSkills,
    required this.score,
    required this.strategy,
  });

  final Post job;
  final String recruiterLabel;
  final String candidateId;
  final String candidateName;
  final List<String> matchedSkills;
  final double score;
  final String strategy;

  Map<String, dynamic> toFirestorePayload() {
    return {
      'jobId': job.id,
      'jobTitle': job.title,
      'fullName': recruiterLabel,
      'recruiterId': job.ownerId,
      'jobseekerId': candidateId,
      'candidateName': candidateName,
      'matchedSkills': matchedSkills,
      'matchPercentage': (score * 100).clamp(1, 100).round(),
      'matchingStrategy': strategy,
    };
  }
}

class _JobVector implements _VectorCarrier<_JobVector> {
  _JobVector({
    required this.post,
    required this.featureVector,
    required this.requiredSkills,
    required this.recruiterLabel,
  });

  final Post post;
  final _FeatureVector featureVector;
  final Set<String> requiredSkills;
  final String recruiterLabel;

  factory _JobVector.fromPost(Post post, String recruiterLabel) {
    // Include tags and requiredSkills in feature vector for similarity matching
    final tokens = <String>[
      post.title,
      post.description,
      post.event,
      post.jobType.name,
      post.jobType.label,
      post.location,
      ...post.tags, // Include tags for matching
      ...post.requiredSkills, // Include required skills for matching
    ];

    return _JobVector(
      post: post,
      recruiterLabel: recruiterLabel,
      featureVector: _FeatureVector.fromTokens(tokens),
      requiredSkills: post.requiredSkills.map(_normalizeToken).toSet(),
    );
  }

  @override
  _FeatureVector get vector => featureVector;

  @override
  Set<String> get comparableTokens => featureVector.tokens;
}

class _CandidateProfile implements _VectorCarrier<_CandidateProfile> {
  _CandidateProfile({
    required this.id,
    required this.displayName,
    required this.skillSet,
    required this.locationPreferences,
    required this.jobPreferences,
    required this.featureVector,
    required this.tagUniverse,
    this.age,
    this.gender,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String displayName;
  final Set<String> skillSet;
  final Set<String> locationPreferences;
  final Set<String> jobPreferences;
  final _FeatureVector featureVector;
  final Set<String> tagUniverse;
  final int? age; // User's age from profile
  final String? gender; // User's gender from profile
  final double? latitude; // User's location latitude
  final double? longitude; // User's location longitude

  bool get isMatchable => featureVector.tokens.isNotEmpty;

  static Future<_CandidateProfile> fromUserDataWithTagData(
    String userId,
    Map<String, dynamic> data,
    Map<TagCategory, List<Tag>> tagData,
    Set<String> skillCategoryIds,
    Set<String> jobPreferenceCategoryIds,
    Set<String> locationCategoryIds,
  ) async {
    final tags = parseTagSelection(data['tags']);

    // Extract skill-related tags from all skill categories
    final skillTokens = <String>[];
    for (final categoryId in skillCategoryIds) {
      skillTokens.addAll(tags[categoryId] ?? const <String>[]);
    }
    // Backward compatibility: also check old hardcoded category IDs
    skillTokens.addAll(tags['skillTags'] ?? const <String>[]);
    skillTokens.addAll(tags['softSkillTags'] ?? const <String>[]);

    // Extract job preference tags
    final jobPrefTokens = <String>{};
    for (final categoryId in jobPreferenceCategoryIds) {
      jobPrefTokens.addAll(
        (tags[categoryId] ?? const <String>[])
            .map(_normalizeToken)
            .where((value) => value.isNotEmpty),
      );
    }
    // Backward compatibility
    jobPrefTokens.addAll(
      (tags['jobPreferenceTags'] ?? const <String>[])
          .map(_normalizeToken)
          .where((value) => value.isNotEmpty),
    );

    // Extract location tags
    final locationTokens = <String>{
      if (data['location'] is String) _normalizeToken(data['location'] as String),
    };
    for (final categoryId in locationCategoryIds) {
      locationTokens.addAll(
        (tags[categoryId] ?? const <String>[])
            .map(_normalizeToken)
            .where((value) => value.isNotEmpty),
      );
    }
    // Backward compatibility
    locationTokens.addAll(
      (tags['locationTags'] ?? const <String>[])
          .map(_normalizeToken)
          .where((value) => value.isNotEmpty),
    );
    locationTokens.removeWhere((element) => element.isEmpty);

    final narrativeTokens = <String>[
      ...(tags.values.expand((value) => value)),
      ..._tokenize(data['professionalProfile'] as String?),
      ..._tokenize(data['professionalSummary'] as String?),
      ..._tokenize(data['workExperience'] as String?),
    ];

    final tokens = <String>[
      ...skillTokens,
      ...narrativeTokens,
    ];

    final displayName = (data['fullName'] as String?)?.trim();
    final age = (data['age'] as int?) ?? (data['age'] as num?)?.toInt();
    final gender = data['gender'] as String?;
    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();

    return _CandidateProfile(
      id: userId,
      displayName: (displayName == null || displayName.isEmpty)
          ? 'Candidate'
          : displayName,
      skillSet: skillTokens
          .map(_normalizeToken)
          .where((value) => value.isNotEmpty)
          .toSet(),
      locationPreferences: locationTokens,
      jobPreferences: jobPrefTokens,
      featureVector: _FeatureVector.fromTokens(tokens),
      tagUniverse: tags.values
          .expand((value) => value.map(_normalizeToken))
          .where((value) => value.isNotEmpty)
          .toSet(),
      age: age,
      gender: gender,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  _FeatureVector get vector => featureVector;

  @override
  Set<String> get comparableTokens => featureVector.tokens;
}

mixin _VectorCarrier<T> {
  _FeatureVector get vector;
  Set<String> get comparableTokens;
}

class _EmbeddingAnnMatcher<T extends _VectorCarrier<T>> {
  List<_AnnNeighbor<T>> findNearest({
    required _FeatureVector query,
    required List<T> items,
    int topK = 25,
  }) {
    if (items.isEmpty) return const [];

    final invertedIndex = <String, List<T>>{};
    for (final item in items) {
      for (final token in item.comparableTokens) {
        invertedIndex.putIfAbsent(token, () => <T>[]).add(item);
      }
    }

    final candidates = <T>{};
    final queryTokens = query.tokens.toList();
    if (queryTokens.isNotEmpty) {
      for (final token in queryTokens.take(6)) {
        final bucket = invertedIndex[token];
        if (bucket != null) {
          candidates.addAll(bucket);
        }
      }
    }

    if (candidates.isEmpty) {
      candidates.addAll(items);
    }

    final neighbors = <_AnnNeighbor<T>>[];
    for (final item in candidates) {
      final similarity = query.cosine(item.vector);
      // Allow similarity > 0 (even if very small) to ensure we get results
      if (similarity.isNaN || similarity < 0) continue;
      neighbors.add(_AnnNeighbor(payload: item, similarity: similarity));
    }

    neighbors.sort((a, b) => b.similarity.compareTo(a.similarity));
    if (neighbors.length > topK) {
      return neighbors.sublist(0, topK);
    }
    return neighbors;
  }
}

class _AnnNeighbor<T> {
  const _AnnNeighbor({required this.payload, required this.similarity});
  final T payload;
  final double similarity;
}

class _FeatureVector {
  _FeatureVector._(this._weights)
      : _norm = sqrt(
          _weights.values.fold<double>(0, (sum, value) => sum + value * value),
        );

  factory _FeatureVector.fromTokens(Iterable<String> tokens) {
    final weights = <String, double>{};
    for (final token in tokens) {
      final normalized = _normalizeToken(token);
      if (normalized.isEmpty) continue;
      weights[normalized] = (weights[normalized] ?? 0) + 1;
    }
    return _FeatureVector._(weights);
  }

  final Map<String, double> _weights;
  final double _norm;

  Set<String> get tokens => _weights.keys.toSet();

  double cosine(_FeatureVector other) {
    if (_norm == 0 || other._norm == 0) return 0;
    double dot = 0;
    if (_weights.length <= other._weights.length) {
      _weights.forEach((key, value) {
        final otherValue = other._weights[key];
        if (otherValue != null) {
          dot += value * otherValue;
        }
      });
    } else {
      other._weights.forEach((key, value) {
        final thisValue = _weights[key];
        if (thisValue != null) {
          dot += value * thisValue;
        }
      });
    }
    return dot / (_norm * other._norm);
  }
}

/// Calculate distance between two coordinates in kilometers
double _calculateDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
}

/// Calculate distance score (0-1, where 1 is closest and 0 is farthest)
/// Uses exponential decay: closer = higher score
double _calculateDistanceScore(
  double distanceKm, {
  double maxDistanceKm = 50.0,
  double decayFactor = 3.0,
}) {
  if (distanceKm <= 0) return 1.0; // Same location
  if (distanceKm >= maxDistanceKm) return 0.0; // Beyond max distance
  
  // Exponential decay: score = e^(-distance/maxDistance * decayFactor)
  // Adjust decayFactor to control how quickly score decreases with distance
  final normalizedDistance = distanceKm / maxDistanceKm;
  return exp(-normalizedDistance * decayFactor);
}

Future<double> _scoreJobseekerMatch(
  _CandidateProfile candidate,
  _JobVector job,
  double similarity,
  _MatchingWeights weights,
) async {
  // Debug: Verify weights object at function entry
  debugPrint('_scoreJobseekerMatch entry: weights.tagMatching=${weights.tagMatching}, weights.textSimilarity=${weights.textSimilarity}, weights.hashCode=${weights.hashCode}');
  
  // Base score from embedding similarity (tags, skills, description similarity)
  var score = similarity * weights.textSimilarity;

  // Step 3: Direct tags matching (post.tags vs jobseeker.tags)
  // This is the core matching logic you requested
  final postTags = job.post.tags.map(_normalizeToken).toSet();
  final candidateTags = candidate.tagUniverse;
  final matchedTags = candidateTags.intersection(postTags);
  
  if (postTags.isNotEmpty) {
    // Calculate tag overlap percentage
    final tagOverlap = matchedTags.length / postTags.length;
    final tagContribution = weights.tagMatching * tagOverlap;
    score += tagContribution;
    
    // Debug: Log tag matching details for ALL jobs (to diagnose weight issues)
    debugPrint('Job ${job.post.id}: tagOverlap=$tagOverlap, tagMatchingWeight=${weights.tagMatching}, tagContribution=$tagContribution, score=$score');
  }

  // Step 4: Required skills matching (post.requiredSkills vs jobseeker skill tags)
  final requiredSkills = job.requiredSkills;
  if (requiredSkills.isNotEmpty) {
    final skillOverlap =
        candidate.skillSet.intersection(requiredSkills).length /
        requiredSkills.length;
    score += weights.requiredSkills * skillOverlap;
  }

  // Step 5: Distance factor (NEW)
  // Calculate distance score if both candidate and job have coordinates
  if (candidate.latitude != null &&
      candidate.longitude != null &&
      job.post.latitude != null &&
      job.post.longitude != null) {
    final distanceKm = _calculateDistance(
      candidate.latitude!,
      candidate.longitude!,
      job.post.latitude!,
      job.post.longitude!,
    );
    
    // Distance score: closer = higher score (exponential decay)
    final distanceScore = _calculateDistanceScore(
      distanceKm,
      maxDistanceKm: weights.maxDistanceKm,
      decayFactor: weights.decayFactor,
    );
    score += weights.distance * distanceScore;
  } else {
    // Fallback: location string matching (if coordinates not available)
    if (candidate.locationPreferences.contains(
      _normalizeToken(job.post.location),
    )) {
      score += weights.distance * 0.3; // 30% of distance weight for string match
    }
  }

  // Additional bonuses (smaller weights)
  final jobTypeToken = _normalizeToken(job.post.jobType.label);
  if (candidate.jobPreferences.contains(jobTypeToken)) {
    score += weights.jobTypePreference;
  }

  return score.clamp(0, 1);
}

Future<double> _scoreRecruiterMatch(
  _JobVector job,
  _CandidateProfile candidate,
  double similarity,
  _MatchingWeights weights,
) async {
  // Debug: Log weights being used in recruiter scoring
  debugPrint('Recruiter scoring - weights: textSimilarity=${weights.textSimilarity}, tagMatching=${weights.tagMatching}, requiredSkills=${weights.requiredSkills}, distance=${weights.distance}');
  
  // Base score from embedding similarity
  var score = similarity * weights.textSimilarity;

  // Direct tags matching (post.tags vs jobseeker.tags)
  final postTags = job.post.tags.map(_normalizeToken).toSet();
  final candidateTags = candidate.tagUniverse;
  final matchedTags = candidateTags.intersection(postTags);
  
  if (postTags.isNotEmpty) {
    final tagOverlap = matchedTags.length / postTags.length;
    score += weights.tagMatching * tagOverlap;
  }

  // Required skills matching
  final requiredSkills = job.requiredSkills;
  if (requiredSkills.isNotEmpty) {
    final skillOverlap =
        candidate.skillSet.intersection(requiredSkills).length /
        requiredSkills.length;
    score += weights.requiredSkills * skillOverlap;
  }

  // Distance factor (NEW)
  if (candidate.latitude != null &&
      candidate.longitude != null &&
      job.post.latitude != null &&
      job.post.longitude != null) {
    final distanceKm = _calculateDistance(
      candidate.latitude!,
      candidate.longitude!,
      job.post.latitude!,
      job.post.longitude!,
    );
    
    final distanceScore = _calculateDistanceScore(
      distanceKm,
      maxDistanceKm: weights.maxDistanceKm,
      decayFactor: weights.decayFactor,
    );
    score += weights.distance * distanceScore;
  } else {
    // Fallback: location string matching
    if (candidate.locationPreferences.contains(
      _normalizeToken(job.post.location),
    )) {
      score += weights.distance * 0.3; // 30% of distance weight for string match
    }
  }

  // Additional bonuses
  final jobTypeToken = _normalizeToken(job.post.jobType.label);
  if (candidate.jobPreferences.contains(jobTypeToken)) {
    score += weights.jobTypePreference;
  }

  return score.clamp(0, 1);
}

List<String> _matchedSkills(
  Set<String> candidateSkills,
  Set<String> jobSkills,
) {
  final overlap = candidateSkills.intersection(jobSkills).toList();
  overlap.sort();
  if (overlap.isNotEmpty) {
    return overlap.map(_displayLabel).take(5).toList();
  }
  return jobSkills.map(_displayLabel).take(3).toList();
}


String _displayLabel(String value) {
  if (value.isEmpty) return value;
  final parts = value
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return value;
  return parts
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _normalizeToken(String? raw) {
  if (raw == null) return '';
  return raw.trim().toLowerCase();
}

List<String> _tokenize(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  return value
      .split(RegExp(r'[^a-zA-Z0-9+#]+'))
      .map((token) => token.trim())
      .where((token) => token.isNotEmpty)
      .toList();
}

Post _postFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return Post.fromMap({...data, 'id': doc.id, 'createdAt': data['createdAt']});
}

/// Removed Gale-Shapley and Hungarian algorithms - not suitable for one-to-many recommendation scenario
/// Current implementation uses weighted sorting which is more appropriate for the use case


