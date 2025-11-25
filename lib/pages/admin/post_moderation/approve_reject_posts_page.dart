import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';
import 'package:fyp_project/services/admin/post_service.dart';
import 'package:fyp_project/pages/admin/post_moderation/post_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:fyp_project/services/user/wallet_service.dart';
import 'package:fyp_project/services/user/notification_service.dart';

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

  // Store posts data
  List<JobPostModel> _allPosts = [];
  List<JobPostModel> _pendingPosts = [];
  List<JobPostModel> _activePosts = [];
  List<JobPostModel> _completedPosts = [];
  List<JobPostModel> _rejectedPosts = [];
  bool _isLoading = true;
  
  // Cache for user names
  final Map<String, String> _userNameCache = {};
  
  // Track processing posts to prevent rapid clicks
  final Set<String> _processingPostIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {}); // Trigger rebuild for search
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabPageController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (!mounted || _currentTabIndex == index) return;
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
    // Prevent multiple clicks on the same post
    if (_processingPostIds.contains(post.id)) return;
    
    setState(() {
      _processingPostIds.add(post.id);
    });
    
    try {
      // Approve the post first
      await _postService.approvePost(post.id);
      
      // Deduct credits from post owner (deduct both balance and heldCredits)
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
            // Send notification to post owner about credit deduction
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
              // Log but don't fail - notification is not critical
              debugPrint('Error sending credit deduction notification: $e');
            }
          } else {
            debugPrint('Warning: Failed to deduct credits for post ${post.id}');
          }
        } catch (e) {
          // Log error but don't fail approval - credits can be processed later
          debugPrint('Error deducting credits for post ${post.id}: $e');
        }
      }
      
      if (!mounted) return;
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
        });
      }
    }
  }

  Future<void> _rejectPost(JobPostModel post) async {
    // Prevent multiple clicks on the same post
    if (_processingPostIds.contains(post.id)) return;
    
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectPostDialog(post: post), // Pass the post here
    );

    if (reason != null && reason.isNotEmpty) {
      setState(() {
        _processingPostIds.add(post.id);
      });
      
      try {
        // Reject the post first
        await _postService.rejectPost(post.id, reason);
        
        // Release held credits for post owner (deduct from heldCredits only, not balance)
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
              // Send notification to post owner about credit release
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
                // Log but don't fail - notification is not critical
                debugPrint('Error sending credit release notification: $e');
              }
            } else {
              debugPrint('Warning: Failed to release credits for post ${post.id}');
            }
          } catch (e) {
            // Log error but don't fail rejection - credits can be processed later
            debugPrint('Error releasing credits for post ${post.id}: $e');
          }
        }
        
        if (!mounted) return;
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
          });
        }
      }
    }
  }


  void _viewPost(JobPostModel post) {
    // Prevent multiple navigation pushes
    if (!mounted) return;
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

  Future<String> _getUserName(String? ownerId) async {
    if (ownerId == null || ownerId.isEmpty) return 'Unknown User';
    if (_userNameCache.containsKey(ownerId)) {
      return _userNameCache[ownerId]!;
    }
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();
      if (userDoc.exists) {
        final userName = userDoc.data()?['fullName'] ?? 'Unknown User';
        _userNameCache[ownerId] = userName;
        return userName;
      }
    } catch (e) {
      print('Error fetching user name: $e');
    }
    return 'Unknown User';
  }

  void _handlePostsUpdate(List<JobPostModel> posts) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _allPosts = posts;
        _pendingPosts = _allPosts.where((p) => p.status == 'pending').toList();
        _activePosts = _allPosts.where((p) => p.status == 'active').toList();
        _completedPosts = _allPosts.where((p) => p.status == 'completed').toList();
        _rejectedPosts = _allPosts.where((p) => p.status == 'rejected').toList();
        _isLoading = false;
      });
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      body: Column(
        children: [
          // Search bar
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

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                _TabButton(
                  label: 'Pending',
                  count: _pendingPosts.length,
                  isSelected: _currentTabIndex == 0,
                  onTap: () => _switchTab(0),
                ),
                _TabButton(
                  label: 'Active',
                  count: _activePosts.length,
                  isSelected: _currentTabIndex == 1,
                  onTap: () => _switchTab(1),
                ),
                _TabButton(
                  label: 'Completed',
                  count: _completedPosts.length,
                  isSelected: _currentTabIndex == 2,
                  onTap: () => _switchTab(2),
                ),
                _TabButton(
                  label: 'Rejected',
                  count: _rejectedPosts.length,
                  isSelected: _currentTabIndex == 3,
                  onTap: () => _switchTab(3),
                ),
              ],
            ),
          ),

          // Stream posts and swipable content area
          Expanded(
            child: StreamBuilder<List<JobPostModel>>(
              stream: _postService.streamAllPosts(),
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
                  children: [
                    // Pending Tab
                    _PostsList(
                      posts: _filterPosts(_pendingPosts),
                      status: 'pending',
                      onApprove: _approvePost,
                      onReject: _rejectPost,
                      onComplete: null,
                      onReopen: null,
                      onView: _viewPost,
                      getUserName: _getUserName,
                      processingPostIds: _processingPostIds,
                    ),
                    // Active Tab
                    _PostsList(
                      posts: _filterPosts(_activePosts),
                      status: 'active',
                      onApprove: null,
                      onReject: _rejectPost,
                      onComplete: null,
                      onReopen: null,
                      onView: _viewPost,
                      getUserName: _getUserName,
                      processingPostIds: _processingPostIds,
                    ),
                    // Completed Tab
                    _PostsList(
                      posts: _filterPosts(_completedPosts),
                      status: 'completed',
                      onApprove: null,
                      onReject: null,
                      onComplete: null,
                      onReopen: null,
                      onView: _viewPost,
                      getUserName: _getUserName,
                      processingPostIds: _processingPostIds,
                    ),
                    // Rejected Tab
                    _PostsList(
                      posts: _filterPosts(_rejectedPosts),
                      status: 'rejected',
                      onApprove: null,
                      onReject: null,
                      onComplete: null,
                      onReopen: null,
                      onView: _viewPost,
                      getUserName: _getUserName,
                      processingPostIds: _processingPostIds,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

// Reject Post Dialog
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
            // Header
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
                          'Reject Job Post',
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

            // Post Preview
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

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Common Reasons Section
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

                    // Common Reasons - Single Column for better layout
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

                    // Custom Reason Option
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

            // Actions
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
                          Text('Reject Post'),
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
// Posts List for each tab
class _PostsList extends StatelessWidget {
  final List<JobPostModel> posts;
  final String status;
  final Function(JobPostModel)? onApprove;
  final Function(JobPostModel)? onReject;
  final Function(JobPostModel)? onComplete;
  final Function(JobPostModel)? onReopen;
  final Function(JobPostModel) onView;
  final Future<String> Function(String?) getUserName;
  final Set<String> processingPostIds;

  const _PostsList({
    required this.posts,
    required this.status,
    this.onApprove,
    this.onReject,
    this.onComplete,
    this.onReopen,
    required this.onView,
    required this.getUserName,
    required this.processingPostIds,
  });

  @override
  Widget build(BuildContext context) {
    // Return a scrollable widget that can be wrapped by RefreshIndicator
    if (posts.isEmpty) {
      return _buildEmptyState(status);
    }
    
    return CustomScrollView(
      slivers: [
        // Header with post count
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${posts.length} post${posts.length == 1 ? '' : 's'} found',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Posts list
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final post = posts[index];
                return _PostCard(
                  post: post,
                  onApprove: onApprove,
                  onReject: onReject,
                  onComplete: onComplete,
                  onReopen: onReopen,
                  onView: onView,
                  getUserName: getUserName,
                  isProcessing: processingPostIds.contains(post.id),
                );
              },
              childCount: posts.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String status) {
    final emptyMessages = {
      'pending': 'No pending posts to review',
      'active': 'No active posts',
      'completed': 'No completed posts',
      'rejected': 'No rejected posts'
    };
    final emptyIcons = {
      'pending': Icons.pending_actions,
      'active': Icons.play_arrow,
      'completed': Icons.check_circle,
      'rejected': Icons.cancel
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            emptyIcons[status] ?? Icons.article,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessages[status] ?? 'No posts found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Posts will appear here once available',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Widgets ----------------

class _TabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  Color getTabColor() {
    switch (label) {
      case 'Pending':
        return Colors.orange;
      case 'Active':
        return Colors.green;
      case 'Completed':
        return Colors.blue;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected ? getTabColor() : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.white.withOpacity(0.3) 
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final JobPostModel post;
  final Function(JobPostModel)? onApprove;
  final Function(JobPostModel)? onReject;
  final Function(JobPostModel)? onComplete;
  final Function(JobPostModel)? onReopen;
  final Function(JobPostModel) onView;
  final Future<String> Function(String?) getUserName;
  final bool isProcessing;

  const _PostCard({
    required this.post,
    this.onApprove,
    this.onReject,
    this.onComplete,
    this.onReopen,
    required this.onView,
    required this.getUserName,
    this.isProcessing = false,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actionButtons = [];

    // Build action buttons based on current status
    switch (post.status) {
      case 'pending':
        actionButtons = [
          if (onApprove != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isProcessing ? null : () => onApprove!(post),
                icon: isProcessing 
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(isProcessing ? 'Processing...' : 'Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.green.withOpacity(0.6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          if (onApprove != null && onReject != null) const SizedBox(width: 8),
          if (onReject != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isProcessing ? null : () => onReject!(post),
                icon: isProcessing 
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.close, size: 18),
                label: Text(isProcessing ? 'Processing...' : 'Reject'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.red.withOpacity(0.6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ];
        break;
      case 'active':
        actionButtons = [
          if (onComplete != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isProcessing ? null : () => onComplete!(post),
                icon: isProcessing 
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.done_all, size: 18),
                label: Text(isProcessing ? 'Processing...' : 'Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          if (onComplete != null && onReject != null) const SizedBox(width: 8),
          if (onReject != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isProcessing ? null : () => onReject!(post),
                icon: isProcessing 
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.close, size: 18),
                label: Text(isProcessing ? 'Processing...' : 'Reject'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.red.withOpacity(0.6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ];
        break;
      case 'completed':
        actionButtons = [
          if (onReopen != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isProcessing ? null : () => onReopen!(post),
                icon: isProcessing 
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.replay, size: 18),
                label: Text(isProcessing ? 'Processing...' : 'Reopen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.orange.withOpacity(0.6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ];
        break;
      case 'rejected':
        actionButtons = [
          if (onApprove != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isProcessing ? null : () => onApprove!(post),
                icon: isProcessing 
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(isProcessing ? 'Processing...' : 'Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.green.withOpacity(0.6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ];
        break;
    }

    // Add view button
    actionButtons.add(const SizedBox(width: 8));
    actionButtons.add(
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: IconButton(
          onPressed: () => onView(post),
          icon: Icon(Icons.visibility, color: Colors.grey[600]),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => onView(post),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.category, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                post.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  post.location.split(',').first, // Show only first part of location
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(post.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _getStatusColor(post.status).withOpacity(0.3)),
                      ),
                      child: Text(
                        _getStatusText(post.status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(post.status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Author and date
                FutureBuilder<String>(
                  future: getUserName(post.ownerId ?? post.submitterName),
                  builder: (context, snapshot) {
                    final userName = snapshot.data ?? 'Loading...';
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.person_outline, size: 14, color: Colors.blue[700]),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            userName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${post.createdAt.day}/${post.createdAt.month}/${post.createdAt.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Action buttons
                Row(children: actionButtons),
              ],
            ),
          ),
        ),
      ),
    );
  }
}