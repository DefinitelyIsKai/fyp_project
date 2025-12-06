import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';
import 'package:fyp_project/services/admin/post_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:fyp_project/services/user/wallet_service.dart';
import 'package:fyp_project/services/user/notification_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class PostDetailPage extends StatefulWidget {
  final JobPostModel post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final PostService _postService = PostService();
  final NotificationService _notificationService = NotificationService();
  bool _isProcessing = false;
  final TextEditingController _rejectionReasonController = TextEditingController();
  String? _ownerName;
  bool _isLoadingOwner = true;

  Future<void> _approvePost() async {
    setState(() => _isProcessing = true);
    try {
      
      await _postService.approvePost(widget.post.id);
      
      final ownerId = widget.post.ownerId;
      if (ownerId != null && ownerId.isNotEmpty) {
        try {
          final success = await WalletService.deductPostCreationCreditsForUser(
            firestore: FirebaseFirestore.instance,
            userId: ownerId,
            postId: widget.post.id,
            feeCredits: 200,
          );
          
          if (success) {
            
            try {
              await _notificationService.notifyWalletDebit(
                userId: ownerId,
                amount: 200,
                reason: 'Post creation fee',
                metadata: {
                  'postId': widget.post.id,
                  'postTitle': widget.post.title,
                  'type': 'post_creation_fee_approved',
                },
              );
            } catch (e) {
              
              debugPrint('Error sending credit deduction notification: $e');
            }
          } else {
            debugPrint('Warning: Failed to deduct credits for post ${widget.post.id}');
          }
        } catch (e) {
          
          debugPrint('Error deducting credits for post ${widget.post.id}: $e');
        }
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post approved and now active'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _rejectPost() async {
    if (_rejectionReasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a rejection reason'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final reason = _rejectionReasonController.text.trim();
      
      await _postService.rejectPost(widget.post.id, reason);
      
      final ownerId = widget.post.ownerId;
      if (ownerId != null && ownerId.isNotEmpty) {
        try {
          final success = await WalletService.releasePostCreationCreditsForUser(
            firestore: FirebaseFirestore.instance,
            userId: ownerId,
            postId: widget.post.id,
            feeCredits: 200,
          );
          
          if (success) {
            
            try {
              await _notificationService.notifyWalletCredit(
                userId: ownerId,
                amount: 200,
                reason: 'Post creation fee (Released)',
                metadata: {
                  'postId': widget.post.id,
                  'postTitle': widget.post.title,
                  'rejectionReason': reason,
                  'type': 'post_creation_fee_released',
                },
              );
            } catch (e) {
              
              debugPrint('Error sending credit release notification: $e');
            }
          } else {
            debugPrint('Warning: Failed to release credits for post ${widget.post.id}');
          }
        } catch (e) {
          
          debugPrint('Error releasing credits for post ${widget.post.id}: $e');
        }
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post rejected'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadOwnerName();
  }

  Future<void> _loadOwnerName() async {
    if (widget.post.ownerId != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.post.ownerId)
            .get();
        if (userDoc.exists && mounted) {
          setState(() {
            _ownerName = userDoc.data()?['fullName'] ?? 'Unknown User';
            _isLoadingOwner = false;
          });
        } else if (mounted) {
          setState(() {
            _ownerName = 'Unknown User';
            _isLoadingOwner = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _ownerName = 'Unknown User';
            _isLoadingOwner = false;
          });
        }
      }
    } else {
      setState(() {
        _ownerName = widget.post.submitterName ?? 'Unknown User';
        _isLoadingOwner = false;
      });
    }
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  String _formatBudget() {
    final min = widget.post.budgetMin;
    final max = widget.post.budgetMax;
    if (min == null && max == null) return 'Not specified';
    if (min != null && max != null) return 'RM ${min.toStringAsFixed(0)} - RM ${max.toStringAsFixed(0)}';
    return 'RM ${(min ?? max)!.toStringAsFixed(0)}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not specified';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  String _formatWorkTime() {
    final start = widget.post.workTimeStart;
    final end = widget.post.workTimeEnd;
    if (start != null && end != null) {
      return '$start - $end';
    }
    if (start != null) return 'From $start';
    if (end != null) return 'Until $end';
    return 'Not specified';
  }

  String _formatGenderRequirement() {
    final gender = widget.post.genderRequirement;
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

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  bool _isBase64Image(String data) {
    if (data.isEmpty) return false;
    if (data.startsWith('data:image/')) return true;
    if (data.length > 100) {
      try {
        base64Decode(data);
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  Uint8List? _decodeBase64Image(String data) {
    try {
      if (data.startsWith('data:image/')) {
        final base64String = data.split(',').last;
        return base64Decode(base64String);
      } else {
        return base64Decode(data);
      }
    } catch (e) {
      return null;
    }
  }

  Widget _buildImageAttachment(String attachment) {
    final imageBytes = _decodeBase64Image(attachment);
    if (imageBytes == null) {
      return _buildFileAttachment(attachment);
    }

    return InkWell(
      onTap: () => _showImageFullScreen(imageBytes),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          color: Colors.grey[100],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                imageBytes,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.zoom_in,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileAttachment(String attachment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              attachment.length > 30 ? '${attachment.substring(0, 30)}...' : attachment,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showImageFullScreen(Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Details'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue[700]!, Colors.blue[800]!],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.post.status.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.post.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(Icons.category, widget.post.industry, Colors.white),
                      _buildInfoChip(Icons.work, widget.post.jobType, Colors.white),
                      _buildInfoChip(Icons.attach_money, _formatBudget(), Colors.white),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Posted By',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          _isLoadingOwner
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  _ownerName ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 20, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.post.location,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.post.latitude != null && widget.post.longitude != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Coordinates: ${widget.post.latitude!.toStringAsFixed(6)}, ${widget.post.longitude!.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.blue[700],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Job Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.post.description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (widget.post.requiredSkills.isNotEmpty)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Required Skills',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.post.requiredSkills
                            .map((skill) => _buildSkillChip(skill, Colors.green))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            if (widget.post.tags.isNotEmpty)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Tags & Categories',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.post.tags
                            .map((tag) => _buildSkillChip(tag, Colors.purple))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

            if (widget.post.event != null || widget.post.eventStartDate != null || widget.post.eventEndDate != null)
              Column(
                children: [
                  const SizedBox(height: 20),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 4,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.indigo,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Event Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (widget.post.event != null)
                            _buildInfoRow('Event Type', widget.post.event!, Icons.event),
                          if (widget.post.eventStartDate != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow('Start Date', _formatDate(widget.post.eventStartDate), Icons.calendar_today),
                          ],
                          if (widget.post.eventEndDate != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow('End Date', _formatDate(widget.post.eventEndDate), Icons.event_available),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Additional Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Created At', _formatDate(widget.post.createdAt), Icons.access_time),
                    if (widget.post.completedAt != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow('Completed At', _formatDate(widget.post.completedAt), Icons.check_circle),
                    ],
                    if (widget.post.views != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow('Views', widget.post.views.toString(), Icons.visibility),
                    ],
                    if (widget.post.applicants != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow('Total Applicants', widget.post.applicants.toString(), Icons.people),
                    ],
                    if (widget.post.approvedApplicants != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow('Approved Applicants', widget.post.approvedApplicants.toString(), Icons.check_circle_outline),
                    ],
                    if (widget.post.applicantQuota != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow('Applicant Quota', widget.post.applicantQuota.toString(), Icons.group),
                    ],
                    if (widget.post.minAgeRequirement != null || widget.post.maxAgeRequirement != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        'Age Requirement',
                        widget.post.minAgeRequirement != null && widget.post.maxAgeRequirement != null
                            ? '${widget.post.minAgeRequirement} - ${widget.post.maxAgeRequirement} years'
                            : widget.post.minAgeRequirement != null
                                ? 'Minimum ${widget.post.minAgeRequirement} years'
                                : 'Maximum ${widget.post.maxAgeRequirement} years',
                        Icons.cake,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Work Time',
                      _formatWorkTime(),
                      Icons.access_time,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Gender Requirement',
                      _formatGenderRequirement(),
                      Icons.people_outline,
                    ),
                    if (widget.post.isDraft != null && widget.post.isDraft == true) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow('Draft Status', 'Yes', Icons.edit),
                    ],
                  ],
                ),
              ),
            ),

            if (widget.post.attachments != null && widget.post.attachments!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Attachments',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: widget.post.attachments!.map((attachment) {
                          final isBase64Image = _isBase64Image(attachment);
                          if (isBase64Image) {
                            return _buildImageAttachment(attachment);
                          } else {
                            return _buildFileAttachment(attachment);
                          }
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            if (widget.post.status == 'pending' || widget.post.status == 'rejected')
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.post.status == 'pending' ? 'Rejection Reason' : 'Rejection Details',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (widget.post.status == 'pending')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Required if rejecting this post',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _rejectionReasonController,
                              decoration: InputDecoration(
                                hintText: 'Enter reason for rejection...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[400]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.orange[400]!),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              maxLines: 3,
                            ),
                          ],
                        )
                      else if (widget.post.status == 'rejected')
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.orange[50],
                            border: Border.all(color: Colors.orange[100]!),
                          ),
                          child: Text(
                            widget.post.rejectionReason ?? 'No reason provided',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            if (widget.post.status == 'pending')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _approvePost,
                        icon: const Icon(Icons.check_circle, size: 20),
                        label: _isProcessing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Approve Post',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _rejectPost,
                        icon: const Icon(Icons.cancel, size: 20),
                        label: const Text(
                          'Reject Post',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}