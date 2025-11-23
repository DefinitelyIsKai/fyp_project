import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/rating_model.dart';
import 'package:fyp_project/services/admin/rating_service.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:intl/intl.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class RatingDetailPage extends StatefulWidget {
  final RatingModel rating;

  const RatingDetailPage({super.key, required this.rating});

  @override
  State<RatingDetailPage> createState() => _RatingDetailPageState();
}

class _RatingDetailPageState extends State<RatingDetailPage> {
  final RatingService _ratingService = RatingService();
  final UserService _userService = UserService();
  final TextEditingController _notesController = TextEditingController();
  bool _isProcessing = false;
  String? _raterName;
  String? _ratedUserName;
  bool _loadingUserInfo = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    try {
      final users = await _userService.getAllUsers();
      final employer = users.firstWhere(
        (u) => u.id == widget.rating.employerId,
        orElse: () => users.first,
      );
      final employee = users.firstWhere(
        (u) => u.id == widget.rating.employeeId,
        orElse: () => users.first,
      );
      if (mounted) {
        setState(() {
          _raterName = employer.fullName;
          _ratedUserName = employee.fullName;
          _loadingUserInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingUserInfo = false);
      }
    }
  }

  Future<void> _deleteRating() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red[700], size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Rating',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this rating? The rating will be marked as deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await _ratingService.deleteRating(
        widget.rating.id,
        reason: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (mounted) {
        _showSnackBar('Rating deleted successfully', isError: false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Rating Review',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.star, size: 20, color: Colors.orange[700]),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Flagged Rating',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < widget.rating.rating.floor()
                                ? Icons.star
                                : Icons.star_border,
                            size: 32,
                            color: Colors.amber,
                          );
                        }),
                        const SizedBox(width: 12),
                        Text(
                          widget.rating.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (widget.rating.comment != null && widget.rating.comment!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.rating.comment!,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rating Details
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rating Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'Rated By (Employer)',
                      value: _loadingUserInfo
                          ? 'Loading...'
                          : (_raterName ?? widget.rating.employerId),
                    ),
                    _DetailRow(
                      label: 'Rated User (Employee)',
                      value: _loadingUserInfo
                          ? 'Loading...'
                          : (_ratedUserName ?? widget.rating.employeeId),
                    ),
                    _DetailRow(
                      label: 'Post ID',
                      value: widget.rating.postId,
                    ),
                    _DetailRow(
                      label: 'Created At',
                      value: DateFormat('MMM dd, yyyy • hh:mm a').format(widget.rating.createdAt),
                    ),
                    if (widget.rating.flaggedReason != null)
                      _DetailRow(
                        label: 'Flagged Reason',
                        value: widget.rating.flaggedReason!,
                        valueColor: Colors.red[700],
                      ),
                    if (widget.rating.reviewedBy != null) ...[
                      const Divider(),
                      _DetailRow(
                        label: 'Reviewed By',
                        value: widget.rating.reviewedBy!,
                      ),
                      if (widget.rating.reviewedAt != null)
                        _DetailRow(
                          label: 'Reviewed At',
                          value: DateFormat('MMM dd, yyyy • hh:mm a')
                              .format(widget.rating.reviewedAt!),
                        ),
                      if (widget.rating.reviewAction != null)
                        _DetailRow(
                          label: 'Action Taken',
                          value: widget.rating.reviewAction!,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Review Notes
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review Notes (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add notes about this review...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Delete Button
            if (widget.rating.status != RatingStatus.removed && 
                widget.rating.status != RatingStatus.deleted && 
                widget.rating.status != RatingStatus.pendingReview) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _deleteRating,
                  icon: const Icon(Icons.delete, size: 20),
                  label: const Text('Delete Rating'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (_isProcessing) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.rating.status == RatingStatus.removed || widget.rating.status == RatingStatus.deleted
                            ? 'This rating has already been deleted.'
                            : 'This rating cannot be deleted.',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

