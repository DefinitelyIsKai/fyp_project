import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/user/post.dart';
import 'wallet_service.dart';
import 'notification_service.dart';
import 'category_service.dart';
import 'cloud_functions_service.dart';

enum PopularPostMetric { views, applicants }

class PostService {
  PostService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    WalletService? walletService,
    NotificationService? notificationService,
    CategoryService? categoryService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _walletService = walletService ?? WalletService(),
       _notificationService = notificationService ?? NotificationService(),
       _categoryService = categoryService ?? CategoryService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final WalletService _walletService;
  final NotificationService _notificationService;
  final CategoryService _categoryService;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('posts');

  Stream<List<Post>> streamMyPosts({bool includeRejected = false}) {
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
              .where((post) {
                if (post.status == PostStatus.deleted) return false;
                //exclude rejected posts 
                if (!includeRejected && post.status == PostStatus.rejected) return false;
                return true;
              })
              .toList();
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        })
        .handleError((error) {
          debugPrint('Error in streamMyPosts (likely during logout): $error');
          return <Post>[];
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
      //null post deleted or rejected 
      if (post.status == PostStatus.deleted || post.status == PostStatus.rejected) return null;
      return post;
    } catch (e) {
      debugPrint('Error fetching post $postId: $e');
      return null;
    }
  }

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

  //stream a single post by ID for real-time updates 
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
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to create a post. Please sign in and try again.');
    }
    
    //post id if available or new one
    final postId = post.id.isNotEmpty ? post.id : _col.doc().id;
    final doc = _col.doc(postId);
    
    final PostStatus initialStatus = post.isDraft 
        ? post.status  
        : PostStatus.pending;
    
    final Post toSave = Post(
      id: doc.id,
      ownerId: currentUser.uid,
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
      workTimeStart: post.workTimeStart,
      workTimeEnd: post.workTimeEnd,
      genderRequirement: post.genderRequirement,
      createdAt: DateTime.now(),
      views: post.views,
      applicants: post.applicants,
    );
    final data = toSave.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();

    data['approvedApplicants'] = 0;

    //200 credits need publishing nodrat
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
  
    return toSave;
  }

  Future<Post> update(Post post) async {
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

    //200 publishing when draft post 
    if (wasDraft && !post.isDraft) {
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
        status: PostStatus.pending, 
        completedAt: post.completedAt,
        createdAt: DateTime.now(), 
        eventStartDate: post.eventStartDate,
        eventEndDate: post.eventEndDate,
        workTimeStart: post.workTimeStart,
        workTimeEnd: post.workTimeEnd,
        genderRequirement: post.genderRequirement,
        views: post.views,
        applicants: post.applicants,
      );
      await _walletService.holdPostCreationCredits(postId: post.id, feeCredits: 200);
    }

 
    if (!post.isDraft && oldStatus != newStatus) {
      //educt credits
      if (oldStatus == PostStatus.pending && newStatus == PostStatus.active) {
        try {
          final success = await WalletService.deductPostCreationCreditsForUser(
            firestore: _firestore,
            userId: ownerId,
            postId: post.id,
            feeCredits: 200,
          );
          if (success) {
            if (post.event.isNotEmpty) {
              await _categoryService.incrementJobCount(post.event);
            }
            //noti recruiter 
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
        }
      }
      //status changed from pending to rejected release credits
      else if (oldStatus == PostStatus.pending && newStatus == PostStatus.rejected) {
        try {
          final success = await WalletService.releasePostCreationCreditsForUser(
            firestore: _firestore,
            userId: ownerId,
            postId: post.id,
            feeCredits: 200,
          );
          if (success && ownerId.isNotEmpty) {
            //noti refund
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
        }
      }
    }

    final data = post.toMap();
    
    //publish from draft, update createdAt
    if (wasDraft && !post.isDraft) {
      data['createdAt'] = FieldValue.serverTimestamp();
    } else {
      //nochange createdAt
      data.remove('createdAt');
    }
    
    try {
      await _col.doc(post.id).set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update post in Firestore: $e');
    }

    return post;
  }

  Future<void> delete(String id) async {
    //get post details before marking as deleted 
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

    //notify recruiter about deletion
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
    
    //rrelease held credits  post  pending 
    if (ownerId != null && 
        ownerId.isNotEmpty && 
        post != null && 
        !post.isDraft && 
        post.status == PostStatus.pending) {
      try {
        final success = await WalletService.releasePostCreationCreditsForUser(
          firestore: _firestore,
          userId: ownerId,
          postId: id,
          feeCredits: 200,
        );
        if (success) {
          //noti refund
          try {
            await _notificationService.notifyWalletCredit(
              userId: ownerId,
              amount: 200,
              reason: 'Post creation fee (Released)',
              metadata: {'postId': id, 'type': 'post_creation_fee_released'},
            );
          } catch (e) {
            debugPrint('Error sending wallet credit notification: $e');
          }
        }
      } catch (e) {
        debugPrint('Error releasing post creation credits for deleted post $id: $e');
        
      }
    }
    
   
    await _col.doc(id).update({
      'status': PostStatus.deleted.name,
    });
  }

 
  Stream<List<Post>> searchPosts({
    String? query,
    String? location,
    double? minBudget,
    double? maxBudget,
    List<String>? events,
  }) {
    Query<Map<String, dynamic>> queryRef = _col.where(
      'isDraft',
      isEqualTo: false,
    );

    if (minBudget != null) {
      queryRef = queryRef.where('budgetMax', isGreaterThanOrEqualTo: minBudget);
    } else if (maxBudget != null) {
      queryRef = queryRef.where('budgetMin', isLessThanOrEqualTo: maxBudget);
    }

    return queryRef
        .snapshots()
        .map((snap) {
          var posts = snap.docs.map((d) => _fromDoc(d)).toList();

          //budget filter in memory 
          if (minBudget != null && maxBudget != null) {
            posts = posts.where((post) {
              if (post.budgetMin == null && post.budgetMax == null) return false;
              
              final postMin = post.budgetMin;
              final postMax = post.budgetMax;
              
              if (postMin != null && postMax != null) {
                return postMin >= minBudget && postMax <= maxBudget;
              }
            
              if (postMin != null && postMax == null) {
                return postMin >= minBudget;
              }
             
              if (postMin == null && postMax != null) {
                return postMax <= maxBudget;
              }
              
              return false;
            }).toList();
          }

         
          if (location != null && location.isNotEmpty) {
            posts = posts.where((post) {
              return post.location.toLowerCase().contains(
                location.toLowerCase(),
              );
            }).toList();
          }

        
          if (events != null && events.isNotEmpty) {
            final eventSet = events.map((e) => e.toLowerCase()).toSet();
            posts = posts.where((post) {
              if (post.event.isEmpty) return false;
              return eventSet.contains(post.event.toLowerCase());
            }).toList();
          }

          
          if (query != null && query.isNotEmpty) {
            final queryLower = query.toLowerCase();
            posts = posts.where((post) {
              return post.title.toLowerCase().contains(queryLower) ||
                  post.description.toLowerCase().contains(queryLower) ||
                  post.tags.any(
                    (tag) => tag.toLowerCase().contains(queryLower),
                  );
            }).toList();
          }

        
          posts = posts.where((post) => 
            post.status != PostStatus.pending && 
            post.status != PostStatus.completed &&
            post.status != PostStatus.deleted &&
            post.status != PostStatus.rejected
          ).toList();

       
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        })
        .handleError((error) {
         
          debugPrint('Error searching posts (likely during logout): $error');
          return <Post>[];
        });
  }

  Stream<List<Post>> streamPopularPosts({
    required PopularPostMetric metric,
    int limit = 5,
  }) {
    final safeLimit = limit <= 0 ? 5 : limit;
    final fetchLimit = safeLimit * 5; 

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

     
      posts.sort((a, b) {
        final metricComparison = metric == PopularPostMetric.views
            ? b.views.compareTo(a.views)
            : b.applicants.compareTo(a.applicants);
        if (metricComparison != 0) return metricComparison;
        return b.createdAt.compareTo(a.createdAt);
      });

      if (posts.length > safeLimit) {
        return posts.sublist(0, safeLimit);
      }
      return posts;
    }).handleError((error) {
    
      debugPrint('Error loading popular posts (likely during logout): $error');
      return <Post>[];
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

  Future<int> autoCompleteExpiredPosts() async {
    try {
      final cloudFunctionsService = CloudFunctionsService();
      final result = await cloudFunctionsService.autoCompleteExpiredPosts();
      
      final completedCount = result['completedCount'] as int? ?? 0;
      final success = result['success'] as bool? ?? false;
      
      if (success) {
        debugPrint('Cloud Function completed $completedCount expired post(s)');
      } else {
        debugPrint('Cloud Function error: ${result['message']}');
      }
      
      return completedCount;
    } catch (e) {
      debugPrint('Error calling Cloud Function for auto-complete: $e');
      return 0;
    }
  }

  Future<void> incrementViewCount({required String postId}) async {
    await _col.doc(postId).update({'views': FieldValue.increment(1)});
  }
}
