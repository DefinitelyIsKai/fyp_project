import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/report_model.dart';

class ReportStatusBanner extends StatelessWidget {
  final ReportModel report;

  const ReportStatusBanner({
    super.key,
    required this.report,
  });

  Color _getStatusColor() {
    switch (report.status) {
      case ReportStatus.pending:
        return Colors.red;
      case ReportStatus.underReview:
        return Colors.orange;
      case ReportStatus.resolved:
        return Colors.green;
      case ReportStatus.dismissed:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: statusColor.withOpacity(0.3), width: 2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              report.status.toString().split('.').last.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              report.reportType == ReportType.jobPost 
                  ? 'Post Report' 
                  : report.reportType == ReportType.user 
                      ? 'Employee Report' 
                      : 'Report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
