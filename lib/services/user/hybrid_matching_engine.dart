import 'dart:collection';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/user/post.dart';
import '../../models/user/tag.dart';
import '../../models/user/tag_category.dart';
import 'auth_service.dart';
import 'tag_service.dart';
import '../../utils/user/tag_definitions.dart';

/// Matching strategy enum
enum MatchingStrategy {
  embeddingsAnn,      // Strategy A: Quick recommendation (many-to-many)
  stableOptimal,      // Strategy B: Precise matching (one-to-one)
}

/// A hybrid matching engine that supports two strategies:
/// - Embeddings + ANN: Quick recommendation for browsing
/// - Gale-Shapley + Hungarian: Precise matching for optimal assignment
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
  static const int _defaultJobseekerResults = 10;

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

    // Step 1: Filter jobs by age requirement (hard filter - must pass)
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

    final recruiterLabels = await _fetchUserLabels(
      ageFilteredJobs.map((job) => job.ownerId).toSet(),
    );

    final jobVectors = ageFilteredJobs
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
      final score = _scoreJobseekerMatch(candidate, jobVector, similarity);
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

    pendingMatches.sort((a, b) => b.score.compareTo(a.score));
    final finalMatches = pendingMatches.take(_defaultJobseekerResults).toList();
    await _persistMatches(finalMatches);
  }

  Future<void> _runRecruiterPipeline(
    String userId,
    MatchingStrategy strategy,
  ) async {
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

      // Step 2: Use Embeddings + ANN for initial filtering
      final annResults = annMatcher.findNearest(
        query: job.featureVector,
        items: ageFilteredCandidates,
        topK: 20,
      );

      if (annResults.isEmpty) continue;

      final scores = <String, double>{};
      for (final neighbor in annResults) {
        final candidate = neighbor.payload;
        final score = _scoreRecruiterMatch(job, candidate, neighbor.similarity);
        if (score <= 0.05) continue;
        scores[candidate.id] = score;
      }

      if (scores.isEmpty) continue;
      compatibility[job.post.id] = scores;
    }

    if (compatibility.isEmpty) return;

    final resolvedPairs = <String, String>{};

    if (strategy == MatchingStrategy.stableOptimal) {
      // Strategy B: Gale-Shapley + Hungarian (Precise matching)
      resolvedPairs.addAll(await _runStableOptimalMatching(
        compatibility,
        jobVectors,
        candidateProfiles,
      ));
    } else {
      // Strategy A: Simple score-based selection (Quick recommendation)
      for (final jobId in compatibility.keys) {
        final scores = compatibility[jobId]!;
        final sortedCandidates = scores.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        if (sortedCandidates.isNotEmpty && sortedCandidates.first.value > 0) {
          resolvedPairs[jobId] = sortedCandidates.first.key;
        }
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

    await _persistMatches(pendingMatches);
  }

  /// Run stable optimal matching using Gale-Shapley + Hungarian algorithms
  Future<Map<String, String>> _runStableOptimalMatching(
    Map<String, Map<String, double>> compatibility,
    List<_JobVector> jobVectors,
    List<_CandidateProfile> candidateProfiles,
  ) async {
    // Step 1: Calculate candidate preferences (candidate → job scores)
    final candidatePreferences = <String, Map<String, double>>{};
    final annMatcher = _EmbeddingAnnMatcher<_JobVector>();

    for (final candidate in candidateProfiles) {
      final jobScores = <String, double>{};
      
      // Find nearest jobs for this candidate
      final annResults = annMatcher.findNearest(
        query: candidate.featureVector,
        items: jobVectors,
        topK: 20,
      );

      for (final neighbor in annResults) {
        final job = neighbor.payload;
        
        // Age filter
        if (!_meetsAgeRequirement(candidate, job.post)) continue;
        
        // Calculate score from candidate's perspective
        final score = _scoreJobseekerMatch(candidate, job, neighbor.similarity);
        if (score > 0.05) {
          jobScores[job.post.id] = score;
        }
      }

      if (jobScores.isNotEmpty) {
        candidatePreferences[candidate.id] = jobScores;
      }
    }

    // Step 2: Build preference lists for Gale-Shapley
    final jobPreferences = <String, List<String>>{};
    for (final jobId in compatibility.keys) {
      final scores = compatibility[jobId]!;
      final sorted = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      jobPreferences[jobId] = sorted.map((e) => e.key).toList();
    }

    final candidatePrefLists = <String, List<String>>{};
    for (final candidateId in candidatePreferences.keys) {
      final scores = candidatePreferences[candidateId]!;
      final sorted = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      candidatePrefLists[candidateId] = sorted.map((e) => e.key).toList();
    }

    // Step 3: Run Hungarian algorithm for optimal assignment
    final hungarian = HungarianMatcher();
    final optimizedPairs = hungarian.maximise(compatibility);

    // Step 4: Run Gale-Shapley for stable matching
    final galeShapley = GaleShapleyMatcher();
    final stablePairs = galeShapley.match(jobPreferences, candidatePrefLists);

    // Step 5: Resolve conflicts (prefer Hungarian, fallback to Gale-Shapley)
    final resolvedPairs = <String, String>{};
    for (final jobId in compatibility.keys) {
      if (optimizedPairs[jobId] != null) {
        // Prefer Hungarian result (optimal assignment)
        resolvedPairs[jobId] = optimizedPairs[jobId]!;
        continue;
      }
      if (stablePairs[jobId] != null) {
        // Fallback to Gale-Shapley result (stable matching)
        resolvedPairs[jobId] = stablePairs[jobId]!;
        continue;
      }
      // Final fallback: highest score
      final fallback = compatibility[jobId]!.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (fallback.isNotEmpty && fallback.first.value > 0) {
        resolvedPairs[jobId] = fallback.first.key;
      }
    }

    return resolvedPairs;
  }

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
            (data['companyName'] as String?) ??
            (data['professionalProfile'] as String?) ??
            (data['fullName'] as String?) ??
            'Hiring Company';
        result[doc.id] = label;
      }
    }
    return result;
  }

  Future<void> _persistMatches(List<_PendingMatch> matches) async {
    if (matches.isEmpty) return;
    final jobseekerGroups = <String, List<_PendingMatch>>{};
    for (final match in matches) {
      jobseekerGroups
          .putIfAbsent(match.candidateId, () => <_PendingMatch>[])
          .add(match);
    }
    for (final entry in jobseekerGroups.entries) {
      await _persistMatchesForJobseeker(entry.key, entry.value);
    }
  }

  Future<void> _persistMatchesForJobseeker(
    String jobseekerId,
    List<_PendingMatch> matches,
  ) async {
    if (matches.isEmpty) return;

    final existingSnapshot = await _firestore
        .collection('job_matches')
        .where('jobseekerId', isEqualTo: jobseekerId)
        .get();

    final existingByJob =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in existingSnapshot.docs) {
      final data = doc.data();
      final jobId = data['jobId'] as String?;
      if (jobId != null && jobId.isNotEmpty) {
        existingByJob[jobId] = doc;
      }
    }

    final batch = _firestore.batch();
    for (final match in matches) {
      final payload = match.toFirestorePayload();
      final existingDoc = existingByJob[match.job.id];

      if (existingDoc != null) {
        final existingStatus =
            existingDoc.data()['status'] as String? ?? 'pending';
        batch.set(existingDoc.reference, {
          ...payload,
          'status': existingStatus,
        }, SetOptions(merge: true));
      } else {
        final docRef = _firestore.collection('job_matches').doc();
        batch.set(docRef, {
          ...payload,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }
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
      'companyName': recruiterLabel,
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
      if (similarity.isNaN || similarity <= 0) continue;
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
double _calculateDistanceScore(double distanceKm, {double maxDistanceKm = 50.0}) {
  if (distanceKm <= 0) return 1.0; // Same location
  if (distanceKm >= maxDistanceKm) return 0.0; // Beyond max distance
  
  // Exponential decay: score = e^(-distance/maxDistance * decayFactor)
  // Adjust decayFactor to control how quickly score decreases with distance
  const decayFactor = 3.0; // Higher = faster decay
  final normalizedDistance = distanceKm / maxDistanceKm;
  return exp(-normalizedDistance * decayFactor);
}

double _scoreJobseekerMatch(
  _CandidateProfile candidate,
  _JobVector job,
  double similarity,
) {
  // Base score from embedding similarity (tags, skills, description similarity)
  var score = similarity * 0.35; // 35% weight for text similarity (reduced from 40%)

  // Step 3: Direct tags matching (post.tags vs jobseeker.tags)
  // This is the core matching logic you requested
  final postTags = job.post.tags.map(_normalizeToken).toSet();
  final candidateTags = candidate.tagUniverse;
  final matchedTags = candidateTags.intersection(postTags);
  
  if (postTags.isNotEmpty) {
    // Calculate tag overlap percentage
    final tagOverlap = matchedTags.length / postTags.length;
    score += 0.35 * tagOverlap; // 35% weight for tag matching (reduced from 40%)
  }

  // Step 4: Required skills matching (post.requiredSkills vs jobseeker skill tags)
  final requiredSkills = job.requiredSkills;
  if (requiredSkills.isNotEmpty) {
    final skillOverlap =
        candidate.skillSet.intersection(requiredSkills).length /
        requiredSkills.length;
    score += 0.15 * skillOverlap; // 15% weight for required skills
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
    final distanceScore = _calculateDistanceScore(distanceKm, maxDistanceKm: 50.0);
    score += 0.10 * distanceScore; // 10% weight for distance (closer = better)
  } else {
    // Fallback: location string matching (if coordinates not available)
    if (candidate.locationPreferences.contains(
      _normalizeToken(job.post.location),
    )) {
      score += 0.03; // 3% bonus for location string match
    }
  }

  // Additional bonuses (smaller weights)
  final jobTypeToken = _normalizeToken(job.post.jobType.label);
  if (candidate.jobPreferences.contains(jobTypeToken)) {
    score += 0.02; // 2% bonus for job type preference
  }

  return score.clamp(0, 1);
}

double _scoreRecruiterMatch(
  _JobVector job,
  _CandidateProfile candidate,
  double similarity,
) {
  // Base score from embedding similarity
  var score = similarity * 0.35; // 35% weight for text similarity

  // Direct tags matching (post.tags vs jobseeker.tags)
  final postTags = job.post.tags.map(_normalizeToken).toSet();
  final candidateTags = candidate.tagUniverse;
  final matchedTags = candidateTags.intersection(postTags);
  
  if (postTags.isNotEmpty) {
    final tagOverlap = matchedTags.length / postTags.length;
    score += 0.35 * tagOverlap; // 35% weight for tag matching
  }

  // Required skills matching
  final requiredSkills = job.requiredSkills;
  if (requiredSkills.isNotEmpty) {
    final skillOverlap =
        candidate.skillSet.intersection(requiredSkills).length /
        requiredSkills.length;
    score += 0.15 * skillOverlap; // 15% weight for required skills
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
    
    final distanceScore = _calculateDistanceScore(distanceKm, maxDistanceKm: 50.0);
    score += 0.10 * distanceScore; // 10% weight for distance
  } else {
    // Fallback: location string matching
    if (candidate.locationPreferences.contains(
      _normalizeToken(job.post.location),
    )) {
      score += 0.03; // 3% bonus for location string match
    }
  }

  // Additional bonuses
  final jobTypeToken = _normalizeToken(job.post.jobType.label);
  if (candidate.jobPreferences.contains(jobTypeToken)) {
    score += 0.02; // 2% bonus for job type preference
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

/// Gale-Shapley stable matching algorithm
/// Finds stable one-to-one matches between jobs (proposers) and candidates (acceptors)
class GaleShapleyMatcher {
  Map<String, String> match(
    Map<String, List<String>> proposerPreferences,
    Map<String, List<String>> acceptorPreferences,
  ) {
    final freeProposers = Queue<String>()..addAll(proposerPreferences.keys);
    final nextProposalIndex = <String, int>{};
    final engagements = <String, String>{}; // acceptor -> proposer

    while (freeProposers.isNotEmpty) {
      final proposer = freeProposers.removeFirst();
      final preferences = proposerPreferences[proposer];
      if (preferences == null || preferences.isEmpty) {
        continue;
      }

      final proposalIndex = nextProposalIndex.update(
        proposer,
        (value) => value + 1,
        ifAbsent: () => 0,
      );

      if (proposalIndex >= preferences.length) {
        continue;
      }

      final candidate = preferences[proposalIndex];
      final currentPartner = engagements[candidate];

      if (currentPartner == null) {
        engagements[candidate] = proposer;
        continue;
      }

      final acceptorPref = acceptorPreferences[candidate];
      if (acceptorPref == null || acceptorPref.isEmpty) {
        continue;
      }

      if (_prefers(acceptorPref, proposer, currentPartner)) {
        engagements[candidate] = proposer;
        freeProposers.add(currentPartner);
      } else {
        freeProposers.add(proposer);
      }
    }

    final result = <String, String>{};
    engagements.forEach((candidate, proposer) {
      result[proposer] = candidate;
    });
    return result;
  }

  bool _prefers(
    List<String> preferenceList,
    String newOption,
    String currentOption,
  ) {
    final newIndex = preferenceList.indexOf(newOption);
    if (newIndex == -1) return false;
    final currentIndex = preferenceList.indexOf(currentOption);
    if (currentIndex == -1) return true;
    return newIndex < currentIndex;
  }
}

/// Hungarian algorithm for optimal assignment
/// Finds one-to-one assignment that maximizes total score
class HungarianMatcher {
  Map<String, String> maximise(Map<String, Map<String, double>> scores) {
    if (scores.isEmpty) return const {};

    final jobIds = scores.keys.toList();
    final candidateIds = scores.values.fold<Set<String>>(<String>{}, (
      set,
      value,
    ) {
      set.addAll(value.keys);
      return set;
    }).toList();

    if (candidateIds.isEmpty) return const {};

    final rows = jobIds.length;
    final cols = candidateIds.length;
    final size = max(rows, cols);
    final matrix = List.generate(size, (_) => List<double>.filled(size, 0));

    double maxValue = 0;
    for (var i = 0; i < rows; i++) {
      final jobId = jobIds[i];
      final row = scores[jobId] ?? {};
      for (var j = 0; j < cols; j++) {
        final candidateId = candidateIds[j];
        final value = row[candidateId] ?? 0;
        matrix[i][j] = value;
        if (value > maxValue) {
          maxValue = value;
        }
      }
    }

    if (maxValue == 0) return const {};

    final costMatrix = List.generate(size, (i) => List<double>.filled(size, 0));
    for (var i = 0; i < size; i++) {
      for (var j = 0; j < size; j++) {
        costMatrix[i][j] = maxValue - matrix[i][j];
      }
    }

    final assignment = _hungarian(costMatrix);
    final result = <String, String>{};

    for (var i = 0; i < assignment.length; i++) {
      final col = assignment[i];
      if (col == -1) continue;
      if (i < rows && col < cols) {
        final score = matrix[i][col];
        if (score > 0) {
          result[jobIds[i]] = candidateIds[col];
        }
      }
    }

    return result;
  }

  List<int> _hungarian(List<List<double>> costMatrix) {
    final n = costMatrix.length;
    final m = costMatrix[0].length;
    final u = List<double>.filled(n + 1, 0);
    final v = List<double>.filled(m + 1, 0);
    final p = List<int>.filled(m + 1, 0);
    final way = List<int>.filled(m + 1, 0);

    for (var i = 1; i <= n; i++) {
      p[0] = i;
      var j0 = 0;
      final minv = List<double>.filled(m + 1, double.infinity);
      final used = List<bool>.filled(m + 1, false);

      do {
        used[j0] = true;
        final i0 = p[j0];
        var delta = double.infinity;
        var j1 = 0;

        for (var j = 1; j <= m; j++) {
          if (used[j]) continue;
          final cur = costMatrix[i0 - 1][j - 1] - u[i0] - v[j];
          if (cur < minv[j]) {
            minv[j] = cur;
            way[j] = j0;
          }
          if (minv[j] < delta) {
            delta = minv[j];
            j1 = j;
          }
        }

        for (var j = 0; j <= m; j++) {
          if (used[j]) {
            u[p[j]] += delta;
            v[j] -= delta;
          } else {
            minv[j] -= delta;
          }
        }

        j0 = j1;
      } while (p[j0] != 0);

      do {
        final j1 = way[j0];
        p[j0] = p[j1];
        j0 = j1;
      } while (j0 != 0);
    }

    final answer = List<int>.filled(n, -1);
    for (var j = 1; j <= m; j++) {
      if (p[j] != 0 && p[j] - 1 < n && j - 1 < m) {
        answer[p[j] - 1] = j - 1;
      }
    }

    return answer;
  }
}


