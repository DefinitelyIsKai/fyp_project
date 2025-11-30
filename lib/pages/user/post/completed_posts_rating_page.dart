import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user/post.dart';
import '../../../models/user/application.dart';
import '../../../services/user/post_service.dart';
import '../../../services/user/application_service.dart';
import '../../../services/user/review_service.dart';
import '../../../services/user/auth_service.dart';
import '../../../widgets/admin/dialogs/user_dialogs/rating_dialog.dart';

class CompletedPostsRatingPage extends StatefulWidget {
  const CompletedPostsRatingPage({super.key});

  @override
  State<CompletedPostsRatingPage> createState() => _CompletedPostsRatingPageState();
}

class _CompletedPostsRatingPageState extends State<CompletedPostsRatingPage> {
  final PostService _postService = PostService();
  final ApplicationService _applicationService = ApplicationService();
  final ReviewService _reviewService = ReviewService();
  final AuthService _authService = AuthService();
  
  //cache user 
  final Map<String, String> _userNameCache = {};
  final Map<String, bool> _hasRatingCache = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Rate Applicants',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<List<Post>>(
        stream: _postService.streamMyPosts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: const Color(0xFF00C8A0), size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Could not load completed posts',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00C8A0),
              ),
            );
          }

          final allPosts = snapshot.data ?? <Post>[];
          final completedPosts = allPosts
              .where((post) => post.status == PostStatus.completed)
              .toList();

          if (completedPosts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  const Text(
                    'No completed posts yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Complete a post to rate applicants',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
              });
              await Future.delayed(const Duration(milliseconds: 100));
            },
            color: const Color(0xFF00C8A0),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: completedPosts.length,
            itemBuilder: (context, index) {
              final post = completedPosts[index];
              return _CompletedPostCard(
                post: post,
                applicationService: _applicationService,
                reviewService: _reviewService,
                authService: _authService,
                userNameCache: _userNameCache,
                hasRatingCache: _hasRatingCache,
              );
            },
            ),
          );
        },
      ),
    );
  }
}

class _CompletedPostCard extends StatefulWidget {
  final Post post;
  final ApplicationService applicationService;
  final ReviewService reviewService;
  final AuthService authService;
  final Map<String, String> userNameCache;
  final Map<String, bool> hasRatingCache;

  const _CompletedPostCard({
    required this.post,
    required this.applicationService,
    required this.reviewService,
    required this.authService,
    required this.userNameCache,
    required this.hasRatingCache,
  });

  @override
  State<_CompletedPostCard> createState() => _CompletedPostCardState();
}

class _CompletedPostCardState extends State<_CompletedPostCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(widget.post.completedAt ?? widget.post.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            StreamBuilder<List<Application>>(
              stream: widget.applicationService.streamPostApplications(widget.post.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00C8A0),
                      ),
                    ),
                  );
                }

                final applications = snapshot.data ?? <Application>[];
                //approved applications rating
                final approvedApplications = applications
                    .where((app) => app.status == ApplicationStatus.approved)
                    .toList();

                if (approvedApplications.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No approved applicants to rate',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return Column(
                  children: approvedApplications.map((application) {
                    return _ApplicantRatingCard(
                      post: widget.post,
                      application: application,
                      reviewService: widget.reviewService,
                      authService: widget.authService,
                      userNameCache: widget.userNameCache,
                      hasRatingCache: widget.hasRatingCache,
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _ApplicantRatingCard extends StatefulWidget {
  final Post post;
  final Application application;
  final ReviewService reviewService;
  final AuthService authService;
  final Map<String, String> userNameCache;
  final Map<String, bool> hasRatingCache;

  const _ApplicantRatingCard({
    required this.post,
    required this.application,
    required this.reviewService,
    required this.authService,
    required this.userNameCache,
    required this.hasRatingCache,
  });

  @override
  State<_ApplicantRatingCard> createState() => _ApplicantRatingCardState();
}

class _ApplicantRatingCardState extends State<_ApplicantRatingCard> {
  String? _applicantName;

  @override
  void initState() {
    super.initState();
    _loadApplicantInfo();
  }

  Future<void> _loadApplicantInfo() async {
    if (widget.userNameCache.containsKey(widget.application.jobseekerId)) {
      setState(() {
        _applicantName = widget.userNameCache[widget.application.jobseekerId];
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.application.jobseekerId)
          .get();
      final name = userDoc.data()?['fullName'] as String? ?? 'Unknown User';
      widget.userNameCache[widget.application.jobseekerId] = name;
      if (mounted) {
        setState(() {
          _applicantName = name;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _applicantName = 'Unknown User';
        });
      }
    }
  }

  Future<void> _showRatingDialog() async {
    await showDialog(
      context: context,
      builder: (context) => RatingDialog(
        postId: widget.post.id,
        jobseekerId: widget.application.jobseekerId,
        reviewService: widget.reviewService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF00C8A0),
            child: Text(
              (_applicantName ?? 'U')[0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _applicantName ?? 'Loading...',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Applied on ${_formatDate(widget.application.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<bool>(
            stream: widget.reviewService.streamRatingExists(
              postId: widget.post.id,
              jobseekerId: widget.application.jobseekerId,
              recruiterId: widget.authService.currentUserId,
            ),
            builder: (context, snapshot) {
              final hasRating = snapshot.data ?? false;
              
              // Update cache
              final cacheKey = '${widget.post.id}_${widget.application.jobseekerId}';
              widget.hasRatingCache[cacheKey] = hasRating;
              
              if (hasRating) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8A0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Color(0xFF00C8A0)),
                      SizedBox(width: 4),
                      Text(
                        'Rated',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00C8A0),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return FilledButton(
                  onPressed: _showRatingDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00C8A0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Rate'),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

