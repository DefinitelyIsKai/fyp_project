import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user/post.dart';
import 'post_create_page.dart';
import 'post_details_page.dart';
import 'completed_posts_rating_page.dart';
import '../attendance/attendance_page.dart';
import '../../../services/user/post_service.dart';
import '../../../services/user/auth_service.dart';
import '../../../services/user/application_service.dart';
import '../../../services/user/attendance_service.dart';
import '../../../models/user/application.dart';
import '../../../utils/user/dialog_utils.dart';
import '../../../utils/user/card_decorations.dart';
import '../../../widgets/user/empty_state.dart';
import '../../../widgets/user/pagination_dots_widget.dart';
import '../../../widgets/user/attendance_view_dialog.dart';

class PostManagementPage extends StatefulWidget {
  const PostManagementPage({super.key});

  @override
  State<PostManagementPage> createState() => _PostManagementPageState();
}

class _PostManagementPageState extends State<PostManagementPage> {
  final PostService _service = PostService();
  final AuthService _authService = AuthService();
  final ApplicationService _applicationService = ApplicationService();
  final AttendanceService _attendanceService = AttendanceService();
  final PageController _pageController = PageController();

  late Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture;
  String? _currentUserId;
  
  List<List<Post>> _pages = [];
  int _currentPage = 0;
  bool _isInitialLoad = true;
  List<Post>? _lastPosts;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _userFuture = _authService.getUserDoc();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final userDoc = await _authService.getUserDoc();
      if (mounted) {
        setState(() {
          _currentUserId = userDoc.id;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentUserId = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isInitialLoad = true;
      _lastPosts = null;
      _pages.clear();
    });
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _refreshApplications() async {
    _applicationService.checkAndAutoRejectApplications();
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> _createNewPost() async {
    final bool? created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const PostCreatePage()),
    );
    if (created == true) {
      if (!mounted) return;
      DialogUtils.showSuccessMessage(
        context: context,
        message: 'Post created',
      );
    }
  }

