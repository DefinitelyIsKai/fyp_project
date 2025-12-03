import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:fyp_project/models/admin/analytics_model.dart';
import 'package:fyp_project/utils/admin/analytics_formatter.dart';

class PdfReportService {
  
  static Map<String, dynamic> _calculateCreditStats(List<Map<String, dynamic>> creditLogs) {
    final processedLogs = creditLogs.where((log) => log['status'] == 'processed').toList();
    final totalTopupAmount = processedLogs.fold<double>(0.0, (sum, log) => sum + (log['amount'] as double));
    final totalTopupCredits = processedLogs.fold<int>(0, (sum, log) => sum + (log['credits'] as int));
    final avgTopupAmount = processedLogs.isNotEmpty ? totalTopupAmount / processedLogs.length : 0.0;
    final avgTopupCredits = processedLogs.isNotEmpty ? totalTopupCredits / processedLogs.length : 0.0;
    final maxTopupAmount = processedLogs.isNotEmpty 
        ? processedLogs.map((log) => log['amount'] as double).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final minTopupAmount = processedLogs.isNotEmpty 
        ? processedLogs.map((log) => log['amount'] as double).reduce((a, b) => a < b ? a : b)
        : 0.0;
    
    return {
      'processedLogs': processedLogs,
      'totalTopupAmount': totalTopupAmount,
      'totalTopupCredits': totalTopupCredits,
      'avgTopupAmount': avgTopupAmount,
      'avgTopupCredits': avgTopupCredits,
      'maxTopupAmount': maxTopupAmount,
      'minTopupAmount': minTopupAmount,
    };
  }

