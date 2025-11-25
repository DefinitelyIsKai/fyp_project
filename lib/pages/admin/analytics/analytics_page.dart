import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:fyp_project/models/admin/analytics_model.dart';
import 'package:fyp_project/services/admin/analytics_service.dart';
import 'package:fyp_project/pages/admin/analytics/analytics_detail_page.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final AnalyticsService _analyticsService = AnalyticsService();
  AnalyticsModel? _analytics;
  AnalyticsModel? _allTimeAnalytics; // For comparison
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
    // Normalize initial dates
    _startDate = _startOfDay(_startDate);
    _endDate = _endOfDay(_endDate);
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final allTimeStart = DateTime(2020, 1, 1);
      final allTimeAnalytics = await _analyticsService.getAnalyticsForRange(allTimeStart, DateTime.now());
      
      final periodAnalytics = await _analyticsService.getAnalyticsForRange(_startDate, _endDate);
      
      List<AnalyticsModel> trendData = [];
      final daysDiff = _endDate.difference(_startDate).inDays;
      final daysToLoad = daysDiff > 30 ? 30 : daysDiff;
      
      for (int i = daysToLoad; i >= 0; i--) {
        final day = _endDate.subtract(Duration(days: i));
        final dayStart = DateTime(day.year, day.month, day.day);
        final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
        final dayAnalytics = await _analyticsService.getAnalyticsForRange(dayStart, dayEnd);
        trendData.add(dayAnalytics.copyWith(date: dayStart));
      }
      
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

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (dialogContext) => _DateRangePickerDialog(
        startDate: _startDate,
        endDate: _endDate,
      ),
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

  double _capEngagementRate(double rate) {
    return rate > 100.0 ? 100.0 : rate;
  }

  double _capGrowthRate(double rate) {
    // Cap growth rate at 100% to avoid misleading high percentages
    if (rate > 100.0) return 100.0;
    // Hide negative growth rates (show as 0)
    if (rate < 0) return 0.0;
    return rate;
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

  Future<void> _generatePDFReport() async {
    if (_analytics == null) return;

    try {
      final pdf = pw.Document();
      final analytics = _analytics!;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Platform Analytics Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      DateFormat('dd MMM yyyy').format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Date Range
              pw.Text(
                'Period: ${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),

              // Executive Summary
              pw.Text(
                'Executive Summary',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  _buildPDFTableRow('Total Users', analytics.totalUsers.toString()),
                  _buildPDFTableRow('Active Users', '${analytics.activeUsers} (${analytics.activeUserPercentage.toStringAsFixed(1)}%)'),
                  _buildPDFTableRow('New Registrations', analytics.newRegistrations.toString()),
                  _buildPDFTableRow('Job Posts Created', analytics.totalJobPosts.toString()),
                  _buildPDFTableRow('Total Applications', analytics.totalApplications.toString()),
                  _buildPDFTableRow('Flagged Content', analytics.totalReports.toString()),
                  _buildPDFTableRow('Engagement Rate', '${analytics.engagementRate.toStringAsFixed(1)}%'),
                ],
              ),
              pw.SizedBox(height: 20),

              // User Activity Trends
              pw.Text(
                'User Activity Trends',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  _buildPDFTableRow('User Growth Rate', '${analytics.userGrowthRate.toStringAsFixed(1)}%'),
                  _buildPDFTableRow('Active User Growth', '${analytics.activeUserGrowth.toStringAsFixed(1)}%'),
                  _buildPDFTableRow('Registration Growth', '${analytics.registrationGrowth.toStringAsFixed(1)}%'),
                  _buildPDFTableRow('Engagement Growth', '${analytics.engagementGrowth.toStringAsFixed(1)}%'),
                ],
              ),
              pw.SizedBox(height: 20),

              // Content & Moderation
              pw.Text(
                'Content & Moderation Statistics',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  _buildPDFTableRow('Total Job Posts', analytics.totalJobPosts.toString()),
                  _buildPDFTableRow('Pending Posts', analytics.pendingJobPosts.toString()),
                  _buildPDFTableRow('Approved Posts', analytics.approvedJobPosts.toString()),
                  _buildPDFTableRow('Rejected Posts', analytics.rejectedJobPosts.toString()),
                  _buildPDFTableRow('Total Reports', analytics.totalReports.toString()),
                  _buildPDFTableRow('Pending Reports', analytics.pendingReports.toString()),
                  _buildPDFTableRow('Resolved Reports', analytics.resolvedReports.toString()),
                ],
              ),
              pw.SizedBox(height: 20),

              // Application Trends
              pw.Text(
                'Application Trends',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  _buildPDFTableRow('Total Applications', analytics.totalApplications.toString()),
                  _buildPDFTableRow('Application Growth', '${analytics.applicationGrowth.toStringAsFixed(1)}%'),
                  _buildPDFTableRow('Avg Applications per Job', analytics.avgApplicationsPerJob.toStringAsFixed(1)),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error generating PDF: $e', isError: true);
      }
    }
  }

  pw.TableRow _buildPDFTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 12)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    );
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
          if (_analytics != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _generatePDFReport,
              tooltip: 'Generate PDF Report',
            ),
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
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnalyticsDetailPage(analytics: _analytics!),
                            ),
                          ),
                          icon: const Icon(Icons.analytics),
                          label: const Text(
                            'Detailed Report',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _generatePDFReport,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text(
                            'Export PDF',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
          child: _QuickStatCard(
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
          child: _QuickStatCard(
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
          child: _QuickStatCard(
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
    if (_trendData.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        // User Growth Trend
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Activity Trends',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(
                      labelRotation: -45,
                      majorGridLines: const MajorGridLines(width: 0),
                    ),
                    primaryYAxis: NumericAxis(),
                    legend: Legend(
                      isVisible: true,
                      position: LegendPosition.bottom,
                    ),
                    tooltipBehavior: TooltipBehavior(enable: true),
                    series: <CartesianSeries<AnalyticsModel, String>>[
                      LineSeries<AnalyticsModel, String>(
                        name: 'Total Users',
                        dataSource: _trendData,
                        xValueMapper: (model, _) => DateFormat('MMM dd').format(model.date),
                        yValueMapper: (model, _) => model.totalUsers,
                        color: Colors.blue,
                        width: 3,
                        markerSettings: const MarkerSettings(isVisible: true),
                      ),
                      LineSeries<AnalyticsModel, String>(
                        name: 'Active Users',
                        dataSource: _trendData,
                        xValueMapper: (model, _) => DateFormat('MMM dd').format(model.date),
                        yValueMapper: (model, _) => model.activeUsers,
                        color: Colors.green,
                        width: 3,
                        markerSettings: const MarkerSettings(isVisible: true),
                      ),
                      LineSeries<AnalyticsModel, String>(
                        name: 'New Registrations',
                        dataSource: _trendData,
                        xValueMapper: (model, _) => DateFormat('MMM dd').format(model.date),
                        yValueMapper: (model, _) => model.newRegistrations,
                        color: Colors.orange,
                        width: 3,
                        markerSettings: const MarkerSettings(isVisible: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Job Posts Trend (Line Chart)
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Job Posts Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(
                      labelRotation: _trendData.length > 7 ? -45 : 0,
                      majorGridLines: const MajorGridLines(width: 0),
                    ),
                    primaryYAxis: NumericAxis(),
                    tooltipBehavior: TooltipBehavior(enable: true),
                    series: <CartesianSeries<AnalyticsModel, String>>[
                      LineSeries<AnalyticsModel, String>(
                        name: 'Job Posts',
                        dataSource: _trendData,
                        xValueMapper: (model, _) => DateFormat('MMM dd').format(model.date),
                        yValueMapper: (model, _) => model.totalJobPosts,
                        color: Colors.blue,
                        width: 3,
                        markerSettings: const MarkerSettings(
                          isVisible: true,
                          height: 6,
                          width: 6,
                        ),
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                          labelPosition: ChartDataLabelPosition.outside,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Flagged Content Trend
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Flagged Content & Reports Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: SfCartesianChart(
                    primaryXAxis: CategoryAxis(
                      labelRotation: -45,
                      majorGridLines: const MajorGridLines(width: 0),
                    ),
                    primaryYAxis: NumericAxis(),
                    legend: Legend(
                      isVisible: true,
                      position: LegendPosition.bottom,
                    ),
                    tooltipBehavior: TooltipBehavior(enable: true),
                    series: <CartesianSeries<AnalyticsModel, String>>[
                      LineSeries<AnalyticsModel, String>(
                        name: 'Total Reports',
                        dataSource: _trendData,
                        xValueMapper: (model, _) => DateFormat('MMM dd').format(model.date),
                        yValueMapper: (model, _) => model.totalReports,
                        color: Colors.red,
                        width: 3,
                        markerSettings: const MarkerSettings(isVisible: true),
                      ),
                      LineSeries<AnalyticsModel, String>(
                        name: 'Pending Reports',
                        dataSource: _trendData,
                        xValueMapper: (model, _) => DateFormat('MMM dd').format(model.date),
                        yValueMapper: (model, _) => model.pendingReports,
                        color: Colors.orange,
                        width: 3,
                        markerSettings: const MarkerSettings(isVisible: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCards() {
    return Column(
      children: [
        // User Engagement
        _AnalyticsSectionCard(
          title: 'User Engagement',
          icon: Icons.trending_up,
          color: Colors.green,
          children: [
            _MetricRow(
              label: 'Engagement Rate',
              value: '${_capEngagementRate(_analytics!.engagementRate).toStringAsFixed(1)}%',
              trend: _capGrowthRate(_analytics!.engagementGrowth),
            ),
            _MetricRow(
              label: 'Messages Sent',
              value: _analytics!.totalMessages.toString(),
              trend: _capGrowthRate(_analytics!.messageGrowth),
            ),
            _MetricRow(
              label: 'Job Applications',
              value: _analytics!.totalApplications.toString(),
              trend: _capGrowthRate(_analytics!.applicationGrowth),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Content & Moderation
        _buildContentModerationSection(),
        const SizedBox(height: 16),

        // Credit & Billing Logs
        _AnalyticsSectionCard(
          title: 'Credit & Billing',
          icon: Icons.credit_card,
          color: Colors.purple,
          children: [
            _MetricRow(
              label: 'Total Credits Used',
              value: _analytics!.totalCreditsUsed.toString(),
              trend: _analytics!.creditUsageGrowth,
            ),
            _MetricRow(
              label: 'Active Subscriptions',
              value: _analytics!.activeSubscriptions.toString(),
              trend: _analytics!.subscriptionGrowth,
            ),
            _MetricRow(
              label: 'Revenue',
              value: '\$${_analytics!.revenue.toStringAsFixed(2)}',
              trend: _analytics!.revenueGrowth,
            ),
            _MetricRow(
              label: 'Credit Purchases',
              value: _analytics!.creditPurchases.toString(),
              trend: _analytics!.purchaseGrowth,
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
                  child: _TopupStatCard(
                    label: 'Total Topup Amount',
                    value: '\$${totalTopupAmount.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TopupStatCard(
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
                  child: _TopupStatCard(
                    label: 'Average Amount',
                    value: '\$${avgTopupAmount.toStringAsFixed(2)}',
                    icon: Icons.calculate,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TopupStatCard(
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
                  child: _TopupStatCard(
                    label: 'Max Topup',
                    value: '\$${maxTopupAmount.toStringAsFixed(2)}',
                    icon: Icons.arrow_upward,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TopupStatCard(
                    label: 'Min Topup',
                    value: '\$${minTopupAmount.toStringAsFixed(2)}',
                    icon: Icons.arrow_downward,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TopupStatCard(
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

class _QuickStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final double trend;

  const _QuickStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.trend = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (trend != 0 && trend != -999.0)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: trend > 0 ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              trend > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 10,
                              color: trend > 0 ? Colors.green[700] : Colors.red[700],
                            ),
                            const SizedBox(width: 1),
                            Text(
                              '${(trend.abs().clamp(0.0, 100.0)).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: trend > 0 ? Colors.green[700] : Colors.red[700],
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
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _AnalyticsSectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final double trend;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                if (trend != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: trend > 0 ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: trend > 0 ? Colors.green[100]! : Colors.red[100]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          trend > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 12,
                          color: trend > 0 ? Colors.green[700] : Colors.red[700],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${(trend.abs().clamp(0.0, 100.0)).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: trend > 0 ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DateRangePickerDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const _DateRangePickerDialog({
    required this.startDate,
    required this.endDate,
  });

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  late DateTime _tempStartDate;
  late DateTime _tempEndDate;

  @override
  void initState() {
    super.initState();
    _tempStartDate = DateTime(widget.startDate.year, widget.startDate.month, widget.startDate.day);
    _tempEndDate = DateTime(widget.endDate.year, widget.endDate.month, widget.endDate.day);
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempStartDate,
      firstDate: DateTime(2020),
      lastDate: _tempEndDate,
    );
    if (picked != null) {
      setState(() {
        _tempStartDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempEndDate,
      firstDate: _tempStartDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _tempEndDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Date Range'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Start Date
            const Text(
              'Start Date',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectStartDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(_tempStartDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Icon(Icons.calendar_today, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // End Date
            const Text(
              'End Date',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectEndDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(_tempEndDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Icon(Icons.calendar_today, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quick Presets
            const Text(
              'Quick Presets',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickDateButton(
                  label: 'Today',
                  onTap: () {
                    final now = DateTime.now();
                    setState(() {
                      _tempStartDate = DateTime(now.year, now.month, now.day);
                      _tempEndDate = DateTime(now.year, now.month, now.day);
                    });
                  },
                ),
                _QuickDateButton(
                  label: 'Last 7 Days',
                  onTap: () {
                    final now = DateTime.now();
                    final startDate = now.subtract(const Duration(days: 7));
                    setState(() {
                      _tempStartDate = DateTime(startDate.year, startDate.month, startDate.day);
                      _tempEndDate = DateTime(now.year, now.month, now.day);
                    });
                  },
                ),
                _QuickDateButton(
                  label: 'Last 30 Days',
                  onTap: () {
                    final now = DateTime.now();
                    final startDate = now.subtract(const Duration(days: 30));
                    setState(() {
                      _tempStartDate = DateTime(startDate.year, startDate.month, startDate.day);
                      _tempEndDate = DateTime(now.year, now.month, now.day);
                    });
                  },
                ),
                _QuickDateButton(
                  label: 'This Month',
                  onTap: () {
                    final now = DateTime.now();
                    setState(() {
                      _tempStartDate = DateTime(now.year, now.month, 1);
                      _tempEndDate = DateTime(now.year, now.month, now.day);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_tempStartDate.isAfter(_tempEndDate)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Start date must be before end date'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            Navigator.pop(context, {
              'start': _tempStartDate,
              'end': _tempEndDate,
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _QuickDateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickDateButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TopupStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool fullWidth;

  const _TopupStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}