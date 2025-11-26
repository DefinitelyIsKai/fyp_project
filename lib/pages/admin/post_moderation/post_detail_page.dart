import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';
import 'package:fyp_project/services/admin/post_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class PostDetailPage extends StatefulWidget {
  final JobPostModel post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final PostService _postService = PostService();
  bool _isProcessing = false;
  final TextEditingController _rejectionReasonController = TextEditingController();
  String? _ownerName;
  bool _isLoadingOwner = true;

  Future<void> _approvePost() async {
    setState(() => _isProcessing = true);
    try {
      await _postService.approvePost(widget.post.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
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
      await _postService.rejectPost(widget.post.id, _rejectionReasonController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
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
            // Header Section
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

            // Owner/Author Section
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

            // Location Section
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

            // Description Section
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

            // Skills Section
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

            // Tags Section
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

            // Event Information
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

            // Additional Information
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
                    if (widget.post.isDraft != null && widget.post.isDraft == true) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow('Draft Status', 'Yes', Icons.edit),
                    ],
                  ],
                ),
              ),
            ),

            // Attachments
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
                      ...widget.post.attachments!.map((attachment) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.attach_file, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                attachment,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Rejection Section
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

            // Action Buttons
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