  Widget _buildPostManagementBody() {
    return StreamBuilder<List<Post>>(
      stream: _service.streamMyPosts(includeRejected: true),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          final isIndexError = error.contains('index') || error.contains('Index');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: const Color(0xFF00C8A0), size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load your posts',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (isIndexError) ...[
                    const SizedBox(height: 16),
                    const Text(
                      ' check composite index ownerId (Asc) + createdAt (Desc)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orange, fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _createNewPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C8A0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Create New Post'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && _isInitialLoad) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF00C8A0),
            ),
          );
        }

        final allPosts = snapshot.data ?? const <Post>[];

        final postsChanged = _lastPosts == null ||
            _lastPosts!.length != allPosts.length ||
            !_listsEqual(_lastPosts!, allPosts);

        if (postsChanged) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _lastPosts = allPosts;
            setState(() {
              _pages.clear();
              for (int i = 0; i < allPosts.length; i += _itemsPerPage) {
                final end = (i + _itemsPerPage < allPosts.length) ? i + _itemsPerPage : allPosts.length;
                _pages.add(allPosts.sublist(i, end));
              }
              if (_pages.isEmpty && allPosts.isNotEmpty) {
                _pages.add(allPosts);
              }
              if (_currentPage >= _pages.length) {
                _currentPage = _pages.length > 0 ? _pages.length - 1 : 0;
              }
              if (_isInitialLoad) {
                _isInitialLoad = false;
                _currentPage = 0;
              }
            });
          });
        }

        if (allPosts.isEmpty && !_isInitialLoad) {
          return const EmptyState.noPosts();
        }

        if (_pages.isEmpty) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF00C8A0),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF00C8A0),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, pageIndex) {
                  final pagePosts = _pages[pageIndex];
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 8),
                      for (final post in pagePosts)
                        _PostCard(
                          post: post,
                          applicationService: _applicationService,
                          attendanceService: _attendanceService,
                          onView: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PostDetailsPage(post: post)),
                            );
                          },
                          onCheckAttendance: () {
                            showDialog(
                              context: context,
                              builder: (context) => AttendanceViewDialog(
                                postId: post.id,
                                applicationService: _applicationService,
                                attendanceService: _attendanceService,
                              ),
                            );
                          },
                          onEdit: () async {
                            final bool? updated = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => PostCreatePage(existing: post)),
                            );
                            if (updated == true && context.mounted) {
                              DialogUtils.showSuccessMessage(
                                context: context,
                                message: 'Post updated',
                              );
                            }
                          },
                          onDelete: () async {
                            String message;
                            if (post.isDraft) {
                              message = 'Are you sure you want to delete "${post.title}"? This action cannot be undone.';
                            } else if (post.status == PostStatus.pending) {
                              message = 'Are you sure you want to delete "${post.title}"? This action cannot be undone. Your 200 points will be refunded.';
                            } else {
                              message = 'Are you sure you want to delete "${post.title}"? This action cannot be undone.';
                            }

                            final confirmed = await DialogUtils.showDestructiveConfirmation(
                              context: context,
                              title: 'Delete Post',
                              message: message,
                              icon: Icons.delete_outline,
                              confirmText: 'Delete',
                              cancelText: 'Cancel',
                            );

                            if (confirmed == true && context.mounted) {
                              try {
                                await _service.delete(post.id);
                                if (context.mounted) {
                                  if (post.status == PostStatus.pending && !post.isDraft) {
                                    DialogUtils.showSuccessMessage(
                                      context: context,
                                      message: 'Post deleted. 200 points refunded.',
                                    );
                                  } else {
                                    DialogUtils.showInfoMessage(
                                      context: context,
                                      message: 'Post deleted',
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  DialogUtils.showWarningMessage(
                                    context: context,
                                    message: 'Failed to delete post: ${e.toString().replaceAll('Exception: ', '').replaceAll('StateError: ', '')}',
                                  );
                                }
                              }
                            }
                          },
                        ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
            ),
            if (_pages.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: PaginationDotsWidget(
                  totalPages: _pages.length,
                  currentPage: _currentPage,
                ),
              ),
          ],
          ),
        );
      },
    );
  }


  bool _listsEqual(List<Post> a, List<Post> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final postA = a[i];
      final postB = b[i];
      if (postA.id != postB.id) return false;
      if (postA.status != postB.status ||
          postA.isDraft != postB.isDraft ||
          postA.views != postB.views ||
          postA.applicants != postB.applicants ||
          postA.title != postB.title) {
        return false;
      }
    }
    return true;
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _userFuture,
      builder: (context, userSnap) {
        final data = userSnap.data?.data();
        final String role = (data?['role'] as String?)?.toLowerCase() == 'recruiter' ? 'recruiter' : 'jobseeker';
        final bool isRecruiter = role == 'recruiter';

        final Widget body = isRecruiter
            ? _buildPostManagementBody()
            : StreamBuilder<List<Application>>(
                stream: _applicationService.streamMyApplications(),
                builder: (context, appSnap) {
                  final applications = appSnap.data ?? const <Application>[];

                  if (appSnap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: const Color(0xFF00C8A0), size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'could not load applications',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              appSnap.error.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (appSnap.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFF00C8A0),
                      ),
                    );
                  }

                  if (applications.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refreshApplications,
                      color: const Color(0xFF00C8A0),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.work_outline, size: 80, color: Colors.grey[400]),
                                const SizedBox(height: 20),
                                Text(
                                  'no applications yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'apply to posts to see them here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshApplications,
                    color: const Color(0xFF00C8A0),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: applications.length,
                      itemBuilder: (context, index) {
                      final app = applications[index];
                      return StreamBuilder<Post?>(
                        stream: _service.streamPostById(app.postId),
                        builder: (context, postSnap) {
                          final post = postSnap.data;
                          if (post == null && postSnap.connectionState == ConnectionState.active) {
                            return const SizedBox.shrink();
                          }
                          if (postSnap.connectionState == ConnectionState.waiting && post == null) {
                            return const SizedBox(
                              height: 80,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00C8A0),
                                ),
                              ),
                            );
                          }
                          final bool isPostDeleted = post != null && post.status == PostStatus.deleted;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          post?.title ?? 'Post unavailable',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      _ApplicationStatusChip(status: app.status),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _dateString(app.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        onPressed: (post == null || isPostDeleted)
                                            ? null
                                            : () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => PostDetailsPage(post: post)),
                                                );
                                              },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF00C8A0),
                                          side: const BorderSide(color: Color(0xFF00C8A0)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        ),
                                        child: const Text('View Details'),
                                      ),
                                      const SizedBox(width: 8),
                                      if (app.status == ApplicationStatus.approved && post != null && !isPostDeleted)
                                        StreamBuilder(
                                          stream: _attendanceService.streamAttendanceByApplicationId(app.id),
                                          builder: (context, attendanceSnapshot) {
                                            int uploadedCount = 0;
                                            if (attendanceSnapshot.hasData && attendanceSnapshot.data != null) {
                                              final attendance = attendanceSnapshot.data;
                                              if (attendance?.hasStartImage ?? false) uploadedCount++;
                                              if (attendance?.hasEndImage ?? false) uploadedCount++;
                                            }
                                            
                                            return OutlinedButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => AttendancePage(
                                                      applicationId: app.id,
                                                      postId: app.postId,
                                                      recruiterId: app.recruiterId,
                                                    ),
                                                  ),
                                                );
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF00C8A0),
                                                side: const BorderSide(color: Color(0xFF00C8A0)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.camera_alt, size: 16),
                                                  const SizedBox(width: 4),
                                                  Text('Attendance ($uploadedCount/2)'),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      const Spacer(),
                                      if (app.status == ApplicationStatus.approved && 
                                          post != null && 
                                          !isPostDeleted && 
                                          post.status == PostStatus.completed)
                                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                                          stream: FirebaseFirestore.instance
                                              .collection('applications')
                                              .doc(app.id)
                                              .snapshots(),
                                          builder: (context, appSnapshot) {
                                            final appData = appSnapshot.data?.data();
                                            final likes = List<String>.from(appData?['likes'] as List? ?? []);
                                            final dislikes = List<String>.from(appData?['dislikes'] as List? ?? []);
                                            final hasLiked = _currentUserId != null && likes.contains(_currentUserId);
                                            final hasDisliked = _currentUserId != null && dislikes.contains(_currentUserId);
                                            
                                            return Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'Like',
                                                      icon: Icon(
                                                        hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                                                        size: 20,
                                                        color: hasLiked ? const Color(0xFF00C8A0) : Colors.grey[600],
                                                      ),
                                                      onPressed: () async {
                                                        try {
                                                          await _applicationService.toggleLikeApplication(app.id);
                                                        } catch (e) {
                                                          if (mounted) {
                                                            DialogUtils.showWarningMessage(
                                                              context: context,
                                                              message: 'Failed to update like: $e',
                                                            );
                                                          }
                                                        }
                                                      },
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      visualDensity: VisualDensity.compact,
                                                      style: IconButton.styleFrom(
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                    ),
                                                    if (likes.isNotEmpty)
                                                      Text(
                                                        '${likes.length}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[600],
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(width: 8),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'Dislike',
                                                      icon: Icon(
                                                        hasDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                                                        size: 20,
                                                        color: hasDisliked ? Colors.red : Colors.grey[600],
                                                      ),
                                                      onPressed: () async {
                                                        try {
                                                          await _applicationService.toggleDislikeApplication(app.id);
                                                        } catch (e) {
                                                          if (mounted) {
                                                            DialogUtils.showWarningMessage(
                                                              context: context,
                                                              message: 'Failed to update dislike: $e',
                                                            );
                                                          }
                                                        }
                                                      },
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      visualDensity: VisualDensity.compact,
                                                      style: IconButton.styleFrom(
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                    ),
                                                    if (dislikes.isNotEmpty)
                                                      Text(
                                                        '${dislikes.length}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey[600],
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                            );
                                          },
                                        ),
                                      if (post != null && !isPostDeleted && post.status == PostStatus.completed && app.status != ApplicationStatus.approved)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Completed',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    ),
                  );
                },
              );

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text(
              isRecruiter ? 'Post Management' : 'My Applications',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: const IconThemeData(color: Colors.black),
            automaticallyImplyLeading: false,
            actions: isRecruiter
                ? [
                    IconButton(
                      icon: const Icon(Icons.rate_review),
                      tooltip: 'Rate Applicants',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CompletedPostsRatingPage(),
                          ),
                        );
                      },
                    ),
                  ]
                : null,
          ),
          floatingActionButton: isRecruiter
              ? FloatingActionButton(
                  onPressed: _createNewPost,
                  backgroundColor: const Color(0xFF00C8A0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.add, size: 28),
                )
              : null,
          body: userSnap.connectionState == ConnectionState.waiting
              ? Center(
                  child: CircularProgressIndicator(
                    color: const Color(0xFF00C8A0),
                  ),
                )
              : body,
        );
      },
    );
  }

  String _dateString(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _ApplicationStatusChip extends StatelessWidget {
  const _ApplicationStatusChip({required this.status});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String label;

    switch (status) {
      case ApplicationStatus.pending:
        bg = Colors.orange.withOpacity(0.15);
        fg = Colors.orange;
        label = 'Pending';
        break;
      case ApplicationStatus.approved:
        bg = const Color(0xFF00C8A0).withOpacity(0.15);
        fg = const Color(0xFF00C8A0);
        label = 'Approved';
        break;
      case ApplicationStatus.rejected:
        bg = Colors.red.withOpacity(0.15);
        fg = Colors.red;
        label = 'Rejected';
        break;
      case ApplicationStatus.deleted:
        bg = Colors.red.withOpacity(0.15);
        fg = Colors.red;
        label = 'Deleted';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.applicationService,
    required this.attendanceService,
    required this.onView,
    required this.onCheckAttendance,
    required this.onEdit,
    required this.onDelete,
  });

  final Post post;
  final ApplicationService applicationService;
  final AttendanceService attendanceService;
  final VoidCallback onView;
  final VoidCallback onCheckAttendance;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isActive = !post.isDraft && post.status == PostStatus.active;
    final bool isPending = !post.isDraft && post.status == PostStatus.pending;
    final bool isRejected = post.status == PostStatus.rejected;
    final bool canMarkCompleted = post.status == PostStatus.active && !post.isDraft;
    final bool canEdit = post.isDraft; 
    final bool canDelete = post.isDraft || isPending;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: CardDecorations.standard(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: post.status == PostStatus.completed
                        ? Colors.grey.withOpacity(0.1)
                        : (isRejected
                            ? Colors.red.withOpacity(0.15)
                            : (isPending 
                                ? Colors.orange.withOpacity(0.15) 
                                : (isActive ? const Color(0xFF00C8A0).withOpacity(0.15) : Colors.orange.withOpacity(0.15)))),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    post.status == PostStatus.completed 
                        ? 'Completed' 
                        : (isRejected
                            ? 'Rejected'
                            : (isPending ? 'Pending' : (isActive ? 'Active' : 'Draft'))),
                    style: TextStyle(
                      color: post.status == PostStatus.completed
                          ? Colors.grey[700]
                          : (isRejected
                              ? Colors.red
                              : (isPending ? Colors.orange : (isActive ? const Color(0xFF00C8A0) : Colors.orange))),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _dateString(post.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(width: 16),
                Icon(Icons.remove_red_eye, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${post.views} views',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!post.isDraft)
                  OutlinedButton(
                    onPressed: onView,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00C8A0),
                      side: const BorderSide(color: Color(0xFF00C8A0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('View'),
                  ),
                if (!post.isDraft && post.status == PostStatus.completed)
                  OutlinedButton(
                    onPressed: onCheckAttendance,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00C8A0),
                      side: const BorderSide(color: Color(0xFF00C8A0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt, size: 16),
                        SizedBox(width: 4),
                        Text('Check Attendance'),
                      ],
                    ),
                  ),
                if (canEdit)
                  OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Edit'),
                  ),
                if (canDelete)
                  OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Delete'),
                  ),
                if (canMarkCompleted)
                  FilledButton(
                    onPressed: () async {
                      final confirmed = await DialogUtils.showConfirmationDialog(
                        context: context,
                        title: 'Mark as Completed',
                        message: 'Are you sure you want to mark "${post.title}" as completed? This will close the post to new applications.',
                        icon: Icons.flag,
                        confirmText: 'Mark Complete',
                        cancelText: 'Cancel',
                        isDestructive: false,
                      );

                      if (confirmed == true && context.mounted) {
                        try {
                          await PostService().markCompleted(postId: post.id);
                          if (context.mounted) {
                            DialogUtils.showSuccessMessage(
                              context: context,
                              message: 'Marked as completed.',
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            DialogUtils.showWarningMessage(
                              context: context,
                              message: 'Failed: $e',
                            );
                          }
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00C8A0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag, size: 16),
                        SizedBox(width: 4),
                        Text('Complete'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  String _dateString(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}