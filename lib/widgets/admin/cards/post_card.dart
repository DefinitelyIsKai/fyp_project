import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';

/// A reusable post card widget for displaying job posts in moderation pages
class PostCard extends StatelessWidget {
  final JobPostModel post;
  final void Function(JobPostModel)? onApprove;
  final void Function(JobPostModel)? onReject;
  final void Function(JobPostModel)? onComplete;
  final void Function(JobPostModel)? onReopen;
  final void Function(JobPostModel) onView;
  final String Function(String?) getUserName;
  final bool isProcessing;

  const PostCard({
    super.key,
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
                label: Text(isProcessing ? 'Processing...' : 'Disable'),
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
                Row(
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
                        getUserName(post.ownerId ?? post.submitterName),
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

