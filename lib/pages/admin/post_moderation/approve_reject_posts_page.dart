import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';
import 'package:fyp_project/services/admin/post_service.dart';
import 'package:fyp_project/pages/admin/post_moderation/post_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:fyp_project/services/user/wallet_service.dart';
import 'package:fyp_project/services/user/notification_service.dart';
import 'package:fyp_project/widgets/admin/common/tab_button.dart';
import 'package:fyp_project/widgets/admin/cards/posts_list.dart';

class ApproveRejectPostsPage extends StatefulWidget {
  const ApproveRejectPostsPage({super.key});

  @override
  State<ApproveRejectPostsPage> createState() => _ApproveRejectPostsPageState();
}

class _ApproveRejectPostsPageState extends State<ApproveRejectPostsPage> {
  final PostService _postService = PostService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _searchController = TextEditingController();
  final PageController _tabPageController = PageController();
  int _currentTabIndex = 0;

  List<JobPostModel> _allPosts = [];
  List<JobPostModel> _pendingPosts = [];
  List<JobPostModel> _activePosts = [];
  List<JobPostModel> _completedPosts = [];
  List<JobPostModel> _rejectedPosts = [];
  bool _isLoading = true;
  
  final Map<String, Map<String, String>> _userInfoCache = {};
  final Set<String> _processingPostIds = {};
  bool _isProcessingGlobal = false;
  Timer? _searchDebounce;
  Timer? _streamThrottle;
  List<JobPostModel>? _pendingPostsUpdate;
  StreamSubscription<List<JobPostModel>>? _postsSubscription;
  final StreamController<List<JobPostModel>> _postsStreamController = StreamController<List<JobPostModel>>.broadcast();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeStream();
  }
  
  void _initializeStream() {
    _postsSubscription = _postService.streamAllPosts().listen(
      (posts) {
        _postsStreamController.add(posts);
      },
      onError: (error) {
        debugPrint('Error in posts stream: $error');
      },
    );
  }
  
  Future<void> _refreshAllPosts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .get();
      
      if (!mounted || _postsStreamController.isClosed) return;
      
      final posts = snapshot.docs
          .map((doc) => JobPostModel.fromFirestore(doc))
          .toList();
      
      _postsStreamController.add(posts);
    } catch (e) {
      debugPrint('Error refreshing posts from Firestore: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing posts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _immediatelyRefreshPost(JobPostModel post) {
    if (!mounted) return;
    
    setState(() {
      _allPosts.removeWhere((p) => p.id == post.id);
      _pendingPosts.removeWhere((p) => p.id == post.id);
      _activePosts.removeWhere((p) => p.id == post.id);
      _completedPosts.removeWhere((p) => p.id == post.id);
      _rejectedPosts.removeWhere((p) => p.id == post.id);
    });
    
    FirebaseFirestore.instance
        .collection('posts')
        .get()
        .then((snapshot) {
          if (!mounted || _postsStreamController.isClosed) return;
          
          final posts = snapshot.docs
              .map((doc) => JobPostModel.fromFirestore(doc))
              .toList();
          
          _postsStreamController.add(posts);
        })
        .catchError((e) {
          debugPrint('Error refreshing posts from Firestore: $e');
        });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _streamThrottle?.cancel();
    _postsSubscription?.cancel();
    _postsStreamController.close();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabPageController.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _switchTab(int index) {
    if (!mounted || _currentTabIndex == index || _isProcessingGlobal) return;
    setState(() => _currentTabIndex = index);
    if (_tabPageController.hasClients) {
      _tabPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentTabIndex = index);
  }

  Future<void> _approvePost(JobPostModel post) async {
    if (_processingPostIds.contains(post.id) || _isProcessingGlobal) return;
    
    setState(() {
      _processingPostIds.add(post.id);
      _isProcessingGlobal = true;
    });
    
    try {
      await _postService.approvePost(post.id);
      
      final ownerId = post.ownerId;
      if (ownerId != null && ownerId.isNotEmpty) {
        try {
          final success = await WalletService.deductPostCreationCreditsForUser(
            firestore: FirebaseFirestore.instance,
            userId: ownerId,
            postId: post.id,
            feeCredits: 200,
          );
          
          if (success) {
            try {
              await _notificationService.notifyWalletDebit(
                userId: ownerId,
                amount: 200,
                reason: 'Post creation fee',
                metadata: {
                  'postId': post.id,
                  'postTitle': post.title,
                  'type': 'post_creation_fee_approved',
                },
              );
            } catch (e) {
              debugPrint('Error sending credit deduction notification: $e');
            }
          } else {
            debugPrint('Warning: Failed to deduct credits for post ${post.id}');
          }
        } catch (e) {
          debugPrint('Error deducting credits for post ${post.id}: $e');
        }
      }
      
      if (!mounted) return;
      
      _immediatelyRefreshPost(post);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post approved and now active'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingPostIds.remove(post.id);
          _isProcessingGlobal = false;
        });
      }
    }
  }

  Future<void> _rejectPost(JobPostModel post) async {
    if (_processingPostIds.contains(post.id) || _isProcessingGlobal) return;
    
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectPostDialog(post: post),
    );

    if (reason != null && reason.isNotEmpty) {
      setState(() {
        _processingPostIds.add(post.id);
        _isProcessingGlobal = true;
      });
      
      try {
        await _postService.rejectPost(post.id, reason);
        
        final ownerId = post.ownerId;
        if (ownerId != null && ownerId.isNotEmpty) {
          try {
            final success = await WalletService.releasePostCreationCreditsForUser(
              firestore: FirebaseFirestore.instance,
              userId: ownerId,
              postId: post.id,
              feeCredits: 200,
            );
            
            if (success) {
              try {
                await _notificationService.notifyWalletCredit(
                  userId: ownerId,
                  amount: 200,
                  reason: 'Post creation fee (Released)',
                  metadata: {
                    'postId': post.id,
                    'postTitle': post.title,
                    'rejectionReason': reason,
                    'type': 'post_creation_fee_released',
                  },
                );
              } catch (e) {
                debugPrint('Error sending credit release notification: $e');
              }
            } else {
              debugPrint('Warning: Failed to release credits for post ${post.id}');
            }
          } catch (e) {
            debugPrint('Error releasing credits for post ${post.id}: $e');
          }
        }
        
        if (!mounted) return;
        
        _immediatelyRefreshPost(post);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post rejected'), backgroundColor: Colors.orange),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) {
          setState(() {
            _processingPostIds.remove(post.id);
            _isProcessingGlobal = false;
          });
        }
      }
    }
  }

  void _viewPost(JobPostModel post) {
    if (!mounted || _isProcessingGlobal) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
    );
  }

  List<JobPostModel> _filterPosts(List<JobPostModel> posts) {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return posts;

    return posts.where((post) =>
    post.title.toLowerCase().contains(query) ||
        post.description.toLowerCase().contains(query) ||
        (post.submitterName ?? '').toLowerCase().contains(query)
    ).toList();
  }

  String _getUserName(String? ownerId) {
    if (ownerId == null || ownerId.isEmpty) return 'Unknown User';
    final userInfo = _userInfoCache[ownerId];
    if (userInfo == null) return 'Loading...';
    return userInfo['name'] ?? 'Unknown User';
  }

  String _getUserEmail(String? ownerId) {
    if (ownerId == null || ownerId.isEmpty) return '';
    final userInfo = _userInfoCache[ownerId];
    if (userInfo == null) return '';
    return userInfo['email'] ?? '';
  }

  void _handlePostsUpdate(List<JobPostModel> posts) {
    final nonDraftPosts = posts.where((p) => p.isDraft != true).toList();
    
    _pendingPostsUpdate = nonDraftPosts;
    
    _streamThrottle?.cancel();
    _streamThrottle = Timer(const Duration(milliseconds: 50), () {
      if (!mounted || _pendingPostsUpdate == null) return;
      
      final postsToProcess = _pendingPostsUpdate!;
      _pendingPostsUpdate = null;
      
      _batchFetchUserNames(postsToProcess);
      
      if (!mounted) return;
      
      bool hasChanged = false;
      if (_allPosts.length != postsToProcess.length) {
        hasChanged = true;
      } else if (_allPosts.isNotEmpty && postsToProcess.isNotEmpty) {
        
        if (_allPosts.first.id != postsToProcess.first.id ||
            _allPosts.last.id != postsToProcess.last.id) {
          hasChanged = true;
        } else {
          final checkIndices = [
            _allPosts.length ~/ 4,
            _allPosts.length ~/ 2,
            (3 * _allPosts.length) ~/ 4,
          ];
          for (final idx in checkIndices) {
            if (idx < _allPosts.length && idx < postsToProcess.length) {
              if (_allPosts[idx].id != postsToProcess[idx].id ||
                  _allPosts[idx].status != postsToProcess[idx].status) {
                hasChanged = true;
                break;
              }
            }
          }
        }
      } else {
        hasChanged = true;
      }
      
      if (hasChanged) {
        setState(() {
          _allPosts = postsToProcess;
          
          _pendingPosts = _allPosts.where((p) => p.status == 'pending').toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _activePosts = _allPosts.where((p) => p.status == 'active').toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _completedPosts = _allPosts.where((p) => p.status == 'completed').toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _rejectedPosts = _allPosts.where((p) => p.status == 'rejected').toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _isLoading = false;
        });
      }
    });
  }
  
  Future<void> _batchFetchUserNames(List<JobPostModel> posts) async {
    final uncachedIds = <String>{};
    for (final post in posts) {
      final ownerId = post.ownerId ?? post.submitterName;
      if (ownerId != null && 
          ownerId.isNotEmpty && 
          !_userInfoCache.containsKey(ownerId)) {
        uncachedIds.add(ownerId);
      }
    }
    
    if (uncachedIds.isEmpty) return;
    
    final idsToFetch = uncachedIds.take(20).toList();
    
    try {
      
      for (var i = 0; i < idsToFetch.length; i += 10) {
        final batch = idsToFetch.skip(i).take(10);
        final futures = batch.map((id) async {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(id)
                .get();
            if (userDoc.exists) {
              final data = userDoc.data();
              return MapEntry(id, {
                'name': (data?['fullName'] as String?) ?? 'Unknown User',
                'email': (data?['email'] as String?) ?? '',
              });
            }
          } catch (e) {
            debugPrint('Error fetching user info for $id: $e');
          }
          return MapEntry(id, {
            'name': 'Unknown User',
            'email': '',
          });
        });
        
        final results = await Future.wait(futures);
        if (mounted) {
          setState(() {
            for (final entry in results) {
              _userInfoCache[entry.key] = entry.value;
            }
          });
        }
        
        if (i + 10 < idsToFetch.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    } catch (e) {
      debugPrint('Error batch fetching user info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessingGlobal,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: const Text(
                'Job Post Management',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              elevation: 0,
              automaticallyImplyLeading: true,
            ),
            body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              enabled: !_isProcessingGlobal,
              decoration: InputDecoration(
                hintText: 'Search job posts by title, description, or author...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                AdminTabButton(
                  label: 'Pending',
                  count: _pendingPosts.length,
                  isSelected: _currentTabIndex == 0,
                  onTap: () => _switchTab(0),
                ),
                AdminTabButton(
                  label: 'Active',
                  count: _activePosts.length,
                  isSelected: _currentTabIndex == 1,
                  onTap: () => _switchTab(1),
                ),
                AdminTabButton(
                  label: 'Completed',
                  count: _completedPosts.length,
                  isSelected: _currentTabIndex == 2,
                  onTap: () => _switchTab(2),
                ),
                AdminTabButton(
                  label: 'Rejected',
                  count: _rejectedPosts.length,
                  isSelected: _currentTabIndex == 3,
                  onTap: () => _switchTab(3),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<JobPostModel>>(
              stream: _postsStreamController.stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading posts...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading posts',
                                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                if (snapshot.hasData) {
                  final posts = snapshot.data!;
                  _handlePostsUpdate(posts);
                }

                return PageView(
                  controller: _tabPageController,
                  onPageChanged: _onPageChanged,
                  physics: _isProcessingGlobal 
                      ? const NeverScrollableScrollPhysics() 
                      : const PageScrollPhysics(),
                  children: [
                    PostsList(
                      posts: _filterPosts(_pendingPosts),
                      status: 'pending',
                      onApprove: _approvePost,
                      onReject: _rejectPost,
                      onComplete: null,
                      onReopen: null,
                      onView: _viewPost,
                      getUserName: _getUserName,
                      getUserEmail: _getUserEmail,
                      processingPostIds: _processingPostIds,
                      onRefresh: _refreshAllPosts,
                    ),
                    PostsList(
                      posts: _filterPosts(_activePosts),
                      status: 'active',
                      onApprove: null,
                      onReject: _rejectPost,
                      onComplete: null,
                      onReopen: null,
                      onView: _viewPost,
                      getUserName: _getUserName,
                      getUserEmail: _getUserEmail,
                      processingPostIds: _processingPostIds,
                      onRefresh: _refreshAllPosts,
                    ),
                    PostsList(
                      posts: _filterPosts(_completedPosts),
                      status: 'completed',
                      onApprove: null,
                      onReject: null,
                      onComplete: null,
                      onReopen: null,
                      onView: _viewPost,
                      getUserName: _getUserName,
                      getUserEmail: _getUserEmail,
                      processingPostIds: _processingPostIds,
                      onRefresh: _refreshAllPosts,
                    ),
                    PostsList(
                      posts: _filterPosts(_rejectedPosts),
                      status: 'rejected',
                      onApprove: null,
                      onReject: null,
                      onComplete: null,
                      onReopen: null,
                      onView: _viewPost,
                      getUserName: _getUserName,
                      getUserEmail: _getUserEmail,
                      processingPostIds: _processingPostIds,
                      onRefresh: _refreshAllPosts,
                    ),
                  ],
                );
              },
            ),
          ),
          ],
          ),
          ),
          if (_isProcessingGlobal)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Processing...',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Roboto',
                              color: Color(0xFF1A1A1A),
                              letterSpacing: 0.5,
                              decoration: TextDecoration.none,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please wait while we update the post',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Roboto',
                              color: Colors.grey[700],
                              letterSpacing: 0.2,
                              decoration: TextDecoration.none,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

}

