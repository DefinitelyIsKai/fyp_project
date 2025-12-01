import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/report_model.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class ReportActionButtons extends StatelessWidget {
  final ReportModel report;
  final bool isProcessing;
  final bool isLoadingInfo;
  final bool Function() isPostDeleted;
  final bool Function() isPostRejected;
  final String Function() getPostActionButtonText;
  final bool Function(String) postExists;
  final VoidCallback onDismissReport;
  final VoidCallback onHandleUserReport;
  final VoidCallback onRejectPost;

  const ReportActionButtons({
    super.key,
    required this.report,
    required this.isProcessing,
    required this.isLoadingInfo,
    required this.isPostDeleted,
    required this.isPostRejected,
    required this.getPostActionButtonText,
    required this.postExists,
    required this.onDismissReport,
    required this.onHandleUserReport,
    required this.onRejectPost,
  });

  @override
  Widget build(BuildContext context) {
    if (report.status == ReportStatus.resolved) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (report.reportType == ReportType.user) ...[
            _buildUserReportActions(),
          ] else if (report.reportType == ReportType.jobPost) ...[
            _buildPostReportActions(),
          ] else ...[
            _buildOtherReportActions(),
          ],
          if (isProcessing) ...[
            const SizedBox(height: 20),
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUserReportActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (isProcessing || isLoadingInfo) ? null : onHandleUserReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Handle User Report',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: (isProcessing || isLoadingInfo) ? null : onDismissReport,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: Colors.grey[400]!, width: 1.5),
            ),
            child: const Text(
              'Dismiss Report',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostReportActions() {
    final postId = report.reportedPostId ?? report.reportedItemId;
    
    return Column(
      children: [
        if (isPostDeleted()) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post Deleted - Report Resolved',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The reported post has been deleted. The report has been automatically resolved.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else if (isPostRejected()) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The reported post has already been rejected.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          if (!isLoadingInfo && postExists(postId)) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (isProcessing || isLoadingInfo) ? null : onRejectPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  getPostActionButtonText(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ] else if (isLoadingInfo) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Checking post status...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: (isProcessing || isLoadingInfo) ? null : onDismissReport,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: Colors.grey[400]!, width: 1.5),
            ),
            child: const Text(
              'Dismiss Report',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherReportActions() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: (isProcessing || isLoadingInfo) ? null : onDismissReport,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[700],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: Colors.grey[400]!, width: 1.5),
        ),
        child: const Text(
          'Dismiss Report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

