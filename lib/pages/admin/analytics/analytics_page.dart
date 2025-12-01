import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/analytics_model.dart';
import 'package:fyp_project/services/admin/analytics_service.dart';
import 'package:fyp_project/services/admin/pdf_report_service.dart';
import 'package:fyp_project/utils/admin/analytics_formatter.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:fyp_project/widgets/admin/cards/analytics_quick_stat_card.dart';
import 'package:fyp_project/widgets/admin/cards/analytics_section_card.dart';
import 'package:fyp_project/widgets/admin/cards/analytics_topup_stat_card.dart';
import 'package:fyp_project/widgets/admin/common/analytics_metric_row.dart';
import 'package:fyp_project/widgets/admin/charts/analytics_trend_charts.dart';
import 'package:fyp_project/widgets/admin/dialogs/date_range_picker_dialog.dart' as custom;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final AnalyticsService _analyticsService = AnalyticsService();
  AnalyticsModel? _analytics;
  AnalyticsModel? _allTimeAnalytics;
  List<AnalyticsModel> _trendData = [];
  List<Map<String, dynamic>> _creditLogs = [];
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 0, 0, 0);
  }
  
  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  @override
  void initState() {
    super.initState();
    
    _startDate = _startOfDay(_startDate);
    _endDate = _endOfDay(_endDate);
    _loadAnalytics();
  }

  // Load analytics data for selected period and all-time
  // Also builds trend data for charts (max 30 days to keep it fast)
  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Get all-time stats from 2020 to now
      final allTimeStart = DateTime(2020, 1, 1);
      final allTimeAnalytics = await _analyticsService.getAnalyticsForRange(allTimeStart, DateTime.now());
      
      // Get stats for selected date range
      final periodAnalytics = await _analyticsService.getAnalyticsForRange(_startDate, _endDate);
      
      // Build trend data day by day (limit to 30 days max for performance)
      List<AnalyticsModel> trendData = [];
      final daysDiff = _endDate.difference(_startDate).inDays;
      final daysToLoad = daysDiff > 30 ? 30 : daysDiff;
      
      // Fetch analytics for each day in the range
      for (int i = daysToLoad; i >= 0; i--) {
        final day = _endDate.subtract(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
        final dayAnalytics = await _analyticsService.getAnalyticsForRange(dayStart, dayEnd);
        trendData.add(dayAnalytics.copyWith(date: dayStart));
      }
      
      // Get credit transaction logs for the period
      final creditLogs = await _analyticsService.getCreditLogs(_startDate, _endDate);
      
      if (mounted) {
        setState(() {
          _analytics = periodAnalytics;
          _allTimeAnalytics = allTimeAnalytics;
          _trendData = trendData;
          _creditLogs = creditLogs;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading analytics: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

  Future<void> _selectDateRange() async {
    if (!mounted) return;

    final result = await custom.DateRangePickerDialog.show(
      context,
      startDate: _startDate,
      endDate: _endDate,
    );

    if (result != null && mounted) {
      setState(() {
        _startDate = _startOfDay(result['start']!);
        _endDate = _endOfDay(result['end']!);
      });
      _loadAnalytics();
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _getDateRangeText() {
    final daysDiff = _endDate.difference(_startDate).inDays;
    if (daysDiff == 0) {
      return 'Today (${_formatDate(_startDate)})';
    }
    if (daysDiff == 29 && _endDate.day == DateTime.now().day) {
      return 'Last 30 days';
    }
    return '${_formatDate(_startDate)} - ${_formatDate(_endDate)}';
  }

  // Generate PDF report using PDF service
  Future<void> _generatePDFReport() async {
    if (_analytics == null || _allTimeAnalytics == null) return;

    try {
      final pdf = await PdfReportService.generateReport(
        analytics: _analytics!,
        allTime: _allTimeAnalytics!,
        startDate: _startDate,
        endDate: _endDate,
        creditLogs: _creditLogs,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error generating PDF: $e', isError: true);
      }
    }
  }

  // Share PDF using PDF service
  Future<void> _sharePDF() async {
    if (_analytics == null || _allTimeAnalytics == null) return;

    try {
      final pdf = await PdfReportService.generateReport(
        analytics: _analytics!,
        allTime: _allTimeAnalytics!,
        startDate: _startDate,
        endDate: _endDate,
        creditLogs: _creditLogs,
      );

      // Save PDF to temporary file and share
      final bytes = await pdf.save();
      final directory = await getTemporaryDirectory();
      final fileName = 'Platform_Analytics_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Share the file
      try {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Platform Analytics Report',
          subject: 'Platform Analytics Report - ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
        );

        // Clean up temporary file after a delay
        Future.delayed(const Duration(seconds: 5), () async {
          try {
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            // Ignore cleanup errors
          }
        });
      } catch (shareError) {
        if (shareError.toString().contains('MissingPluginException') || 
            shareError.toString().contains('missing plugin')) {
          if (mounted) {
            _showSnackBar('分享功能需要重新构建应用。请运行: flutter clean && flutter pub get && flutter run', isError: true);
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = '分享 PDF 时出错: ${e.toString()}';
        if (e.toString().contains('MissingPluginException') || 
            e.toString().contains('missing plugin')) {
          errorMessage = '分享插件未正确加载。请重新构建应用 (flutter clean && flutter pub get && flutter run)';
        }
        _showSnackBar(errorMessage, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Analytics & Reporting',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh',
          ),
          if (_analytics != null) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _sharePDF,
              tooltip: 'Share PDF',
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _generatePDFReport,
              tooltip: 'Generate PDF Report',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryDark, AppColors.primaryMedium],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track usage, engagement, and platform performance',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Date Range Selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: AppColors.primaryDark),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date Range',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getDateRangeText(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Analytics Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading analytics data...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This may take a moment to load',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : _analytics == null
                ? _buildEmptyState()
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildQuickStats(),
                  const SizedBox(height: 20),

                  _buildTrendCharts(),
                  const SizedBox(height: 20),

                  _buildAnalyticsCards(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: AnalyticsQuickStatCard(
            title: 'Active Users',
            value: _analytics!.activeUsers.toString(),
            subtitle: 'Online now',
            color: Colors.green,
            icon: Icons.people_alt,
            trend: _analytics!.activeUserGrowth,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: AnalyticsQuickStatCard(
            title: 'Job Posts',
            value: _analytics!.totalJobPosts.toString(),
            subtitle: 'This period',
            color: Colors.blue,
            icon: Icons.article,
            trend: _analytics!.jobPostGrowth,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: AnalyticsQuickStatCard(
            title: 'Flagged Content',
            value: _analytics!.totalReports.toString(),
            subtitle: 'Requires attention',
            color: Colors.red,
            icon: Icons.flag,
            trend: _analytics!.reportGrowth,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendCharts() {
    return AnalyticsTrendCharts(trendData: _trendData);
  }

  Widget _buildAnalyticsCards() {
    return Column(
      children: [
        // User Engagement
        AnalyticsSectionCard(
          title: 'User Engagement',
          icon: Icons.trending_up,
          color: Colors.green,
          children: [
            AnalyticsMetricRow(
              label: 'Engagement Rate',
              value: '${AnalyticsFormatter.capEngagementRate(_analytics!.engagementRate).toStringAsFixed(1)}%',
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.engagementGrowth),
            ),
            AnalyticsMetricRow(
              label: 'Messages Sent',
              value: _analytics!.totalMessages.toString(),
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.messageGrowth),
            ),
            AnalyticsMetricRow(
              label: 'Job Applications',
              value: _analytics!.totalApplications.toString(),
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.applicationGrowth),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Content & Moderation
        _buildContentModerationSection(),
        const SizedBox(height: 16),

        // Credit & Billing Logs
        AnalyticsSectionCard(
          title: 'Credit & Billing',
          icon: Icons.credit_card,
          color: Colors.purple,
          children: [
            AnalyticsMetricRow(
              label: 'Total Credits Used',
              value: _analytics!.totalCreditsUsed.toString(),
              trend: 0.0, 
            ),
            AnalyticsMetricRow(
              label: 'Active Subscriptions',
              value: _analytics!.activeSubscriptions.toString(),
              trend: 0.0,
            ),
            AnalyticsMetricRow(
              label: 'Revenue',
              value: 'RM ${_analytics!.revenue.toStringAsFixed(2)}',
              trend: 0.0, 
            ),
            AnalyticsMetricRow(
              label: 'Credit Purchases',
              value: _analytics!.creditPurchases.toString(),
              trend: 0.0, 
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Credit Topup Statistics
        _buildCreditTopupStats(),
      ],
    );
  }

  Widget _buildContentModerationSection() {
    if (_analytics == null || _allTimeAnalytics == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flag, size: 24, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Content & Moderation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Job Posts
            _buildComparisonRow(
              'Job Posts',
              _analytics!.totalJobPosts,
              _allTimeAnalytics!.totalJobPosts,
              [
                _buildSubMetric('Pending', _analytics!.pendingJobPosts, _allTimeAnalytics!.pendingJobPosts),
                _buildSubMetric('Active', _analytics!.approvedJobPosts, _allTimeAnalytics!.approvedJobPosts),
                _buildSubMetric('Completed', (_analytics!.totalJobPosts - _analytics!.pendingJobPosts - _analytics!.approvedJobPosts - _analytics!.rejectedJobPosts).clamp(0, _analytics!.totalJobPosts), (_allTimeAnalytics!.totalJobPosts - _allTimeAnalytics!.pendingJobPosts - _allTimeAnalytics!.approvedJobPosts - _allTimeAnalytics!.rejectedJobPosts).clamp(0, _allTimeAnalytics!.totalJobPosts)),
                _buildSubMetric('Rejected', _analytics!.rejectedJobPosts, _allTimeAnalytics!.rejectedJobPosts),
              ],
            ),
            const SizedBox(height: 20),
            
            // Reports
            _buildComparisonRow(
              'Reports',
              _analytics!.totalReports,
              _allTimeAnalytics!.totalReports,
              [
                _buildSubMetric('Pending', _analytics!.pendingReports, _allTimeAnalytics!.pendingReports),
                _buildSubMetric('Resolved', _analytics!.resolvedReports, _allTimeAnalytics!.resolvedReports),
                _buildSubMetric('Dismissed', _analytics!.dismissedReports, _allTimeAnalytics!.dismissedReports),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String label, int periodValue, int allTimeValue, List<Widget>? subMetrics) {
    final percentage = allTimeValue > 0 ? (periodValue / allTimeValue * 100).clamp(0.0, 100.0) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      periodValue.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Selected Period',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      allTimeValue.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      'All Time',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
        const SizedBox(height: 4),
        Text(
          '${percentage.toStringAsFixed(1)}% of all time',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        if (subMetrics != null && subMetrics.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: subMetrics,
          ),
        ],
      ],
    );
  }

  Widget _buildSubMetric(String label, int periodValue, int allTimeValue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                periodValue.toString(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' / ${allTimeValue}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreditTopupStats() {
    if (_creditLogs.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  'No credit topup transactions found',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculate statistics
    final processedLogs = _creditLogs.where((log) => log['status'] == 'processed').toList();
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.trending_up, size: 24, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Credit Topup Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AnalyticsTopupStatCard(
                    label: 'Total Topup Amount',
                    value: '\$${totalTopupAmount.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnalyticsTopupStatCard(
                    label: 'Total Credits',
                    value: totalTopupCredits.toString(),
                    icon: Icons.stars,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AnalyticsTopupStatCard(
                    label: 'Average Amount',
                    value: '\$${avgTopupAmount.toStringAsFixed(2)}',
                    icon: Icons.calculate,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnalyticsTopupStatCard(
                    label: 'Average Credits',
                    value: avgTopupCredits.toStringAsFixed(0),
                    icon: Icons.analytics,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AnalyticsTopupStatCard(
                    label: 'Max Topup',
                    value: '\$${maxTopupAmount.toStringAsFixed(2)}',
                    icon: Icons.arrow_upward,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnalyticsTopupStatCard(
                    label: 'Min Topup',
                    value: '\$${minTopupAmount.toStringAsFixed(2)}',
                    icon: Icons.arrow_downward,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnalyticsTopupStatCard(
              label: 'Total Transactions',
              value: '${processedLogs.length} processed',
              icon: Icons.receipt_long,
              color: Colors.indigo,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Analytics Data',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analytics data will appear here once available',
            style: TextStyle(
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}