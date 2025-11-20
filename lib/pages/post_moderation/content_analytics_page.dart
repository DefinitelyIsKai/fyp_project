import 'package:flutter/material.dart';
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
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => _DateRangePickerDialog(
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

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _getDateRangeText() {
    final daysDiff = _endDate.difference(_startDate).inDays;
    if (daysDiff == 0) return 'Today';
    if (daysDiff == 29 && _endDate.day == DateTime.now().day) return 'Last 30 days';
    return '${_formatDate(_startDate)} - ${_formatDate(_endDate)}';
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

              // Overview Statistics
              pw.Text(
                'Overview Statistics',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    children: [
                      _buildTableCell('Total Posts', analytics['totalPosts'].toString()),
                      _buildTableCell('Posts in Period', analytics['postsInPeriod'].toString()),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('Pending', analytics['pending'].toString()),
                      _buildTableCell('Active', analytics['active'].toString()),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('Completed', analytics['completed'].toString()),
                      _buildTableCell('Rejected', analytics['rejected'].toString()),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell('Approval Rate', '${(analytics['approvalRate'] as double).toStringAsFixed(1)}%'),
                      _buildTableCell('Rejection Rate', '${(analytics['rejectionRate'] as double).toStringAsFixed(1)}%'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Category Breakdown
              if (analytics['categoryBreakdown'] != null && (analytics['categoryBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Category Breakdown',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                  },
                  children: (analytics['categoryBreakdown'] as Map<String, dynamic>)
                      .entries
                      .map((entry) => pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Expanded(
                                      flex: 2,
                                      child: pw.Text(
                                        entry.key,
                                        style: pw.TextStyle(fontSize: 12),
                                        maxLines: 2,
                                      ),
                                    ),
                                    pw.SizedBox(width: 8),
                                    pw.Expanded(
                                      flex: 1,
                                      child: pw.Text(
                                        entry.value.toString(),
                                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                                        textAlign: pw.TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ))
                      .toList(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Location Breakdown
              if (analytics['locationBreakdown'] != null && (analytics['locationBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Location Breakdown',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                  },
                  children: (analytics['locationBreakdown'] as Map<String, dynamic>)
                      .entries
                      .take(10)
                      .map((entry) => pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(8),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Expanded(
                                      flex: 2,
                                      child: pw.Text(
                                        entry.key,
                                        style: pw.TextStyle(fontSize: 12),
                                        maxLines: 2,
                                      ),
                                    ),
                                    pw.SizedBox(width: 8),
                                    pw.Expanded(
                                      flex: 1,
                                      child: pw.Text(
                                        entry.value.toString(),
                                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                                        textAlign: pw.TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ))
                      .toList(),
                ),
                pw.SizedBox(height: 20),
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
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  pw.Widget _buildTableCell(String text, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              text,
              style: pw.TextStyle(fontSize: 12),
              maxLines: 2,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.right,
              maxLines: 1,
            ),
          ),
        ],
      ),
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
                  'Track post performance and engagement statistics',
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
                          Icon(Icons.calendar_today, color: Colors.blue[700]),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
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

                            // Status Distribution Chart
                            _buildStatusChart(),
                            const SizedBox(height: 20),

                            // Category Breakdown
                            _buildCategoryChart(),
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
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Total Posts',
            value: analytics['totalPosts'].toString(),
            icon: Icons.article,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Active',
            value: analytics['active'].toString(),
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Pending',
            value: analytics['pending'].toString(),
            icon: Icons.pending,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Rejected',
            value: analytics['rejected'].toString(),
            icon: Icons.cancel,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChart() {
    final analytics = _analytics!;
    final data = [
      ChartData('Active', analytics['active'].toDouble(), Colors.green),
      ChartData('Pending', analytics['pending'].toDouble(), Colors.orange),
      ChartData('Completed', analytics['completed'].toDouble(), Colors.blue),
      ChartData('Rejected', analytics['rejected'].toDouble(), Colors.red),
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Distribution',
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

    final sortedCategories = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sortedCategories.take(10).toList();
    final totalPosts = analytics['totalPosts'] as int;
    final totalInCategories = topCategories.fold<int>(0, (sum, entry) => sum + (entry.value as int));

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
              'Total: $totalInCategories posts across ${topCategories.length} categories',
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
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries<MapEntry<String, dynamic>, String>>[
                  ColumnSeries<MapEntry<String, dynamic>, String>(
                    dataSource: topCategories,
                    xValueMapper: (entry, _) => entry.key,
                    yValueMapper: (entry, _) => entry.value as int,
                    color: Colors.blue,
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
            if (analytics['avgBudgetMin'] != null)
              _buildStatRow('Avg Budget Min', '\$${(analytics['avgBudgetMin'] as double).toStringAsFixed(2)}'),
            if (analytics['avgBudgetMax'] != null)
              _buildStatRow('Avg Budget Max', '\$${(analytics['avgBudgetMax'] as double).toStringAsFixed(2)}'),
            _buildStatRow('Posts in Period', analytics['postsInPeriod'].toString()),
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
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
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
          ],
        ),
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
    _tempStartDate = widget.startDate;
    _tempEndDate = widget.endDate;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempStartDate,
      firstDate: DateTime(2020),
      lastDate: _tempEndDate,
    );
    if (picked != null) {
      setState(() => _tempStartDate = picked);
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
      setState(() => _tempEndDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Date Range'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _selectStartDate,
            child: Container(
              padding: const EdgeInsets.all(16),
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
                        'Start Date',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(_tempStartDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _selectEndDate,
            child: Container(
              padding: const EdgeInsets.all(16),
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
                        'End Date',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(_tempEndDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
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

