import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:fyp_project/services/post_analytics_service.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ContentAnalyticsPage extends StatefulWidget {
  const ContentAnalyticsPage({super.key});

  @override
  State<ContentAnalyticsPage> createState() => _ContentAnalyticsPageState();
}

class _ContentAnalyticsPageState extends State<ContentAnalyticsPage> {
  final PostAnalyticsService _analyticsService = PostAnalyticsService();
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final analytics = await _analyticsService.getPostAnalytics(
        startDate: _startDate,
        endDate: _endDate,
      );
      setState(() => _analytics = analytics);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading analytics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateTimeRange() async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => _DateTimeRangePickerDialog(
        startDate: _startDate,
        endDate: _endDate,
      ),
    );

    if (result != null) {
      setState(() {
        _startDate = result['start']!;
        _endDate = result['end']!;
      });
      _loadAnalytics();
    }
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _getDateRangeText() {
    final daysDiff = _endDate.difference(_startDate).inDays;
    if (daysDiff == 0) {
      return 'Today (${_formatDateTime(_startDate)})';
    }
    if (daysDiff == 29 && _endDate.day == DateTime.now().day) {
      return 'Last 30 days';
    }
    return '${_formatDateTime(_startDate)} - ${_formatDateTime(_endDate)}';
  }

  Future<void> _downloadPDF() async {
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
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Content Analytics Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.Text(
                      DateFormat('dd MMM yyyy HH:mm').format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Date Range
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'Period: ',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '${_formatDateTime(_startDate)} - ${_formatDateTime(_endDate)}',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Overview Statistics
              pw.Text(
                'Overview Statistics',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                },
                children: [
                  _buildPDFTableRow('Total Posts', analytics['totalPosts'].toString(), 'All Time'),
                  _buildPDFTableRow('Posts in Period', analytics['postsInPeriod'].toString(), 'Selected Period'),
                  _buildPDFTableRow('Pending', analytics['pending'].toString(), analytics['pendingInPeriod'].toString()),
                  _buildPDFTableRow('Active', analytics['active'].toString(), analytics['activeInPeriod'].toString()),
                  _buildPDFTableRow('Completed', analytics['completed'].toString(), analytics['completedInPeriod'].toString()),
                  _buildPDFTableRow('Rejected', analytics['rejected'].toString(), analytics['rejectedInPeriod'].toString()),
                  _buildPDFTableRow('Approval Rate', '${(analytics['approvalRate'] as double).toStringAsFixed(1)}%', ''),
                  _buildPDFTableRow('Rejection Rate', '${(analytics['rejectionRate'] as double).toStringAsFixed(1)}%', ''),
                ],
              ),
              pw.SizedBox(height: 20),

              // Budget Analysis
              if (analytics['avgBudgetMin'] != null || analytics['avgBudgetMax'] != null) ...[
                pw.Text(
                  'Budget Analysis',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    if (analytics['avgBudgetMin'] != null)
                      _buildPDFTableRow2Col('Average Budget Min', 'RM ${(analytics['avgBudgetMin'] as double).toStringAsFixed(2)}'),
                    if (analytics['avgBudgetMax'] != null)
                      _buildPDFTableRow2Col('Average Budget Max', 'RM ${(analytics['avgBudgetMax'] as double).toStringAsFixed(2)}'),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],

              // Category Breakdown
              if (analytics['categoryBreakdown'] != null && (analytics['categoryBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Category Breakdown (Top 10)',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: () {
                    final entries = (analytics['categoryBreakdown'] as Map<String, dynamic>).entries.toList();
                    entries.sort((a, b) => b.value.compareTo(a.value));
                    return entries.take(10).map((entry) => _buildPDFTableRow2Col(entry.key, entry.value.toString())).toList();
                  }(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Industry Breakdown
              if (analytics['industryBreakdown'] != null && (analytics['industryBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Industry Breakdown (Top 10)',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: () {
                    final entries = (analytics['industryBreakdown'] as Map<String, dynamic>).entries.toList();
                    entries.sort((a, b) => b.value.compareTo(a.value));
                    return entries.take(10).map((entry) => _buildPDFTableRow2Col(entry.key, entry.value.toString())).toList();
                  }(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Job Type Breakdown
              if (analytics['jobTypeBreakdown'] != null && (analytics['jobTypeBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Job Type Breakdown',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: () {
                    final entries = (analytics['jobTypeBreakdown'] as Map<String, dynamic>).entries.toList();
                    entries.sort((a, b) => b.value.compareTo(a.value));
                    return entries.map((entry) => _buildPDFTableRow2Col(entry.key, entry.value.toString())).toList();
                  }(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Location Breakdown
              if (analytics['locationBreakdown'] != null && (analytics['locationBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Location Breakdown (Top 10)',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: () {
                    final entries = (analytics['locationBreakdown'] as Map<String, dynamic>).entries.toList();
                    entries.sort((a, b) => b.value.compareTo(a.value));
                    return entries.take(10).map((entry) => _buildPDFTableRow2Col(entry.key, entry.value.toString())).toList();
                  }(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Daily Breakdown
              if (analytics['dailyBreakdown'] != null && (analytics['dailyBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Daily Post Activity',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1),
                  },
                  children: () {
                    final entries = (analytics['dailyBreakdown'] as Map<String, dynamic>).entries.toList();
                    entries.sort((a, b) => a.key.compareTo(b.key));
                    return entries.map((entry) {
                      final date = DateTime.parse(entry.key);
                      return _buildPDFTableRow2Col(DateFormat('dd MMM yyyy').format(date), entry.value.toString());
                    }).toList();
                  }(),
                ),
              ],
            ];
          },
        ),
      );

      // Show PDF preview and allow download
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.TableRow _buildPDFTableRow(String label, String value, String period) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            maxLines: 2,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            period,
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  pw.TableRow _buildPDFTableRow2Col(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            maxLines: 2,
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Analytics'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh',
          ),
          if (_analytics != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _downloadPDF,
              tooltip: 'Download PDF',
            ),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Content Analytics',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Comprehensive post performance and engagement statistics',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Date Time Range Selector
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
                    onTap: _selectDateTimeRange,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date & Time Range',
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

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _analytics == null
                    ? const Center(child: Text('No data available'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quick Stats
                            _buildQuickStats(),
                            const SizedBox(height: 20),

                            // Period Comparison
                            _buildPeriodComparison(),
                            const SizedBox(height: 20),

                            // Daily Trend Chart
                            _buildDailyTrendChart(),
                            const SizedBox(height: 20),

                            // Status Distribution Chart
                            _buildStatusChart(),
                            const SizedBox(height: 20),

                            // Category Breakdown
                            _buildCategoryChart(),
                            const SizedBox(height: 20),

                            // Industry Breakdown
                            _buildIndustryChart(),
                            const SizedBox(height: 20),

                            // Job Type Breakdown
                            _buildJobTypeChart(),
                            const SizedBox(height: 20),

                            // Location Breakdown
                            _buildLocationChart(),
                            const SizedBox(height: 20),

                            // Budget Analysis
                            _buildBudgetAnalysis(),
                            const SizedBox(height: 20),

                            // Detailed Statistics
                            _buildDetailedStats(),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final analytics = _analytics!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            child: _StatCard(
              title: 'Total Posts',
              value: analytics['totalPosts'].toString(),
              subtitle: 'All Time',
              icon: Icons.article,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            child: _StatCard(
              title: 'In Period',
              value: analytics['postsInPeriod'].toString(),
              subtitle: 'Selected Range',
              icon: Icons.timeline,
              color: Colors.purple,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            child: _StatCard(
              title: 'Active',
              value: analytics['active'].toString(),
              subtitle: '${analytics['activeInPeriod']} in period',
              icon: Icons.check_circle,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            child: _StatCard(
              title: 'Pending',
              value: analytics['pending'].toString(),
              subtitle: '${analytics['pendingInPeriod']} in period',
              icon: Icons.pending,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodComparison() {
    final analytics = _analytics!;
    final totalPosts = analytics['totalPosts'] as int;
    final postsInPeriod = analytics['postsInPeriod'] as int;
    final periodPercentage = totalPosts > 0 ? (postsInPeriod / totalPosts * 100) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Period Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ComparisonItem(
                    label: 'Posts in Selected Period',
                    value: postsInPeriod.toString(),
                    percentage: periodPercentage,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ComparisonItem(
                    label: 'Total Posts (All Time)',
                    value: totalPosts.toString(),
                    percentage: 100.0,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTrendChart() {
    final analytics = _analytics!;
    final dailyBreakdown = analytics['dailyBreakdown'] as Map<String, dynamic>?;
    
    if (dailyBreakdown == null || dailyBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedDaily = dailyBreakdown.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final chartData = sortedDaily.map((entry) {
      final date = DateTime.parse(entry.key);
      return ChartData(
        DateFormat('dd MMM').format(date),
        (entry.value as int).toDouble(),
        Colors.blue,
      );
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Post Activity Trend',
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
                  labelRotation: chartData.length > 7 ? -45 : 0,
                ),
                primaryYAxis: NumericAxis(),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  LineSeries<ChartData, String>(
                    dataSource: chartData,
                    xValueMapper: (data, _) => data.label,
                    yValueMapper: (data, _) => data.value,
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
    );
  }

  Widget _buildStatusChart() {
    final analytics = _analytics!;
    final data = [
      ChartData('Active', analytics['active'].toDouble(), Colors.green),
      ChartData('Pending', analytics['pending'].toDouble(), Colors.orange),
      ChartData('Completed', analytics['completed'].toDouble(), Colors.blue),
      ChartData('Rejected', analytics['rejected'].toDouble(), Colors.red),
    ].where((item) => item.value > 0).toList();

    if (data.isEmpty) {
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
            const Text(
              'Status Distribution (All Time)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCircularChart(
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                ),
                series: <CircularSeries>[
                  DoughnutSeries<ChartData, String>(
                    dataSource: data,
                    xValueMapper: (data, _) => data.label,
                    yValueMapper: (data, _) => data.value,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                    pointColorMapper: (data, _) => data.color,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    final analytics = _analytics!;
    final categoryBreakdown = analytics['categoryBreakdown'] as Map<String, dynamic>?;
    
    if (categoryBreakdown == null || categoryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out empty keys and ensure values are valid
    final validCategories = categoryBreakdown.entries
        .where((entry) => entry.key.isNotEmpty && entry.value != null && (entry.value as int) > 0)
        .toList();
    
    if (validCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedCategories = validCategories
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    final topCategories = sortedCategories.take(10).toList();
    final totalPosts = analytics['totalPosts'] as int;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Categories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Top 10 categories by post count',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            // Statistics List
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: topCategories.length,
                itemBuilder: (context, index) {
                  final entry = topCategories[index];
                  final count = entry.value as int;
                  final percentage = totalPosts > 0 ? (count / totalPosts * 100) : 0.0;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$count posts',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  labelRotation: topCategories.length > 5 ? -45 : 0,
                ),
                primaryYAxis: NumericAxis(),
                legend: const Legend(isVisible: false),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<MapEntry<String, dynamic>, String>(
                    name: 'Posts',
                    dataSource: topCategories,
                    xValueMapper: (entry, _) => entry.key.isNotEmpty ? entry.key : 'Unknown',
                    yValueMapper: (entry, _) => (entry.value as int? ?? 0),
                    color: Colors.blue,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      textStyle: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndustryChart() {
    final analytics = _analytics!;
    final industryBreakdown = analytics['industryBreakdown'] as Map<String, dynamic>?;
    
    if (industryBreakdown == null || industryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out empty keys and ensure values are valid
    final validIndustries = industryBreakdown.entries
        .where((entry) => entry.key.isNotEmpty && entry.value != null && (entry.value as int) > 0)
        .toList();
    
    if (validIndustries.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedIndustries = validIndustries
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    final topIndustries = sortedIndustries.take(10).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Industries',
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
                  labelRotation: topIndustries.length > 5 ? -45 : 0,
                ),
                primaryYAxis: NumericAxis(),
                legend: const Legend(isVisible: false),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<MapEntry<String, dynamic>, String>(
                    name: 'Posts',
                    dataSource: topIndustries,
                    xValueMapper: (entry, _) => entry.key.isNotEmpty ? entry.key : 'Unknown',
                    yValueMapper: (entry, _) => (entry.value as int? ?? 0),
                    color: Colors.purple,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      textStyle: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobTypeChart() {
    final analytics = _analytics!;
    final jobTypeBreakdown = analytics['jobTypeBreakdown'] as Map<String, dynamic>?;
    
    if (jobTypeBreakdown == null || jobTypeBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out empty keys and ensure values are valid
    final validJobTypes = jobTypeBreakdown.entries
        .where((entry) => entry.key.isNotEmpty && entry.value != null && (entry.value as int) > 0)
        .toList();
    
    if (validJobTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedJobTypes = validJobTypes
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Job Type Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                primaryYAxis: NumericAxis(),
                legend: const Legend(isVisible: false),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<MapEntry<String, dynamic>, String>(
                    name: 'Posts',
                    dataSource: sortedJobTypes,
                    xValueMapper: (entry, _) => entry.key.isNotEmpty ? entry.key : 'Unknown',
                    yValueMapper: (entry, _) => (entry.value as int? ?? 0),
                    color: Colors.teal,
                    dataLabelSettings: DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      textStyle: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationChart() {
    final analytics = _analytics!;
    final locationBreakdown = analytics['locationBreakdown'] as Map<String, dynamic>?;
    
    if (locationBreakdown == null || locationBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedLocations = locationBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topLocations = sortedLocations.take(10).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Locations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Top 10 locations by post count',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: topLocations.length,
                itemBuilder: (context, index) {
                  final entry = topLocations[index];
                  final count = entry.value as int;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '$count posts',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetAnalysis() {
    final analytics = _analytics!;
    final avgBudgetMin = analytics['avgBudgetMin'] as double?;
    final avgBudgetMax = analytics['avgBudgetMax'] as double?;

    if (avgBudgetMin == null && avgBudgetMax == null) {
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
            const Text(
              'Budget Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (avgBudgetMin != null)
                  Expanded(
                    child: _BudgetCard(
                      label: 'Average Min Budget',
                      value: 'RM ${avgBudgetMin.toStringAsFixed(2)}',
                      icon: Icons.arrow_downward,
                      color: Colors.green,
                    ),
                  ),
                if (avgBudgetMin != null && avgBudgetMax != null)
                  const SizedBox(width: 16),
                if (avgBudgetMax != null)
                  Expanded(
                    child: _BudgetCard(
                      label: 'Average Max Budget',
                      value: 'RM ${avgBudgetMax.toStringAsFixed(2)}',
                      icon: Icons.arrow_upward,
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStats() {
    final analytics = _analytics!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detailed Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Approval Rate', '${(analytics['approvalRate'] as double).toStringAsFixed(1)}%'),
            _buildStatRow('Rejection Rate', '${(analytics['rejectionRate'] as double).toStringAsFixed(1)}%'),
            _buildStatRow('Active Posts (Period)', analytics['activeInPeriod'].toString()),
            _buildStatRow('Pending Posts (Period)', analytics['pendingInPeriod'].toString()),
            _buildStatRow('Completed Posts (Period)', analytics['completedInPeriod'].toString()),
            _buildStatRow('Rejected Posts (Period)', analytics['rejectedInPeriod'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparisonItem extends StatelessWidget {
  final String label;
  final String value;
  final double percentage;
  final Color color;

  const _ComparisonItem({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
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
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: 4),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BudgetCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class ChartData {
  final String label;
  final double value;
  final Color color;

  ChartData(this.label, this.value, this.color);
}

class _DateTimeRangePickerDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const _DateTimeRangePickerDialog({
    required this.startDate,
    required this.endDate,
  });

  @override
  State<_DateTimeRangePickerDialog> createState() => _DateTimeRangePickerDialogState();
}

class _DateTimeRangePickerDialogState extends State<_DateTimeRangePickerDialog> {
  late DateTime _tempStartDate;
  late DateTime _tempEndDate;
  late TimeOfDay _tempStartTime;
  late TimeOfDay _tempEndTime;

  @override
  void initState() {
    super.initState();
    _tempStartDate = widget.startDate;
    _tempEndDate = widget.endDate;
    _tempStartTime = TimeOfDay.fromDateTime(widget.startDate);
    _tempEndTime = TimeOfDay.fromDateTime(widget.endDate);
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
        _tempStartDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _tempStartTime.hour,
          _tempStartTime.minute,
        );
      });
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _tempStartTime,
    );
    if (picked != null) {
      setState(() {
        _tempStartTime = picked;
        _tempStartDate = DateTime(
          _tempStartDate.year,
          _tempStartDate.month,
          _tempStartDate.day,
          picked.hour,
          picked.minute,
        );
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
        _tempEndDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _tempEndTime.hour,
          _tempEndTime.minute,
        );
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _tempEndTime,
    );
    if (picked != null) {
      setState(() {
        _tempEndTime = picked;
        _tempEndDate = DateTime(
          _tempEndDate.year,
          _tempEndDate.month,
          _tempEndDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Date & Time Range'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Start Date
            const Text(
              'Start Date & Time',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd/MM/yyyy').format(_tempStartDate),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _selectStartTime,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Time',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(_tempStartTime),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const Icon(Icons.access_time, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // End Date
            const Text(
              'End Date & Time',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd/MM/yyyy').format(_tempEndDate),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: _selectEndTime,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Time',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(_tempEndTime),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const Icon(Icons.access_time, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
                      _tempStartDate = DateTime(now.year, now.month, now.day, 0, 0);
                      _tempEndDate = now;
                      _tempStartTime = const TimeOfDay(hour: 0, minute: 0);
                      _tempEndTime = TimeOfDay.fromDateTime(now);
                    });
                  },
                ),
                _QuickDateButton(
                  label: 'Last 7 Days',
                  onTap: () {
                    final now = DateTime.now();
                    setState(() {
                      _tempStartDate = now.subtract(const Duration(days: 7));
                      _tempEndDate = now;
                      _tempStartTime = TimeOfDay.fromDateTime(_tempStartDate);
                      _tempEndTime = TimeOfDay.fromDateTime(_tempEndDate);
                    });
                  },
                ),
                _QuickDateButton(
                  label: 'Last 30 Days',
                  onTap: () {
                    final now = DateTime.now();
                    setState(() {
                      _tempStartDate = now.subtract(const Duration(days: 30));
                      _tempEndDate = now;
                      _tempStartTime = TimeOfDay.fromDateTime(_tempStartDate);
                      _tempEndTime = TimeOfDay.fromDateTime(_tempEndDate);
                    });
                  },
                ),
                _QuickDateButton(
                  label: 'This Month',
                  onTap: () {
                    final now = DateTime.now();
                    setState(() {
                      _tempStartDate = DateTime(now.year, now.month, 1, 0, 0);
                      _tempEndDate = now;
                      _tempStartTime = const TimeOfDay(hour: 0, minute: 0);
                      _tempEndTime = TimeOfDay.fromDateTime(_tempEndDate);
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
