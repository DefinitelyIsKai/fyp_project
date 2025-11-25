import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAttachments();
    _checkUserRoleAndIncrementView();
    _loadOwnerName();
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
          // Show report button for jobseekers when post is completed
          if (_userRole == 'jobseeker' && !_isOwner && widget.post.status == PostStatus.completed)
            FutureBuilder<bool>(
              future: Future.wait([
                _applicationService.hasApplied(widget.post.id),
                _reportService.hasReportedPost(widget.post.id),
              ]).then((results) => results[0] && !results[1]),
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
          // Show report jobseekers button for owner when post is completed
          if (_isOwner && widget.post.status == PostStatus.completed)
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
                    // Store application in local variable for type promotion
                    final Application? currentApplication = application;
                    
                    // Stream post document for real-time quota updates
                    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(widget.post.id)
                          .snapshots(),
                      builder: (context, postSnapshot) {
                        Post currentPost = widget.post;
                        int approvedCount = 0;
                        
                        if (postSnapshot.hasData) {
                          final data = postSnapshot.data!.data();
                          if (data != null) {
                            // Get approved count from document
                            approvedCount = (data['approvedApplicants'] as int?) ?? 0;
                            // Reconstruct post from document data
                            try {
                              currentPost = Post.fromMap({...data, 'id': widget.post.id});
                            } catch (e) {
                              // If parsing fails, use original post
                              currentPost = widget.post;
                            }
                          }
                        }
                        
                        final applicantQuota = currentPost.applicantQuota;
                        final isQuotaReached = applicantQuota != null && 
                                              approvedCount >= applicantQuota;
                        
                        // Determine button state and text based on application status
                        final bool isDisabled = hasApplied || 
                                              currentPost.status == PostStatus.completed || 
                                              currentPost.status == PostStatus.pending ||
                                              isQuotaReached;
                        
                        String buttonText;
                        if (_isApplying) {
                          buttonText = 'Applying...';
                        } else if (hasApplied && currentApplication != null) {
                          // Show actual application status
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
                        } else {
                          buttonText = 'Apply Now - 100 points';
                        }
                        
                        return SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: (isDisabled || _isApplying)
                                ? null
                                : () => _handleApply(context),
                            style: isDisabled
                                ? ButtonStyles.disabled()
                                : ButtonStyles.primaryElevated(),
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
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
                    widget.post.title,
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
                          color: widget.post.status == PostStatus.completed
                              ? Colors.grey[100]
                              : (widget.post.status == PostStatus.pending
                                  ? Colors.orange.withOpacity(0.1)
                                  : const Color(0xFF00C8A0).withOpacity(0.1)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.post.status == PostStatus.completed
                                ? Colors.grey[300]!
                                : (widget.post.status == PostStatus.pending
                                    ? Colors.orange.withOpacity(0.3)
                                    : const Color(0xFF00C8A0).withOpacity(0.3)),
                          ),
                        ),
                        child: Text(
                          widget.post.status == PostStatus.completed 
                              ? 'COMPLETED' 
                              : (widget.post.status == PostStatus.pending ? 'PENDING' : 'ACTIVE'),
                          style: TextStyle(
                            color: widget.post.status == PostStatus.completed 
                                ? Colors.grey[600] 
                                : (widget.post.status == PostStatus.pending 
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
                        '${_daysAgo(widget.post.createdAt)} days ago',
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
                    future: FirebaseFirestore.instance.collection('posts').doc(widget.post.id).get(),
                    builder: (context, snapshot) {
                      final data = snapshot.data?.data();
                      final views = data?['views'] as int? ?? widget.post.views;
                      return Row(
                        children: [
                          Icon(Icons.remove_red_eye, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text('$views views', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                          const SizedBox(width: 16),
                          Icon(Icons.people_alt, size: 16, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text('${widget.post.applicants} applicants', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Quick Info Card
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
                  _buildInfoRow('Event Type', widget.post.event.isNotEmpty ? widget.post.event : 'Not specified'),
                  const SizedBox(height: 16),
                  _buildInfoRow('Event Date', _formatEventDate()),
                  const SizedBox(height: 16),
                  _buildInfoRow('Budget Range', _budgetText(widget.post)),
                  const SizedBox(height: 16),
                  _buildInfoRow('Availability', widget.post.jobType.label),
                ],
              ),
            ),
            
            // Description Card
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
                      widget.post.description.isNotEmpty 
                          ? widget.post.description 
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
            
            // Location Card
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
                  if (widget.post.latitude != null && widget.post.longitude != null)
                    _buildMapView()
                  else
                    _buildLocationText(),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Skills Card
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
                  if (widget.post.tags.isNotEmpty)
                    _buildSkillsGrid()
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
            
            if (_hasRequirementsSection) ...[
              const SizedBox(height: 16),
              _buildRequirementsCard(),
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
            
            const SizedBox(height: 20),
          ],
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

  Widget _buildLocationText() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.grey[500], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.post.location.isNotEmpty 
                  ? widget.post.location 
                  : 'Location not specified',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.post.tags.map((tag) {
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

  bool get _hasRequirementsSection {
    // Only show requirements section if there are age or quota requirements
    // Skills are already shown in Categories & Skills section
    return widget.post.minAgeRequirement != null ||
        widget.post.maxAgeRequirement != null ||
        widget.post.applicantQuota != null;
  }

  Widget _buildRequirementsCard() {
    final hasAge = widget.post.minAgeRequirement != null || widget.post.maxAgeRequirement != null;
    final hasQuota = widget.post.applicantQuota != null;

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
              value: _formatAgeRequirement(),
            ),
          if (hasQuota) ...[
            if (hasAge) const SizedBox(height: 12),
            _RequirementRow(
              label: 'Applicant Quota',
              value: '${widget.post.applicantQuota} candidates',
            ),
          ],
        ],
      ),
    );
  }

  String _formatAgeRequirement() {
    final min = widget.post.minAgeRequirement;
    final max = widget.post.maxAgeRequirement;
    if (min != null && max != null) {
      return '$min - $max years old';
    }
    if (min != null) return 'At least $min years old';
    if (max != null) return 'Up to $max years old';
    return 'Not specified';
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

  String _formatEventDate() {
    final startDate = widget.post.eventStartDate;
    final endDate = widget.post.eventEndDate;
    
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
      // Check if same day
      if (startDate.year == endDate.year &&
          startDate.month == endDate.month &&
          startDate.day == endDate.day) {
        // Same day: "Dec 25, 2024, 9:00 AM - 5:00 PM"
        return '${formatDate(startDate)}, ${formatTime(startDate)} - ${formatTime(endDate)}';
      } else {
        // Different days: "Dec 25, 2024 - Dec 27, 2024"
        return '${formatDate(startDate)} - ${formatDate(endDate)}';
      }
    } else if (startDate != null) {
      // Only start date: "Dec 25, 2024, 9:00 AM"
      return '${formatDate(startDate)}, ${formatTime(startDate)}';
    } else {
      // Only end date: "Until Dec 27, 2024, 5:00 PM"
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

  Widget _buildMapView() {
    final position = LatLng(widget.post.latitude!, widget.post.longitude!);
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: position,
            zoom: 14,
          ),
          markers: {
            Marker(
              markerId: MarkerId(widget.post.id),
              position: position,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            ),
          },
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
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
    // Prevent multiple simultaneous executions
    if (_isApplying || !mounted) return;
    
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
      
      // Refresh the page by replacing the current route
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
      DialogUtils.showWarningMessage(
        context: context,
        message: insufficient
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
    // Show confirmation dialog first
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

    // Show the report form dialog
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
    // Show confirmation dialog first
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

    // Show the jobseeker list dialog
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