class _RejectPostDialog extends StatefulWidget {
  final JobPostModel post;

  const _RejectPostDialog({required this.post});

  @override
  State<_RejectPostDialog> createState() => _RejectPostDialogState();
}

class _RejectPostDialogState extends State<_RejectPostDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _selectedReason;
  bool _isCustomReason = false;

  final List<Map<String, String>> _commonReasons = [
    {
      'title': 'Incomplete Information',
      'description': 'Missing essential job details'
    },
    {
      'title': 'Inappropriate Content',
      'description': 'Contains offensive language'
    },
    {
      'title': 'Duplicate Post',
      'description': 'Similar job already exists'
    },
    {
      'title': 'Violates Guidelines',
      'description': 'Breaks community rules'
    },
    {
      'title': 'Spam Content',
      'description': 'Promotional or spam content'
    },
    {
      'title': 'Unclear Description',
      'description': 'Job details are vague'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.warning_amber, color: Colors.red[700]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disable Job Post',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please provide a reason for rejecting this post',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Container(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.post.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.post.category} • ${widget.post.location}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a reason',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose from common reasons or write your own',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmallScreen = constraints.maxWidth < 400;
                        return GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isSmallScreen ? 1 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: isSmallScreen ? 3.5 : 2.5,
                            mainAxisExtent: isSmallScreen ? 80 : 90,
                          ),
                          itemCount: _commonReasons.length,
                          itemBuilder: (context, index) {
                            final reason = _commonReasons[index];
                            final isSelected = _selectedReason == reason['title'] && !_isCustomReason;

                            return _ReasonCard(
                              title: reason['title']!,
                              description: reason['description']!,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedReason = reason['title'];
                                  _reasonController.text = reason['title']!;
                                  _isCustomReason = false;
                                });
                              },
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    _CustomReasonCard(
                      isSelected: _isCustomReason,
                      controller: _reasonController,
                      onTap: () {
                        setState(() {
                          _isCustomReason = true;
                          _selectedReason = null;
                          _reasonController.clear();
                        });
                      },
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _reasonController.text.trim().isNotEmpty
                          ? () => Navigator.pop(context, _reasonController.text.trim())
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close, size: 18),
                          SizedBox(width: 8),
                          Text('Disable Post'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReasonCard({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.red : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.red[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.red : Colors.grey[400]!,
                    width: 2,
                  ),
                  color: isSelected ? Colors.red : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.red[700] : Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.red[600] : Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomReasonCard extends StatelessWidget {
  final bool isSelected;
  final TextEditingController controller;
  final VoidCallback onTap;
  final Function(String) onChanged;

  const _CustomReasonCard({
    required this.isSelected,
    required this.controller,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[400]!,
                        width: 2,
                      ),
                      color: isSelected ? Colors.blue : Colors.transparent,
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Custom Reason',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.blue[700] : Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                onChanged: onChanged,
                enabled: isSelected,
                maxLines: 3,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Type your reason here...',
                  filled: true,
                  fillColor: isSelected ? Colors.white : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue[700]!),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              if (!isSelected) ...[
                const SizedBox(height: 8),
                Text(
                  'Tap to enable custom reason',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}