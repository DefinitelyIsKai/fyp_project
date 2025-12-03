import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/report_model.dart';
import 'package:fyp_project/widgets/admin/common/detail_row.dart';

class ReportInformationCard extends StatelessWidget {
  final ReportModel report;
  final bool isLoading;
  final String Function(String) getUserDisplay;
  final String Function(String) getPostDisplay;
  final String? Function() getPostOwnerId;
  final bool Function() isPostDeleted;
  final bool Function() isPostRejected;
  final VoidCallback onViewPostDetails;
  final String Function(DateTime) formatDateTime;
  final String? Function() getDeductedCreditsFromActionTaken;

  const ReportInformationCard({
    super.key,
    required this.report,
    required this.isLoading,
    required this.getUserDisplay,
    required this.getPostDisplay,
    required this.getPostOwnerId,
    required this.isPostDeleted,
    required this.isPostRejected,
    required this.onViewPostDetails,
    required this.formatDateTime,
    required this.getDeductedCreditsFromActionTaken,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DetailRow(
                      label: 'Reason',
                      value: report.reason,
                      isHighlighted: true,
                      labelWidth: 130,
                    ),
                    if (report.description != null && report.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      DetailRow(
                        label: 'Description',
                        value: report.description!,
                        labelWidth: 130,
                      ),
                    ],
                    const SizedBox(height: 16),
                    DetailRow(
                      label: 'Reported At',
                      value: formatDateTime(report.reportedAt),
                      labelWidth: 130,
                    ),
                    const SizedBox(height: 16),
                    DetailRow(
                      label: 'Reporter',
                      value: getUserDisplay(report.reporterId),
                      labelWidth: 130,
                    ),
                    const SizedBox(height: 16),
                    if (report.reportType == ReportType.user) ...[
                      DetailRow(
                        label: 'Reported User',
                        value: getUserDisplay(
                          report.reportedEmployeeId ?? report.reportedItemId
                        ),
                        labelWidth: 130,
                      ),
                    ] else if (report.reportType == ReportType.jobPost) ...[
                      _buildReportedPostSection(),
                      if (getPostOwnerId() != null && getPostOwnerId()!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DetailRow(
                          label: 'Post Owner',
                          value: getUserDisplay(getPostOwnerId()!),
                          labelWidth: 130,
                        ),
                      ],
                    ],
                    if (report.reviewedBy != null && report.reviewedBy!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      DetailRow(
                        label: 'Reviewed By',
                        value: getUserDisplay(report.reviewedBy!),
                        labelWidth: 130,
                      ),
                    ],
                    if (report.reviewedAt != null) ...[
                      const SizedBox(height: 16),
                      DetailRow(
                        label: 'Reviewed At',
                        value: formatDateTime(report.reviewedAt!),
                        labelWidth: 130,
                      ),
                    ],
                    if (report.reviewNotes != null && report.reviewNotes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      DetailRow(
                        label: 'Review Notes',
                        value: report.reviewNotes!,
                        labelWidth: 130,
                      ),
                    ],
                    if (report.status == ReportStatus.resolved) ...[
                      Builder(
                        builder: (context) {
                          final deductedCredits = getDeductedCreditsFromActionTaken();
                          if (deductedCredits != null) {
                            return Column(
                              children: [
                                const SizedBox(height: 16),
                                DetailRow(
                                  label: 'Credit Deducted',
                                  value: '$deductedCredits credits',
                                  isHighlighted: false,
                                  labelWidth: 130,
                                ),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                    if (report.actionTaken != null && report.actionTaken!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      DetailRow(
                        label: 'Action Taken',
                        value: report.actionTaken!,
                        labelWidth: 130,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildReportedPostSection() {
    final postId = report.reportedPostId ?? report.reportedItemId;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 130,
            child: Text(
              'Reported Post',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        getPostDisplay(postId),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (isPostDeleted()) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline, 
                              size: 14, 
                              color: Colors.red[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Deleted',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isPostRejected()) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.block, 
                              size: 14, 
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Rejected',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (!isPostDeleted())
                  OutlinedButton.icon(
                    onPressed: onViewPostDetails,
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Post Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      side: BorderSide(color: Colors.blue[300]!),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, 
                          size: 16, 
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Post has been deleted',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
