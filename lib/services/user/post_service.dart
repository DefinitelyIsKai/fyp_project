import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/user/post.dart';
import '../../models/user/app_notification.dart';
import 'wallet_service.dart';
import 'notification_service.dart';
import 'category_service.dart';
import 'application_service.dart';

enum PopularPostMetric { views, applicants }

class PostService {
  PostService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    WalletService? walletService,
    NotificationService? notificationService,
    CategoryService? categoryService,
    ApplicationService? applicationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _walletService = walletService ?? WalletService(),
       _notificationService = notificationService ?? NotificationService(),
       _categoryService = categoryService ?? CategoryService(),
       _applicationService = applicationService ?? ApplicationService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final WalletService _walletService;
  final NotificationService _notificationService;
  final CategoryService _categoryService;
  final ApplicationService _applicationService;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('posts');

  Stream<List<Post>> streamMyPosts() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return Stream.value(<Post>[]);
    }
    return _col
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final posts = snap.docs
              .map((d) => _fromDoc(d))
              .where((post) => 
                post.status != PostStatus.deleted &&
                post.status != PostStatus.rejected
              )
              .toList();
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        })
        .handleError((error) {
          debugPrint('Error loading posts: $error');
          throw error;
        });
  }

  Future<List<Post>> loadInitialMyPosts({int limit = 10}) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return [];
    }

    try {
      final snapshot = await _col
          .where('ownerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      final posts = snapshot.docs
          .map((d) => _fromDoc(d))
          .where((post) => 
            post.status != PostStatus.deleted &&
            post.status != PostStatus.rejected
          )
          .toList();

      if (posts.length > limit) {
        return posts.sublist(0, limit);
      }
      return posts;
    } catch (e) {
      debugPrint('Error loading initial posts: $e');
      return [];
    }
  }

  Future<List<Post>> loadMoreMyPosts({
    required DateTime lastPostTime,
    String? lastPostId,
    int limit = 10,
  }) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return [];
    }

    try {
      final Timestamp timestampCursor = Timestamp.fromDate(lastPostTime);

      if (lastPostId != null) {
        try {
          final snapshot = await _col
              .where('ownerId', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .orderBy(FieldPath.documentId, descending: true)
              .startAfter([timestampCursor, lastPostId])
              .limit(limit)
              .get();

          return snapshot.docs
              .map((d) => _fromDoc(d))
              .where((post) => 
                post.status != PostStatus.deleted &&
                post.status != PostStatus.rejected
              )
              .toList();
        } catch (e) {
          debugPrint('Composite index may be missing, using simple pagination: $e');
        }
      }

      final snapshot = await _col
          .where('ownerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .startAfter([timestampCursor])
          .limit(limit)
          .get();

      return snapshot.docs
          .map((d) => _fromDoc(d))
          .where((post) => 
            post.status != PostStatus.deleted &&
            post.status != PostStatus.rejected
          )
          .toList();
    } catch (e) {
      debugPrint('Error loading more posts: $e');
      return [];
    }
  }

  Future<Post?> getById(String postId) async {
    try {
      final doc = await _col.doc(postId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final post = _fromDoc(doc);
      // Return null if post is deleted or rejected (makes it unavailable)
      if (post.status == PostStatus.deleted || post.status == PostStatus.rejected) return null;
      return post;
    } catch (e) {
      debugPrint('Error fetching post $postId: $e');
      return null;
    }
  }

  // Get post by ID including deleted posts (useful for showing deleted status in applications)
  Future<Post?> getByIdIncludingDeleted(String postId) async {
    try {
      final doc = await _col.doc(postId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return _fromDoc(doc);
    } catch (e) {
      debugPrint('Error fetching post $postId: $e');
      return null;
    }
  }

  // Stream a single post by ID for real-time updates (e.g., quota changes)
  // Returns both the Post object and raw document data for fields not in Post model
  Stream<Map<String, dynamic>> streamPostByIdWithData(String postId) {
    return _col.doc(postId).snapshots().map((doc) {
      if (!doc.exists) {
        return {'post': null, 'data': null};
      }
      final data = doc.data();
      if (data == null) {
        return {'post': null, 'data': null};
      }
      try {
        final post = _fromDoc(doc);
        return {'post': post, 'data': data};
      } catch (e) {
        debugPrint('Error parsing post from stream: $e');
        return {'post': null, 'data': data};
      }
    }).handleError((error) {
      debugPrint('Error streaming post $postId: $error');
      return {'post': null, 'data': null};
    });
  }

  // Stream a single post by ID for real-time updates (e.g., quota changes)
  Stream<Post?> streamPostById(String postId) {
    return _col.doc(postId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      try {
        return _fromDoc(doc);
      } catch (e) {
        debugPrint('Error parsing post from stream: $e');
        return null;
      }
    }).handleError((error) {
      debugPrint('Error streaming post $postId: $error');
      return null;
    });
  }

  Future<Post> create(Post post) async {
    // Use provided post ID if available (for new posts with images), otherwise generate new one
    final postId = post.id.isNotEmpty ? post.id : _col.doc().id;
    final doc = _col.doc(postId);
    
    // For new posts, status should be pending (not draft) or active (draft)
    // When publishing (not draft), status should be pending for admin review
    final PostStatus initialStatus = post.isDraft 
        ? (post.status == PostStatus.pending ? PostStatus.active : post.status)
        : PostStatus.pending;
    
    final Post toSave = Post(
      id: doc.id,
      ownerId: _auth.currentUser?.uid ?? '',
      title: post.title,
      description: post.description,
      budgetMin: post.budgetMin,
      budgetMax: post.budgetMax,
      location: post.location,
      latitude: post.latitude,
      longitude: post.longitude,
      event: post.event,
      jobType: post.jobType,
      tags: post.tags,
      requiredSkills: post.requiredSkills,
      minAgeRequirement: post.minAgeRequirement,
      maxAgeRequirement: post.maxAgeRequirement,
      applicantQuota: post.applicantQuota,
      attachments: post.attachments,
      isDraft: post.isDraft,
      status: initialStatus,
      completedAt: post.completedAt,
      eventStartDate: post.eventStartDate,
      eventEndDate: post.eventEndDate,
      createdAt: DateTime.now(),
      views: post.views,
      applicants: post.applicants,
    );
    final data = toSave.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    // Initialize approvedApplicants to 0 for new posts
    data['approvedApplicants'] = 0;

    // Hold 200 credits if publishing (not draft) - credits are held, not deducted yet
    // Credits will be deducted when post is approved (status changes to active)
    // Credits will be released when post is rejected
    if (!post.isDraft) {
      try {
        await _walletService.holdPostCreationCredits(postId: doc.id, feeCredits: 200);
      } catch (e) {
        throw Exception('Failed to hold credits for post creation: $e');
      }
    }

    try {
      await doc.set(data, SetOptions(merge: true)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Saving post to Firestore timed out after 10 seconds');
        },
      );
    } catch (e) {
      if (e is TimeoutException) {
        rethrow;
      }
      throw Exception('Failed to save post to Firestore: $e');
    }
    
    // Increment jobCount for the category/event when post is not a draft
    // Note: Only increment when post is approved (status = active), not when pending
    // This will be handled when status changes to active
    
    // Notification will be sent when post status changes to 'active' (when admin approves)
    // This is handled in the admin PostService.approvePost() method
    return toSave;
  }

  Future<Post> update(Post post) async {
    // Check if post is being published (was draft, now not draft)
    final existingDoc = await _col.doc(post.id).get();
    final existingData = existingDoc.data();
    if (existingData == null) {
      throw StateError('Post not found');
    }
    
    final bool wasDraft = existingData['isDraft'] as bool? ?? true;
    final String? oldStatusStr = existingData['status'] as String?;
    final PostStatus oldStatus = oldStatusStr != null
        ? PostStatus.values.firstWhere(
            (e) => e.name == oldStatusStr,
            orElse: () => PostStatus.active,
          )
        : PostStatus.active;
    final PostStatus newStatus = post.status;
    final String ownerId = existingData['ownerId'] as String? ?? '';

    // Hold 200 credits if publishing a previously draft post
    if (wasDraft && !post.isDraft) {
      // When publishing draft, set status to pending for admin review
      post = Post(
        id: post.id,
        ownerId: post.ownerId,
        title: post.title,
        description: post.description,
        budgetMin: post.budgetMin,
        budgetMax: post.budgetMax,
        location: post.location,
        latitude: post.latitude,
        longitude: post.longitude,
        event: post.event,
        jobType: post.jobType,
        tags: post.tags,
        requiredSkills: post.requiredSkills,
        minAgeRequirement: post.minAgeRequirement,
        maxAgeRequirement: post.maxAgeRequirement,
        applicantQuota: post.applicantQuota,
        attachments: post.attachments,
        isDraft: post.isDraft,
        status: PostStatus.pending, // Set to pending when publishing
        completedAt: post.completedAt,
        createdAt: post.createdAt,
        eventStartDate: post.eventStartDate,
        eventEndDate: post.eventEndDate,
        views: post.views,
        applicants: post.applicants,
      );
      await _walletService.holdPostCreationCredits(postId: post.id, feeCredits: 200);
    }

    // Handle status changes for credits processing
    // Only process if status actually changed and post is not a draft
    if (!post.isDraft && oldStatus != newStatus) {
      // Status changed from pending to active (approved) - deduct credits
      if (oldStatus == PostStatus.pending && newStatus == PostStatus.active) {
        try {
          final success = await WalletService.deductPostCreationCreditsForUser(
            firestore: _firestore,
            userId: ownerId,
            postId: post.id,
            feeCredits: 200,
          );
          if (success) {
            // Increment jobCount when post is approved
            if (post.event.isNotEmpty) {
              await _categoryService.incrementJobCount(post.event);
            }
            // Send notification to recruiter about approval
            if (ownerId.isNotEmpty) {
              try {
                await _notificationService.notifyWalletDebit(
                  userId: ownerId,
                  amount: 200,
                  reason: 'Post creation fee',
                  metadata: {'postId': post.id, 'type': 'post_creation_fee_deducted'},
                );
              } catch (e) {
                debugPrint('Error sending wallet debit notification: $e');
              }
            }
          }
        } catch (e) {
          debugPrint('Error deducting post creation credits: $e');
          // Don't fail the update if credit processing fails
        }
      }
      // Status changed from pending to rejected - release credits
      else if (oldStatus == PostStatus.pending && newStatus == PostStatus.rejected) {
        try {
          final success = await WalletService.releasePostCreationCreditsForUser(
            firestore: _firestore,
            userId: ownerId,
            postId: post.id,
            feeCredits: 200,
          );
          if (success && ownerId.isNotEmpty) {
            // Send notification to recruiter about refund
            try {
              await _notificationService.notifyWalletCredit(
                userId: ownerId,
                amount: 200,
                reason: 'Post creation fee (Released)',
                metadata: {'postId': post.id, 'type': 'post_creation_fee_released'},
              );
            } catch (e) {
              debugPrint('Error sending wallet credit notification: $e');
            }
          }
        } catch (e) {
          debugPrint('Error releasing post creation credits: $e');
          // Don't fail the update if credit processing fails
        }
      }
    }

    final data = post.toMap();
    data.remove('createdAt');
    
    try {
      await _col.doc(post.id).set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update post in Firestore: $e');
    }

    // Notification will be sent when post status changes to 'active' (when admin approves)
    // This is handled in the admin PostService.approvePost() method
    return post;
  }

  Future<void> delete(String id) async {
    // Get post details before marking as deleted (for notifications)
    // Fetch directly from Firestore to get post even if already deleted
    Post? post;
    String postTitle = 'your post';
    String? ownerId;
    
    try {
      final doc = await _col.doc(id).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          post = _fromDoc(doc);
          postTitle = post.title;
          ownerId = post.ownerId;
        }
      }
    } catch (e) {
      debugPrint('Error fetching post $id for deletion: $e');
    }

    // Get all applications for this post to notify jobseekers
    List<String> jobseekerIds = [];
    if (ownerId != null && ownerId.isNotEmpty) {
      try {
        final applications = await _applicationService.getApplicationsByPostId(
          postId: id,
          recruiterId: ownerId,
        );
        jobseekerIds = applications.map((app) => app.jobseekerId).toSet().toList();
      } catch (e) {
        debugPrint('Error getting applications for post $id: $e');
      }
    }

    // Send notifications to jobseekers who applied (using batch method for efficiency)
    if (jobseekerIds.isNotEmpty) {
      try {
        await _notificationService.notifyMultipleUsers(
          userIds: jobseekerIds,
          category: NotificationCategory.post,
          title: 'Post removed',
          body: 'The post "$postTitle" that you applied to has been removed by the recruiter.',
          metadata: {'postTitle': postTitle},
        );
      } catch (e) {
        debugPrint('Error notifying jobseekers about post deletion: $e');
      }
    }

    // Send notification to recruiter
    if (ownerId != null && ownerId.isNotEmpty) {
      try {
        await _notificationService.notifyPostDeletedToRecruiter(
          recruiterId: ownerId,
          postTitle: postTitle,
        );
      } catch (e) {
        debugPrint('Error notifying recruiter $ownerId about post deletion: $e');
      }
    }

    // Clean up associated applications before marking post as deleted
    if (ownerId != null && ownerId.isNotEmpty) {
      try {
        await _applicationService.deleteApplicationsByPostId(
          postId: id,
          recruiterId: ownerId,
        );
      } catch (e) {
        // Log error but continue with post deletion
        // This ensures post deletion isn't blocked by application cleanup failures
        debugPrint('Warning: Failed to cleanup applications for post $id: $e');
      }
    }
    
    // Mark the post as deleted instead of actually deleting it
    await _col.doc(id).update({
      'status': PostStatus.deleted.name,
    });
  }

  // Search posts with filters
  Stream<List<Post>> searchPosts({
    String? query,
    String? location,
    double? minBudget,
    double? maxBudget,
    List<String>? industries,
  }) {
    Query<Map<String, dynamic>> queryRef = _col.where(
      'isDraft',
      isEqualTo: false,
    );

    // Apply budget filters if provided
    // Note: Even with composite index, Firestore doesn't allow two range queries 
    // on different fields, so we use one in Firestore query and filter the other in memory
    if (minBudget != null) {
      queryRef = queryRef.where('budgetMax', isGreaterThanOrEqualTo: minBudget);
    } else if (maxBudget != null) {
      queryRef = queryRef.where('budgetMin', isLessThanOrEqualTo: maxBudget);
    }

    return queryRef
        .snapshots()
        .map((snap) {
          var posts = snap.docs.map((d) => _fromDoc(d)).toList();

          // Apply the other budget filter in memory if both are provided
          if (minBudget != null && maxBudget != null) {
            // minBudget was used in Firestore query (budgetMax >= minBudget),
            // now filter by maxBudget in memory to ensure post's budget range 
            // is completely within user's search range
            // Post matches if: post.budgetMin >= minBudget AND post.budgetMax <= maxBudget
            posts = posts.where((post) {
              if (post.budgetMin == null && post.budgetMax == null) return false;
              
              final postMin = post.budgetMin;
              final postMax = post.budgetMax;
              
              // If post has both min and max, both must be within user's range
              if (postMin != null && postMax != null) {
                return postMin >= minBudget && postMax <= maxBudget;
              }
              // If post only has min, it must be >= user's min and we assume it's acceptable
              if (postMin != null && postMax == null) {
                return postMin >= minBudget;
              }
              // If post only has max, it must be <= user's max
              if (postMin == null && postMax != null) {
                return postMax <= maxBudget;
              }
              
              return false;
            }).toList();
          }

          // Filter by location if provided
          if (location != null && location.isNotEmpty) {
            posts = posts.where((post) {
              return post.location.toLowerCase().contains(
                location.toLowerCase(),
              );
            }).toList();
          }

          // Filter by industry if provided
          if (industries != null && industries.isNotEmpty) {
            final industrySet = industries.map((i) => i.toLowerCase()).toSet();
            posts = posts.where((post) {
              if (post.event.isEmpty) return false;
              return industrySet.contains(post.event.toLowerCase());
            }).toList();
          }

          // Filter by search query if provided
          if (query != null && query.isNotEmpty) {
            final queryLower = query.toLowerCase();
            posts = posts.where((post) {
              return post.title.toLowerCase().contains(queryLower) ||
                  post.description.toLowerCase().contains(queryLower) ||
                  post.event.toLowerCase().contains(queryLower) ||
                  post.tags.any(
                    (tag) => tag.toLowerCase().contains(queryLower),
                  );
            }).toList();
          }

          // Filter out pending, completed, deleted, and rejected posts (only show active posts)
          posts = posts.where((post) => 
            post.status != PostStatus.pending && 
            post.status != PostStatus.completed &&
            post.status != PostStatus.deleted &&
            post.status != PostStatus.rejected
          ).toList();

          // Sort by createdAt descending (newest first)
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        })
        .handleError((error) {
          debugPrint('Error searching posts: $error');
          throw error;
        });
  }

  Stream<List<Post>> streamPopularPosts({
    required PopularPostMetric metric,
    int limit = 5,
  }) {
    final safeLimit = limit <= 0 ? 5 : limit;
    // Fetch without orderBy to avoid index requirement, sort in memory instead
    final fetchLimit = safeLimit * 5; // Fetch more to ensure we have enough after filtering

    return _col
        .where('isDraft', isEqualTo: false)
        .limit(fetchLimit)
        .snapshots()
        .map((snap) {
      final posts = snap.docs
          .map((d) => _fromDoc(d))
          .where((post) => 
            !post.isDraft && 
            post.status != PostStatus.pending && 
            post.status != PostStatus.completed &&
            post.status != PostStatus.deleted &&
            post.status != PostStatus.rejected
          )
          .toList();

      // Sort in memory by the requested metric
      posts.sort((a, b) {
        final metricComparison = metric == PopularPostMetric.views
            ? b.views.compareTo(a.views)
            : b.applicants.compareTo(a.applicants);
        if (metricComparison != 0) return metricComparison;
        return b.createdAt.compareTo(a.createdAt);
      });

      // Return top N after sorting
      if (posts.length > safeLimit) {
        return posts.sublist(0, safeLimit);
      }
      return posts;
    }).handleError((error) {
      debugPrint('Error loading popular posts: $error');
      throw error;
    });
  }

  Post _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? <String, dynamic>{};
    try {
      return Post.fromMap({
        ...data,
        'id': d.id,
        'createdAt': (data['createdAt'] is Timestamp)
            ? (data['createdAt'] as Timestamp).toDate()
            : data['createdAt'],
      });
    } catch (e) {
      throw FormatException(
        'Failed to parse Post document ${d.id} from Firestore: $e',
        e,
      );
    }
  }

  Future<void> markCompleted({required String postId}) async {
    await _col.doc(postId).set({
      'status': PostStatus.completed.name,
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> incrementViewCount({required String postId}) async {
    await _col.doc(postId).update({'views': FieldValue.increment(1)});
  }
}
