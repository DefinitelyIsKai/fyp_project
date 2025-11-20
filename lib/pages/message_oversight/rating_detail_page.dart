import 'package:flutter/material.dart';
import 'package:fyp_project/models/rating_model.dart';
import 'package:fyp_project/services/rating_service.dart';
import 'package:fyp_project/services/user_service.dart';
import 'package:fyp_project/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
      final rater = users.firstWhere(
        (u) => u.id == widget.rating.raterId,
        orElse: () => users.first,
      );
      final ratedUser = users.firstWhere(
        (u) => u.id == widget.rating.ratedUserId,
        orElse: () => users.first,
      );
      if (mounted) {
        setState(() {
          _raterName = rater.fullName;
          _ratedUserName = ratedUser.fullName;
          _loadingUserInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingUserInfo = false);
      }
    }
  }

  Future<void> _takeAction(String action) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final reviewerId = authService.currentAdmin?.id ?? 'admin';

    if (action == 'warning' || action == 'suspend') {
      final confirmed = await _showActionConfirmation(action);
      if (!confirmed) return;
    }

    setState(() => _isProcessing = true);
    try {
      await _ratingService.reviewRating(
        ratingId: widget.rating.id,
        action: action,
        reviewedBy: reviewerId,
        reviewNotes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      // If warning or suspend, also take action on the user
      if (action == 'warning') {
        await _userService.issueWarning(
          userId: widget.rating.raterId,
          violationReason: 'Inappropriate rating content: ${widget.rating.flaggedReason ?? "Violation of community guidelines"}',
        );
      } else if (action == 'suspend') {
        await _userService.suspendUser(
          widget.rating.raterId,
          violationReason: 'Severe rating violation: ${widget.rating.flaggedReason ?? "Violation of community guidelines"}',
          durationDays: 7,
        );
      }

      if (mounted) {
        _showSnackBar('Rating reviewed successfully. Action: ${action.toUpperCase()}', isError: false);
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

  Future<bool> _showActionConfirmation(String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              action == 'warning' ? Icons.warning : Icons.pause_circle_outline,
              color: action == 'warning' ? Colors.orange : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(action == 'warning' ? 'Issue Warning' : 'Suspend User'),
          ],
        ),
        content: Text(
          action == 'warning'
              ? 'This will issue a warning to the rater. After 3 warnings, their account will be automatically suspended.'
              : 'This will suspend the rater\'s account for 7 days. They will not be able to access the platform during this time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'warning' ? Colors.orange : Colors.red,
            ),
            child: Text(action == 'warning' ? 'Issue Warning' : 'Suspend User'),
          ),
        ],
      ),
    );
    return result ?? false;
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
        backgroundColor: Colors.blue[700],
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
                      label: 'Rated By',
                      value: _loadingUserInfo
                          ? 'Loading...'
                          : (_raterName ?? widget.rating.raterId),
                    ),
                    _DetailRow(
                      label: 'Rated User',
                      value: _loadingUserInfo
                          ? 'Loading...'
                          : (_ratedUserName ?? widget.rating.ratedUserId),
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

            // Action Buttons
            const Text(
              'Review Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _takeAction('approved'),
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _takeAction('removed'),
                    icon: const Icon(Icons.delete, size: 20),
                    label: const Text('Remove'),
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
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _takeAction('warning'),
                icon: const Icon(Icons.warning, size: 20),
                label: const Text('Issue Warning to Rater'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _takeAction('suspend'),
                icon: const Icon(Icons.pause_circle_outline, size: 20),
                label: const Text('Suspend Rater Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
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

