import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/user/post.dart';
import '../../../models/user/application.dart';
import '../../../services/user/post_service.dart';
import '../../../services/user/wallet_service.dart';
import '../../../services/user/application_service.dart';
import '../../../services/user/auth_service.dart';
import '../../../services/user/report_service.dart';
import '../../../utils/user/dialog_utils.dart';
import '../../../utils/user/button_styles.dart';
import '../../../widgets/admin/dialogs/user_dialogs/report_post_dialog.dart';
import '../../../widgets/admin/dialogs/user_dialogs/report_jobseeker_list_dialog.dart';

class PostDetailsPage extends StatefulWidget {
  const PostDetailsPage({super.key, required this.post});

  final Post post;

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  static final PostService _service = PostService();
  static final WalletService _wallet = WalletService();
  static final ApplicationService _applicationService = ApplicationService();
  static final AuthService _authService = AuthService();
  static final ReportService _reportService = ReportService();
  GoogleMapController? _mapController;
  List<Map<String, dynamic>> _attachments = [];
  bool _isOwner = false;
  String? _userRole;
  bool _isApplying = false;
  String? _ownerName;
  String? _rejectionReason;
  int _refreshKey = 0;
  PostStatus? _currentPostStatus; 

  @override
  void initState() {
    super.initState();
    _currentPostStatus = widget.post.status;
    _loadAttachments();
    _checkUserRoleAndIncrementView();
    _loadOwnerName();
    _loadRejectionReason();
  }

  Future<void> _loadRejectionReason() async {
    if (widget.post.status == PostStatus.rejected) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.post.id)
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (mounted) {
            setState(() {
              _rejectionReason = data?['rejectionReason'] as String?;
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading rejection reason: $e');
      }
    }
  }

  Future<void> _checkUserRoleAndIncrementView() async {
    try {
      final userDoc = await _authService.getUserDoc();
      final userId = userDoc.id;
      final rawRole = userDoc.data()?['role'] as String?;
      final role = (rawRole ?? 'jobseeker').toLowerCase();
      
      setState(() {
        _isOwner = userId == widget.post.ownerId;
        _userRole = role;
      });
      
      if (role == 'jobseeker' && userId != widget.post.ownerId) {
        await _service.incrementViewCount(postId: widget.post.id);
      }
    } catch (e) {
      debugPrint('Error checking user role or incrementing view: $e');
      setState(() {
        _isOwner = false;
        _userRole = 'jobseeker';
      });
    }
  }