  static List<pw.Widget> _buildPdfPages({
    required pw.Context context,
    required AnalyticsModel analytics,
    required AnalyticsModel allTime,
    required DateTime startDate,
    required DateTime endDate,
    required Map<String, dynamic> creditStats,
  }) {
    final processedLogs = creditStats['processedLogs'] as List;
    final formatDate = (DateTime date) => DateFormat('dd/MM/yyyy').format(date);
    
    return [
      
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Platform Analytics Report',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
          pw.Text(
            DateFormat('dd MMM yyyy HH:mm').format(DateTime.now()),
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
      pw.SizedBox(height: 15),

      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          children: [
            pw.Text(
              'Period: ',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              '${formatDate(startDate)} - ${formatDate(endDate)}',
              style: pw.TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 20),

      _buildSectionTitle('Overview Statistics'),
      _buildComparisonTable(
        context: context,
        headers: ['Metric', 'All Time', 'Selected Period'],
        data: [
          ['Total Users', allTime.totalUsers.toString(), analytics.totalUsers.toString()],
          ['Active Users', allTime.activeUsers.toString(), analytics.activeUsers.toString()],
          ['Inactive Users', allTime.inactiveUsers.toString(), analytics.inactiveUsers.toString()],
          ['New Registrations', allTime.newRegistrations.toString(), analytics.newRegistrations.toString()],
          ['Total Job Posts', allTime.totalJobPosts.toString(), analytics.totalJobPosts.toString()],
          ['Total Applications', allTime.totalApplications.toString(), analytics.totalApplications.toString()],
          ['Total Reports', allTime.totalReports.toString(), analytics.totalReports.toString()],
          ['Engagement Rate', '${AnalyticsFormatter.capEngagementRate(allTime.engagementRate).toStringAsFixed(1)}%', '${AnalyticsFormatter.capEngagementRate(analytics.engagementRate).toStringAsFixed(1)}%'],
        ],
      ),
      pw.SizedBox(height: 20),

      _buildSectionTitle('User Engagement'),
      _buildComparisonTable(
        context: context,
        headers: ['Metric', 'All Time', 'Selected Period'],
        data: [
          ['Engagement Rate', '${AnalyticsFormatter.capEngagementRate(allTime.engagementRate).toStringAsFixed(1)}%', '${AnalyticsFormatter.capEngagementRate(analytics.engagementRate).toStringAsFixed(1)}%'],
          ['Job Applications', allTime.totalApplications.toString(), analytics.totalApplications.toString()],
          ['Messages Sent', allTime.totalMessages.toString(), analytics.totalMessages.toString()],
        ],
      ),
      pw.SizedBox(height: 20),

      _buildSectionTitle('Content & Moderation Statistics'),
      _buildComparisonTable(
        context: context,
        headers: ['Metric', 'All Time', 'Selected Period'],
        data: [
          ['Total Job Posts', allTime.totalJobPosts.toString(), analytics.totalJobPosts.toString()],
          ['Pending Posts', allTime.pendingJobPosts.toString(), analytics.pendingJobPosts.toString()],
          ['Approved Posts', allTime.approvedJobPosts.toString(), analytics.approvedJobPosts.toString()],
          ['Rejected Posts', allTime.rejectedJobPosts.toString(), analytics.rejectedJobPosts.toString()],
          ['Total Reports', allTime.totalReports.toString(), analytics.totalReports.toString()],
          ['Pending Reports', allTime.pendingReports.toString(), analytics.pendingReports.toString()],
          ['Resolved Reports', allTime.resolvedReports.toString(), analytics.resolvedReports.toString()],
          ['Dismissed Reports', allTime.dismissedReports.toString(), analytics.dismissedReports.toString()],
        ],
      ),
      pw.SizedBox(height: 20),

      _buildSectionTitle('Credit & Billing'),
      _buildComparisonTable(
        context: context,
        headers: ['Metric', 'All Time', 'Selected Period'],
        data: [
          ['Total Credits Used', allTime.totalCreditsUsed.toString(), analytics.totalCreditsUsed.toString()],
          ['Active Subscriptions', allTime.activeSubscriptions.toString(), analytics.activeSubscriptions.toString()],
          ['Revenue', 'RM ${allTime.revenue.toStringAsFixed(2)}', 'RM ${analytics.revenue.toStringAsFixed(2)}'],
          ['Credit Purchases', allTime.creditPurchases.toString(), analytics.creditPurchases.toString()],
        ],
      ),
      pw.SizedBox(height: 20),

      if (processedLogs.isNotEmpty) ...[
        _buildSectionTitle('Credit Topup Statistics'),
        _buildComparisonTable(
          context: context,
          headers: ['Metric', 'Value'],
          data: [
            ['Total Topup Amount', 'RM ${creditStats['totalTopupAmount'].toStringAsFixed(2)}'],
            ['Total Credits', creditStats['totalTopupCredits'].toString()],
            ['Average Amount', 'RM ${creditStats['avgTopupAmount'].toStringAsFixed(2)}'],
            ['Average Credits', creditStats['avgTopupCredits'].toStringAsFixed(0)],
            ['Max Topup', 'RM ${creditStats['maxTopupAmount'].toStringAsFixed(2)}'],
            ['Min Topup', 'RM ${creditStats['minTopupAmount'].toStringAsFixed(2)}'],
            ['Total Transactions', '${processedLogs.length} processed'],
          ],
        ),
        pw.SizedBox(height: 20),
      ],

      _buildSectionTitle('Growth Rates'),
      _buildComparisonTable(
        context: context,
        headers: ['Metric', 'Growth Rate'],
        data: [
          ['User Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.userGrowthRate, 'userGrowth', analytics)],
          ['Active User Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.activeUserGrowth, 'activeUserGrowth', analytics)],
          ['Registration Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.registrationGrowth, 'registrationGrowth', analytics)],
          ['Engagement Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.engagementGrowth, 'engagementGrowth', analytics)],
          ['Message Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.messageGrowth, 'messageGrowth', analytics)],
          ['Application Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.applicationGrowth, 'applicationGrowth', analytics)],
          ['Report Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.reportGrowth, 'reportGrowth', analytics)],
          ['Job Post Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.jobPostGrowth, 'jobPostGrowth', analytics)],
        ],
      ),
    ];
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  static pw.Widget _buildComparisonTable({
    required pw.Context context,
    required List<String> headers,
    required List<List<String>> data,
  }) {
    return pw.TableHelper.fromTextArray(
      context: context,
      headers: headers,
      data: data,
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 0.5,
      ),
      cellAlignment: pw.Alignment.centerLeft,
      headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
      headerStyle: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: pw.TextStyle(fontSize: 9),
      rowDecoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
    );
  }

  static Future<pw.Document> generateReport({
    required AnalyticsModel analytics,
    required AnalyticsModel allTime,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> creditLogs,
  }) async {
    final pdf = pw.Document();
    final creditStats = _calculateCreditStats(creditLogs);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return _buildPdfPages(
            context: context,
            analytics: analytics,
            allTime: allTime,
            startDate: startDate,
            endDate: endDate,
            creditStats: creditStats,
          );
        },
      ),
    );
    
    return pdf;
  }
}