  Future<void> _loadAttachments() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('posts').doc(widget.post.id).get();
      final data = doc.data();
      if (data != null && data['attachments'] != null) {
        final attachments = data['attachments'] as List?;
        if (attachments != null) {
          setState(() {
            _attachments = attachments.map((a) {
              if (a is Map) {
                return Map<String, dynamic>.from(a);
              } else if (a is String) {
                return {'base64': a, 'fileType': 'jpg'};
              }
              return <String, dynamic>{};
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading attachments: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _refreshKey++;
    });
    await Future.wait([
      _loadAttachments(),
      _checkUserRoleAndIncrementView(),
      _loadOwnerName(),
      _loadRejectionReason(),
    ]);
  }

  Future<void> _loadOwnerName() async {
    try {
      final ownerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.post.ownerId)
          .get();
      
      if (ownerDoc.exists && mounted) {
        final data = ownerDoc.data();
        setState(() {
          _ownerName = (data?['fullName'] as String?)?.trim();
          if (_ownerName == null || _ownerName!.isEmpty) {
            _ownerName = 'Unknown User';
          }
        });
      } else if (mounted) {
        setState(() {
          _ownerName = 'Unknown User';
        });
      }
    } catch (e) {
      debugPrint('Error loading owner name: $e');
      if (mounted) {
        setState(() {
          _ownerName = 'Unknown User';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Job Details',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          //report button post is active or completed
          if (_userRole == 'jobseeker' && !_isOwner && _currentPostStatus != null && (_currentPostStatus == PostStatus.completed || _currentPostStatus == PostStatus.active))
            FutureBuilder<bool>(
              future: Future.wait([
                _applicationService.hasApplied(widget.post.id),
                _reportService.hasReportedPost(widget.post.id),
              ]).then((results) {
                final hasApplied = results[0];
                final hasReported = results[1];
                final shouldShow = hasApplied && !hasReported;
                debugPrint('Report button check - hasApplied: $hasApplied, hasReported: $hasReported, shouldShow: $shouldShow');
                return shouldShow;
              }),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                if (snapshot.data == true) {
                  return IconButton(
                    icon: const Icon(Icons.flag_outlined, color: Colors.red),
                    tooltip: 'Report Post',
                    onPressed: () => _showReportPostDialog(context),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          // recruiter post is completed
          if (_isOwner && _currentPostStatus != null && _currentPostStatus == PostStatus.completed)
            IconButton(
              icon: const Icon(Icons.flag_outlined, color: Colors.red),
              tooltip: 'Report Jobseeker',
              onPressed: () => _showReportJobseekerListDialog(context),
            ),
        ],
      ),
      bottomNavigationBar: (_userRole == 'jobseeker' && !_isOwner)
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: StreamBuilder<Application?>(
                  stream: _applicationService.streamApplicationForPost(widget.post.id),
                  builder: (context, applicationSnapshot) {
                    final application = applicationSnapshot.data;
                    final bool hasApplied = application != null;
                    final Application? currentApplication = application;
                    
                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(widget.post.id)
                          .snapshots()
                          .handleError((error) {
                           
                            debugPrint('Error in post stream (likely during logout): $error');
                          }),
                      builder: (context, postSnapshot) {
                        Post currentPost = widget.post;
                        int approvedCount = 0;
                        
                        if (postSnapshot.hasData) {
                          final data = postSnapshot.data!.data();
                          if (data != null) {
                            int? _parseInt(dynamic value) {
                              if (value == null) return null;
                              if (value is int) return value;
                              if (value is double) return value.toInt();
                              if (value is num) return value.toInt();
                              if (value is String) return int.tryParse(value);
                              return null;
                            }
                            approvedCount = _parseInt(data['approvedApplicants']) ?? 0;
                            try {
                              currentPost = Post.fromMap({...data, 'id': widget.post.id});
                            } catch (e) {
                              currentPost = widget.post;
                            }
                          }
                        }
                        
                        final applicantQuota = currentPost.applicantQuota;
                        final isQuotaReached = applicantQuota != null && approvedCount >= applicantQuota;
                        
                        bool isEventStartingSoon = false;
                        if (currentPost.eventStartDate != null) {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final eventStartDate = currentPost.eventStartDate!;
                          final eventStartDateOnly = DateTime(
                            eventStartDate.year,
                            eventStartDate.month,
                            eventStartDate.day,
                          );
                          isEventStartingSoon = eventStartDateOnly.isAtSameMomentAs(today) || eventStartDateOnly.isBefore(today);
                        }
                        
                        final bool isDisabled = hasApplied || 
                                              currentPost.status == PostStatus.completed || 
                                              currentPost.status == PostStatus.pending ||
                                              isQuotaReached ||
                                              isEventStartingSoon;
                        
                        String buttonText;
                        if (_isApplying) {
                          buttonText = 'Applying...';
                        } else if (hasApplied && currentApplication != null) {
                          switch (currentApplication.status) {
                            case ApplicationStatus.pending:
                              buttonText = 'Application Pending';
                              break;
                            case ApplicationStatus.approved:
                              buttonText = 'Application Approved';
                              break;
                            case ApplicationStatus.rejected:
                              buttonText = 'Application Rejected';
                              break;
                            case ApplicationStatus.deleted:
                              buttonText = 'Application Submitted';
                              break;
                          }
                        } else if (currentPost.status == PostStatus.completed) {
                          buttonText = 'Job Completed';
                        } else if (currentPost.status == PostStatus.pending) {
                          buttonText = 'Pending Review';
                        } else if (isQuotaReached) {
                          buttonText = 'Quota Full';
                        } else if (isEventStartingSoon) {
                          buttonText = 'Event Starts';
                        } else {
                          buttonText = 'Apply Now - 100 points';
                        }
                        return SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: (isDisabled || _isApplying)? null : () => _handleApply(context),
                            style: isDisabled ? ButtonStyles.disabled(): ButtonStyles.primaryElevated(),
                            child: Text(
                              buttonText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF00C8A0),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          key: ValueKey('post_stream_${widget.post.id}_$_refreshKey'),
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.post.id)
              .snapshots()
              .handleError((error) {
                debugPrint('Error in post stream: $error');
              }),
          builder: (context, postSnapshot) {
            Post currentPost = widget.post;
            if (postSnapshot.hasData && postSnapshot.data!.exists) {
              final data = postSnapshot.data!.data();
              if (data != null) {
                try {
                  currentPost = Post.fromMap({...data, 'id': widget.post.id});
                  if (mounted && _currentPostStatus != currentPost.status) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _currentPostStatus = currentPost.status;
                        });
                      }
                    });
                  }
                } catch (e) {
                  debugPrint('Error parsing post data: $e');
                  currentPost = widget.post;
                }
              }
            }
            
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF00C8A0), width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentPost.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: currentPost.status == PostStatus.completed
                                    ? Colors.grey[100]
                                    : (currentPost.status == PostStatus.pending
                                        ? Colors.orange.withOpacity(0.1)
                                        : const Color(0xFF00C8A0).withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: currentPost.status == PostStatus.completed
                                      ? Colors.grey[300]!
                                      : (currentPost.status == PostStatus.pending
                                          ? Colors.orange.withOpacity(0.3)
                                          : const Color(0xFF00C8A0).withOpacity(0.3)),
                                ),
                              ),
                              child: Text(
                                currentPost.status == PostStatus.completed 
                                    ? 'COMPLETED' 
                                    : (currentPost.status == PostStatus.pending ? 'PENDING' : 'ACTIVE'),
                                style: TextStyle(
                                  color: currentPost.status == PostStatus.completed 
                                      ? Colors.grey[600] 
                                      : (currentPost.status == PostStatus.pending 
                                          ? Colors.orange 
                                          : const Color(0xFF00C8A0)),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.schedule, size: 16, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              '${_daysAgo(currentPost.createdAt)} days ago',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_ownerName != null) ...[
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                'Posted by $_ownerName',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance.collection('posts').doc(currentPost.id).get(),
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data();
                      int? _parseInt(dynamic value) {
                        if (value == null) return null;
                        if (value is int) return value;
                        if (value is double) return value.toInt();
                        if (value is num) return value.toInt();
                        if (value is String) return int.tryParse(value);
                        return null;
                      }
                      final views = _parseInt(data?['views']) ?? widget.post.views;
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('applications')
                            .where('postId', isEqualTo: currentPost.id)
                            .snapshots(),
                        builder: (context, appsSnapshot) {
                          final applications = appsSnapshot.data?.docs ?? [];
                          int totalLikes = 0;
                          int totalDislikes = 0;
                          
                          for (final doc in applications) {
                            final data = doc.data();
                            final likes = List<String>.from(data['likes'] as List? ?? []);
                            final dislikes = List<String>.from(data['dislikes'] as List? ?? []);
                            totalLikes += likes.length;
                            totalDislikes += dislikes.length;
                          }
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // First row: views and applicants
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.remove_red_eye, size: 16, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text('$views views', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.people_alt, size: 16, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text('${widget.post.applicants} applicants', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                    ],
                                  ),
                                ],
                              ),
                              // Second row: likes and dislikes in the same row
                              if (applications.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    // Like display with enhanced styling
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00C8A0).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFF00C8A0).withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.thumb_up,
                                            size: 16,
                                            color: totalLikes > 0 ? const Color(0xFF00C8A0) : Colors.grey[500],
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$totalLikes',
                                            style: TextStyle(
                                              color: totalLikes > 0 ? const Color(0xFF00C8A0) : Colors.grey[600],
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (totalLikes != 1) ...[
                                            const SizedBox(width: 2),
                                            Text(
                                              'likes',
                                              style: TextStyle(
                                                color: totalLikes > 0 ? const Color(0xFF00C8A0) : Colors.grey[600],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ] else ...[
                                            const SizedBox(width: 2),
                                            Text(
                                              'like',
                                              style: TextStyle(
                                                color: totalLikes > 0 ? const Color(0xFF00C8A0) : Colors.grey[600],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Dislike display with enhanced styling
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.thumb_down,
                                            size: 16,
                                            color: totalDislikes > 0 ? Colors.red : Colors.grey[500],
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$totalDislikes',
                                            style: TextStyle(
                                              color: totalDislikes > 0 ? Colors.red : Colors.grey[600],
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (totalDislikes != 1) ...[
                                            const SizedBox(width: 2),
                                            Text(
                                              'dislikes',
                                              style: TextStyle(
                                                color: totalDislikes > 0 ? Colors.red : Colors.grey[600],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ] else ...[
                                            const SizedBox(width: 2),
                                            Text(
                                              'dislike',
                                              style: TextStyle(
                                                color: totalDislikes > 0 ? Colors.red : Colors.grey[600],
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoRow('Event Type', currentPost.event.isNotEmpty ? currentPost.event : 'Not specified'),
                  const SizedBox(height: 16),
                  _buildInfoRow('Event Date', _formatEventDate(currentPost)),
                  const SizedBox(height: 16),
                  _buildInfoRow('Budget Range', _budgetText(currentPost)),
                  const SizedBox(height: 16),
                  _buildInfoRow('Availability', currentPost.jobType.label),
                  const SizedBox(height: 16),
                  _buildInfoRow('Work Time', _formatWorkTime(currentPost)),
                ],
              ),
            ),
            
            //desc
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, size: 20, color: const Color(0xFF00C8A0)),
                      const SizedBox(width: 8),
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      currentPost.description.isNotEmpty 
                          ? currentPost.description 
                          : 'No description provided',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            //location
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 20, color: const Color(0xFF00C8A0)),
                      const SizedBox(width: 8),
                      const Text(
                        'Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (currentPost.latitude != null && currentPost.longitude != null) ...[
                    _buildMapView(currentPost),
                    const SizedBox(height: 12),
                    _buildLocationText(post: currentPost, showAsTextOnly: true),
                  ] else
                    _buildLocationText(post: currentPost),
                ],
              ),
            ),
            const SizedBox(height: 16),
            //skill
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.category, size: 20, color: const Color(0xFF00C8A0)),
                      const SizedBox(width: 8),
                      const Text(
                        'Categories & Skills',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (currentPost.tags.isNotEmpty)
                    _buildSkillsGrid(currentPost)
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        'No skills specified',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            
            if (_hasRequirementsSection(currentPost)) ...[
              const SizedBox(height: 16),
              _buildRequirementsCard(currentPost),
            ],
            
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.attachment, size: 20, color: const Color(0xFF00C8A0)),
                        const SizedBox(width: 8),
                        const Text(
                          'Attachments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildAttachments(),
                  ],
                ),
              ),
            ],
            
            //rejection reason 
            if (currentPost.status == PostStatus.rejected && _rejectionReason != null && _rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cancel_outlined, size: 20, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Rejection Reason',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                      ),
                      child: Text(
                        _rejectionReason!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 20),
          ],
        ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationText({required Post post, bool showAsTextOnly = false}) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('posts')
          .doc(post.id)
          .get(),
      builder: (context, snapshot) {
        String location = post.location;
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('location')) {
            final firebaseLocation = data['location'];
            if (firebaseLocation != null) {
              location = firebaseLocation.toString();
            }
          }
        }
        
        if (showAsTextOnly) {
          return snapshot.connectionState == ConnectionState.waiting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  location.isNotEmpty 
                      ? location 
                      : 'Location not specified',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 15,
                  ),
                );
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: snapshot.connectionState == ConnectionState.waiting
              ? Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey[500], size: 20),
                    const SizedBox(width: 12),
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey[500], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        location.isNotEmpty ? location : 'Location not specified',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSkillsGrid(Post post) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: post.tags.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF00C8A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00C8A0).withOpacity(0.3)),
          ),
          child: Text(
            tag,
            style: const TextStyle(
              color: Color(0xFF00C8A0),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _hasRequirementsSection(Post post) {
    return post.minAgeRequirement != null ||
        post.maxAgeRequirement != null ||
        post.applicantQuota != null ||
        (post.genderRequirement != null && post.genderRequirement!.isNotEmpty);
  }

  Widget _buildRequirementsCard(Post post) {
    final hasAge = post.minAgeRequirement != null || post.maxAgeRequirement != null;
    final hasQuota = post.applicantQuota != null;
    final hasGender = post.genderRequirement != null && post.genderRequirement!.isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule, size: 20, color: const Color(0xFF00C8A0)),
              const SizedBox(width: 8),
              const Text(
                'Candidate Requirements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasAge)
            _RequirementRow(
              label: 'Age Requirement',
              value: _formatAgeRequirement(post),
            ),
          if (hasQuota) ...[
            if (hasAge) const SizedBox(height: 12),
            _RequirementRow(
              label: 'Applicant Quota',
              value: '${post.applicantQuota} candidates',
            ),
          ],
          if (hasGender) ...[
            if (hasAge || hasQuota) const SizedBox(height: 12),
            _RequirementRow(
              label: 'Gender Requirement',
              value: _formatGenderRequirement(post),
            ),
          ],
        ],
      ),
    );
  }

  String _formatAgeRequirement(Post post) {
    final min = post.minAgeRequirement;
    final max = post.maxAgeRequirement;
    if (min != null && max != null) {
      return '$min - $max years old';
    }
    if (min != null) return 'At least $min years old';
    if (max != null) return 'Up to $max years old';
    return 'Not specified';
  }

  String _formatWorkTime(Post post) {
    final start = post.workTimeStart;
    final end = post.workTimeEnd;
    if (start != null && end != null) {
      return '$start - $end';
    }
    if (start != null) return 'From $start';
    if (end != null) return 'Until $end';
    return 'Not specified';
  }

  String _formatGenderRequirement(Post post) {
    final gender = post.genderRequirement;
    if (gender == null || gender.isEmpty) {
      return 'Not specified';
    }
    switch (gender.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'any':
        return 'Any';
      default:
        return gender;
    }
  }

  static int _daysAgo(DateTime createdAt) {
    return DateTime.now().difference(createdAt).inDays;
  }

  static String _budgetText(Post p) {
    if (p.budgetMin != null && p.budgetMax != null) {
      return '\$${p.budgetMin!.round()} - \$${p.budgetMax!.round()}';
    }
    if (p.budgetMin != null) return 'From \$${p.budgetMin!.round()}';
    if (p.budgetMax != null) return 'Up to \$${p.budgetMax!.round()}';
    return 'Not specified';
  }

  String _formatEventDate(Post post) {
    final startDate = post.eventStartDate;
    final endDate = post.eventEndDate;
    
    if (startDate == null && endDate == null) {
      return 'Not specified';
    }
    
    String formatDate(DateTime date) {
      final month = _getMonthAbbreviation(date.month);
      return '${month} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
    }
    
    String formatTime(DateTime date) {
      final hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour < 12 ? 'AM' : 'PM';
      return '$hour:$minute $period';
    }
    
    if (startDate != null && endDate != null) {
      
      if (startDate.year == endDate.year && startDate.month == endDate.month && startDate.day == endDate.day) {
        return '${formatDate(startDate)}, ${formatTime(startDate)} - ${formatTime(endDate)}';
      } else {
        return '${formatDate(startDate)} - ${formatDate(endDate)}';
      }
    } else if (startDate != null) {
      return '${formatDate(startDate)}, ${formatTime(startDate)}';
    } else {
      return 'Until ${formatDate(endDate!)}, ${formatTime(endDate)}';
    }
  }
  
  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildMapView(Post post) {
    final position = LatLng(post.latitude!, post.longitude!);
    return GestureDetector(
      onTap: () => _showFullScreenMap(position, post),
      onDoubleTap: () => _showFullScreenMap(position, post),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: position,
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: MarkerId(post.id),
                    position: position,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  ),
                },
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                scrollGesturesEnabled: false,
                zoomGesturesEnabled: false,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: false,
                onTap: (LatLng location) {
                  _showFullScreenMap(position, post);
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fullscreen,
                  size: 20,
                  color: Color(0xFF00C8A0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenMap(LatLng postPosition, Post post) {
    Future<String> getLocationFromFirebase() async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(post.id)
            .get();
        if (doc.exists) {
          final data = doc.data();
          final location = data?['location']?.toString();
          if (location != null && location.isNotEmpty) {
            return location;
          }
        }
      } catch (e) {
        debugPrint('Error loading location from Firebase: $e');
      }
      return post.location.isNotEmpty ? post.location : 'Location';
    }

    Future<Position?> getCurrentLocation() async {
      try {
        
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('Location services are disabled');
          return null;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            debugPrint('Location permissions are denied');
            return null;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          debugPrint('Location permissions are permanently denied');
          return null;
        }
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        return position;
      } catch (e) {
        debugPrint('Error getting current location: $e');
        return null;
      }
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: Future.wait([
          getLocationFromFirebase(),
          getCurrentLocation(),
        ]).then((results) => {
          'locationText': results[0] as String,
          'userPosition': results[1] as Position?,
        }),
        builder: (context, snapshot) {
          final locationText = snapshot.data?['locationText'] ?? post.location;
          final userPosition = snapshot.data?['userPosition'] as Position?;
          
          Set<Marker> markers = {
            Marker(
              markerId: MarkerId('post_${post.id}'),
              position: postPosition,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: post.title,
                snippet: locationText.isNotEmpty ? locationText : 'Job Location',
              ),
            ),
          };

          LatLng? userLatLng;
          if (userPosition != null) {
            userLatLng = LatLng(userPosition.latitude, userPosition.longitude);
          }

          CameraPosition initialCameraPosition;
          if (userLatLng != null) {
            double centerLat = (postPosition.latitude + userLatLng.latitude) / 2;
            double centerLng = (postPosition.longitude + userLatLng.longitude) / 2;
            
            double distance = Geolocator.distanceBetween(
              postPosition.latitude,
              postPosition.longitude,
              userLatLng.latitude,
              userLatLng.longitude,
            );
            
            double zoom = 12.0;
            if (distance > 10000) zoom = 10.0;
            else if (distance > 5000) zoom = 11.0;
            else if (distance > 1000) zoom = 12.0;
            else if (distance > 500) zoom = 13.0;
            else zoom = 14.0;
            
            initialCameraPosition = CameraPosition(
              target: LatLng(centerLat, centerLng),
              zoom: zoom,
            );
          } else {
            initialCameraPosition = CameraPosition(
              target: postPosition,
              zoom: 15,
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: GoogleMap(
                    initialCameraPosition: initialCameraPosition,
                    markers: markers,
                    myLocationEnabled: true, 
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: true,
                    onMapCreated: (GoogleMapController controller) {
                      if (userLatLng != null) {
                        controller.animateCamera(
                          CameraUpdate.newLatLngBounds(
                            LatLngBounds(
                              southwest: LatLng(
                                postPosition.latitude < userLatLng.latitude 
                                    ? postPosition.latitude 
                                    : userLatLng.latitude,
                                postPosition.longitude < userLatLng.longitude 
                                    ? postPosition.longitude 
                                    : userLatLng.longitude,
                              ),
                              northeast: LatLng(
                                postPosition.latitude > userLatLng.latitude 
                                    ? postPosition.latitude 
                                    : userLatLng.latitude,
                                postPosition.longitude > userLatLng.longitude 
                                    ? postPosition.longitude 
                                    : userLatLng.longitude,
                              ),
                            ),
                            100.0,
                          ),
                        );
                      }
                    },
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttachments() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 100,
      ),
      itemCount: _attachments.length,
      itemBuilder: (context, index) {
        final attachment = _attachments[index];
        final base64 = attachment['base64'] as String?;
        if (base64 == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => _showImageFullScreen(base64),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(base64),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[100],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.grey[400], size: 24),
                        const SizedBox(height: 4),
                        Text(
                          'Unable to load',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImageFullScreen(String base64) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withOpacity(0.9),
              ),
              child: Center(
                child: InteractiveViewer(
                  child: Image.memory(
                    base64Decode(base64),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApply(BuildContext context) async {
    //no multiple apply
    if (_isApplying || !mounted) return;
    
    if (widget.post.eventStartDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final eventStartDate = widget.post.eventStartDate!;
      final eventStartDateOnly = DateTime(
        eventStartDate.year,
        eventStartDate.month,
        eventStartDate.day,
      );
      if (eventStartDateOnly.isAtSameMomentAs(today) || 
          eventStartDateOnly.isBefore(today)) {
        if (!mounted) return;
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Applications are no longer accepted. The event has started or starts soon.',
        );
        return;
      }
    }
    
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Apply to Job',
      message: 'Are you sure you want to apply to "${widget.post.title}"? This will hold 100 points until the recruiter makes a decision.',
      icon: Icons.work_outline,
      confirmText: 'Apply',
      cancelText: 'Cancel',
      isDestructive: false,
    );
    
    if (confirmed != true || !mounted) return;
    
    setState(() {
      _isApplying = true;
    });
    
    try {
      await _wallet.chargeApplication(postId: widget.post.id, feeCredits: 100);
      await _applicationService.createApplication(
        postId: widget.post.id,
        recruiterId: widget.post.ownerId,
      );
      
      if (!mounted) return;
      
      DialogUtils.showSuccessMessage(
        context: context,
        message: 'Application submitted successfully! 100 points on hold.',
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailsPage(post: widget.post),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final bool insufficient = e.toString().contains('INSUFFICIENT_FUNDS');
      final bool alreadyExists = e.toString().contains('already exists');
      final bool postCompleted = e.toString().contains('POST_COMPLETED');
      final bool notVerified = e.toString().contains('USER_NOT_VERIFIED');
      DialogUtils.showWarningMessage(
        context: context,
        message: notVerified
            ? 'Your account must be verified before you can apply for jobs. Please complete the verification process in your profile.'
            : insufficient
                ? 'Insufficient credits. You need 100 points to apply.'
                : alreadyExists
                    ? 'You have already applied to this job.'
                    : postCompleted
                        ? 'This post has been completed. Applications are no longer being accepted.'
                        : 'Error processing application. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  Future<void> _showReportPostDialog(BuildContext context) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Report Post',
      message: 'Are you sure you want to report "${widget.post.title}"? This action will submit a report to our moderation team.',
      icon: Icons.flag_outlined,
      confirmText: 'Continue',
      cancelText: 'Cancel',
      isDestructive: false,
    );

    if (confirmed != true || !context.mounted) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const ReportPostDialog(),
    );

    if (result != null && result['reason'] != null) {
      try {
        await _reportService.reportPost(
          postId: widget.post.id,
          reason: result['reason']!,
          description: result['description'] ?? '',
        );
        if (context.mounted) {
          DialogUtils.showSuccessMessage(
            context: context,
            message: 'Report submitted successfully. Thank you for your feedback.',
          );
        }
      } catch (e) {
        if (context.mounted) {
          DialogUtils.showWarningMessage(
            context: context,
            message: e.toString().replaceAll('Exception: ', ''),
          );
        }
      }
    }
  }

  Future<void> _showReportJobseekerListDialog(BuildContext context) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Report Jobseeker',
      message: 'You are about to report a jobseeker who worked on this job. Please select the jobseeker you wish to report.',
      icon: Icons.flag_outlined,
      confirmText: 'Continue',
      cancelText: 'Cancel',
      isDestructive: false,
    );

    if (confirmed != true || !context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) => ReportJobseekerListDialog(
        postId: widget.post.id,
        reportService: _reportService,
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}


class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, size: 18, color: const Color(0xFF00C8A0)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}