import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:fyp_project/services/admin/post_analytics_service.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:fyp_project/utils/admin/app_colors.dart';

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

  // Helper to set start of day
  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 0, 0, 0);
  }
  
  // Helper to set end of day
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
      final analytics = await _analyticsService.getPostAnalytics(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (mounted) {
        setState(() => _analytics = analytics);
      }
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDateTimeRange() async {
    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) =>
          _DateTimeRangePickerDialog(startDate: _startDate, endDate: _endDate),
    );

    if (result != null && mounted) {
      setState(() {
        _startDate = _startOfDay(result['start']!);
        _endDate = _endOfDay(result['end']!);
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
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Content Analytics Report',
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

              // Date Range
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
                      '${_formatDateTime(_startDate)} - ${_formatDateTime(_endDate)}',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Overview Statistics
              pw.Text(
                'Overview Statistics',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
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
                headers: ['Metric', 'All Time', 'Selected Period'],
                data: [
                  [
                    'Total Posts',
                    analytics['totalPosts'].toString(),
                    analytics['postsInPeriod'].toString(),
                  ],
                  [
                    'Pending',
                    analytics['pending'].toString(),
                    analytics['pendingInPeriod'].toString(),
                  ],
                  [
                    'Active',
                    analytics['active'].toString(),
                    analytics['activeInPeriod'].toString(),
                  ],
                  [
                    'Completed',
                    analytics['completed'].toString(),
                    analytics['completedInPeriod'].toString(),
                  ],
                  [
                    'Rejected',
                    analytics['rejected'].toString(),
                    analytics['rejectedInPeriod'].toString(),
                  ],
                  [
                    'Approval Rate',
                    '${(analytics['approvalRate'] as double).toStringAsFixed(1)}%',
                    () {
                      final activeInPeriod = analytics['activeInPeriod'] as int;
                      final completedInPeriod = analytics['completedInPeriod'] as int;
                      final rejectedInPeriod = analytics['rejectedInPeriod'] as int;
                      final approvedInPeriod = activeInPeriod + completedInPeriod;
                      final totalProcessedInPeriod = approvedInPeriod + rejectedInPeriod;
                      if (totalProcessedInPeriod > 0) {
                        final rate = (approvedInPeriod / totalProcessedInPeriod) * 100;
                        return '${rate.toStringAsFixed(1)}%';
                      }
                      return '0.0%';
                    }(),
                  ],
                  [
                    'Rejection Rate',
                    '${(analytics['rejectionRate'] as double).toStringAsFixed(1)}%',
                    () {
                      final activeInPeriod = analytics['activeInPeriod'] as int;
                      final completedInPeriod = analytics['completedInPeriod'] as int;
                      final rejectedInPeriod = analytics['rejectedInPeriod'] as int;
                      final approvedInPeriod = activeInPeriod + completedInPeriod;
                      final totalProcessedInPeriod = approvedInPeriod + rejectedInPeriod;
                      if (totalProcessedInPeriod > 0) {
                        final rate = (rejectedInPeriod / totalProcessedInPeriod) * 100;
                        return '${rate.toStringAsFixed(1)}%';
                      }
                      return '0.0%';
                    }(),
                  ],
                ],
              ),
              pw.SizedBox(height: 20),

              // Budget Analysis
              if (analytics['avgBudgetMin'] != null ||
                  analytics['avgBudgetMax'] != null) ...[
                pw.Text(
                  'Budget Analysis',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
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
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  headers: ['Metric', 'Value'],
                  data: [
                    if (analytics['avgBudgetMin'] != null)
                      [
                        'Average Budget Min',
                        'RM ${(analytics['avgBudgetMin'] as double).toStringAsFixed(2)}',
                      ],
                    if (analytics['avgBudgetMax'] != null)
                      [
                        'Average Budget Max',
                        'RM ${(analytics['avgBudgetMax'] as double).toStringAsFixed(2)}',
                      ],
                  ].whereType<List<String>>().toList(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Event Breakdown (using event field)
              if (analytics['eventBreakdown'] != null &&
                  (analytics['eventBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Event Breakdown (Top 10)',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
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
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  headers: ['Event', 'Posts'],
                  data: () {
                    final entries =
                        (analytics['eventBreakdown'] as Map<String, dynamic>)
                            .entries
                            .toList();
                    entries.sort((a, b) => b.value.compareTo(a.value));
                    return entries
                        .take(10)
                        .map((entry) => [entry.key, entry.value.toString()])
                        .toList();
                  }(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Job Type Breakdown
              if (analytics['jobTypeBreakdown'] != null &&
                  (analytics['jobTypeBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Job Type Breakdown',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
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
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  headers: ['Job Type', 'Posts'],
                  data: () {
                    final entries =
                        (analytics['jobTypeBreakdown'] as Map<String, dynamic>)
                            .entries
                            .toList();
                    entries.sort((a, b) => b.value.compareTo(a.value));
                    return entries
                        .map((entry) => [entry.key, entry.value.toString()])
                        .toList();
                  }(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Location Breakdown (State only)
              if (analytics['locationBreakdown'] != null &&
                  (analytics['locationBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Location Breakdown by State (Top 10)',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
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
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  headers: ['State', 'Posts'],
                  data: () {
                    final entries =
                        (analytics['locationBreakdown'] as Map<String, dynamic>)
                            .entries
                            .toList();
                    entries.sort((a, b) => b.value.compareTo(a.value));
                    return entries
                        .take(10)
                        .map((entry) => [entry.key, entry.value.toString()])
                        .toList();
                  }(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Tags Breakdown
              if (analytics['tagsBreakdown'] != null &&
                  (analytics['tagsBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Tags Breakdown (Top 10)',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
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
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  headers: ['Tag', 'Posts'],
                  data: () {
                    final entries =
                        (analytics['tagsBreakdown'] as Map<String, dynamic>)
                            .entries
                            .toList();
                    entries.sort((a, b) => b.value.compareTo(a.value));
                    return entries
                        .take(10)
                        .map((entry) => [entry.key, entry.value.toString()])
                        .toList();
                  }(),
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
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sharePDF() async {
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
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Content Analytics Report',
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

              // Date Range
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
                      '${_formatDateTime(_startDate)} - ${_formatDateTime(_endDate)}',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Overview Statistics
              pw.Text(
                'Overview Statistics',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
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
                headers: ['Metric', 'All Time', 'Selected Period'],
                data: [
                  [
                    'Total Posts',
                    analytics['totalPosts'].toString(),
                    analytics['postsInPeriod'].toString(),
                  ],
                  [
                    'Pending',
                    analytics['pending'].toString(),
                    analytics['pendingInPeriod'].toString(),
                  ],
                  [
                    'Active',
                    analytics['active'].toString(),
                    analytics['activeInPeriod'].toString(),
                  ],
                  [
                    'Completed',
                    analytics['completed'].toString(),
                    analytics['completedInPeriod'].toString(),
                  ],
                  [
                    'Rejected',
                    analytics['rejected'].toString(),
                    analytics['rejectedInPeriod'].toString(),
                  ],
                  [
                    'Approval Rate',
                    '${(analytics['approvalRate'] as double).toStringAsFixed(1)}%',
                    () {
                      final activeInPeriod = analytics['activeInPeriod'] as int;
                      final completedInPeriod = analytics['completedInPeriod'] as int;
                      final rejectedInPeriod = analytics['rejectedInPeriod'] as int;
                      final approvedInPeriod = activeInPeriod + completedInPeriod;
                      final totalProcessedInPeriod = approvedInPeriod + rejectedInPeriod;
                      if (totalProcessedInPeriod > 0) {
                        final rate = (approvedInPeriod / totalProcessedInPeriod) * 100;
                        return '${rate.toStringAsFixed(1)}%';
                      }
                      return '0.0%';
                    }(),
                  ],
                  [
                    'Rejection Rate',
                    '${(analytics['rejectionRate'] as double).toStringAsFixed(1)}%',
                    () {
                      final activeInPeriod = analytics['activeInPeriod'] as int;
                      final completedInPeriod = analytics['completedInPeriod'] as int;
                      final rejectedInPeriod = analytics['rejectedInPeriod'] as int;
                      final approvedInPeriod = activeInPeriod + completedInPeriod;
                      final totalProcessedInPeriod = approvedInPeriod + rejectedInPeriod;
                      if (totalProcessedInPeriod > 0) {
                        final rate = (rejectedInPeriod / totalProcessedInPeriod) * 100;
                        return '${rate.toStringAsFixed(1)}%';
                      }
                      return '0.0%';
                    }(),
                  ],
                ],
              ),
              pw.SizedBox(height: 20),

              // Budget Analysis
              if (analytics['avgBudgetMin'] != null ||
                  analytics['avgBudgetMax'] != null) ...[
                pw.Text(
                  'Budget Analysis',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
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
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  headers: ['Metric', 'Value'],
                  data: [
                    if (analytics['avgBudgetMin'] != null)
                      [
                        'Average Budget Min',
                        'RM ${(analytics['avgBudgetMin'] as double).toStringAsFixed(2)}',
                      ],
                    if (analytics['avgBudgetMax'] != null)
                      [
                        'Average Budget Max',
                        'RM ${(analytics['avgBudgetMax'] as double).toStringAsFixed(2)}',
                      ],
                  ].whereType<List<String>>().toList(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Event Breakdown (using event field)
              if (analytics['eventBreakdown'] != null &&
                  (analytics['eventBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Event Breakdown (Top 10)',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
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
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  headers: ['Event', 'Posts'],
                  data: () {
                    final entries =
                        (analytics['eventBreakdown'] as Map<String, dynamic>)
                            .entries
                            .toList();
                    entries.sort((a, b) => b.value.compareTo(a.value));
                    return entries
                        .take(10)
                        .map((entry) => [entry.key, entry.value.toString()])
                        .toList();
                  }(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Job Type Breakdown
              if (analytics['jobTypeBreakdown'] != null &&
                  (analytics['jobTypeBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Job Type Breakdown',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
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
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  headers: ['Job Type', 'Posts'],
                  data: () {
                    final entries =
                        (analytics['jobTypeBreakdown'] as Map<String, dynamic>)
                            .entries
                            .toList();
                    entries.sort((a, b) => b.value.compareTo(a.value));
                    return entries
                        .map((entry) => [entry.key, entry.value.toString()])
                        .toList();
                  }(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Location Breakdown (State only)
              if (analytics['locationBreakdown'] != null &&
                  (analytics['locationBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Location Breakdown by State (Top 10)',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
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
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  headers: ['State', 'Posts'],
                  data: () {
                    final entries =
                        (analytics['locationBreakdown'] as Map<String, dynamic>)
                            .entries
                            .toList();
                    entries.sort((a, b) => b.value.compareTo(a.value));
                    return entries
                        .take(10)
                        .map((entry) => [entry.key, entry.value.toString()])
                        .toList();
                  }(),
                ),
                pw.SizedBox(height: 20),
              ],

              // Tags Breakdown
              if (analytics['tagsBreakdown'] != null &&
                  (analytics['tagsBreakdown'] as Map).isNotEmpty) ...[
                pw.Text(
                  'Tags Breakdown (Top 10)',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.TableHelper.fromTextArray(
                  context: context,
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
                      bottom: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 0.5,
                      ),
                    ),
                  ),
                  headers: ['Tag', 'Posts'],
                  data: () {
                    final entries =
                        (analytics['tagsBreakdown'] as Map<String, dynamic>)
                            .entries
                            .toList();
                    entries.sort((a, b) => b.value.compareTo(a.value));
                    return entries
                        .take(10)
                        .map((entry) => [entry.key, entry.value.toString()])
                        .toList();
                  }(),
                ),
                pw.SizedBox(height: 20),
              ],
            ];
          },
        ),
      );

      // Save PDF to temporary file and share
      final bytes = await pdf.save();
      final directory = await getTemporaryDirectory();
      final fileName = 'Content_Analytics_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Share the file
      try {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Content Analytics Report',
          subject: 'Content Analytics Report - ${_formatDateTime(_startDate)} to ${_formatDateTime(_endDate)}',
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
        // Handle MissingPluginException specifically
        if (shareError.toString().contains('MissingPluginException') || 
            shareError.toString().contains('missing plugin')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('分享功能需要重新构建应用。请运行: flutter clean && flutter pub get && flutter run'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
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
              onPressed: _downloadPDF,
              tooltip: 'Download PDF',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryDark,
                  AppColors.primaryMedium,
                ],
              ),
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

                        // Status Comparison
                        _buildStatusComparison(),
                        const SizedBox(height: 20),

                        // Event Breakdown
                        _buildEventChart(),
                        const SizedBox(height: 20),

                        // Event Comparison
                        _buildEventComparison(),
                        const SizedBox(height: 20),

                        // Tags Breakdown
                        _buildTagsChart(),
                        const SizedBox(height: 20),

                        // Tags Comparison
                        _buildTagsComparison(),
                        const SizedBox(height: 20),

                        // Industry Breakdown
                        _buildIndustryChart(),
                        const SizedBox(height: 20),

                        // Industry Comparison
                        _buildIndustryComparison(),
                        const SizedBox(height: 20),

                        // Job Type Breakdown
                        _buildJobTypeChart(),
                        const SizedBox(height: 20),

                        // Job Type Comparison
                        _buildJobTypeComparison(),
                        const SizedBox(height: 20),

                        // Location Breakdown
                        _buildLocationChart(),
                        const SizedBox(height: 20),

                        // Location Comparison
                        _buildLocationComparison(),
                        const SizedBox(height: 20),

                        // Budget Analysis
                        _buildBudgetAnalysis(),
                        const SizedBox(height: 20),

                        // Budget Comparison
                        _buildBudgetComparison(),
                        const SizedBox(height: 20),

                        // Detailed Statistics Comparison
                        _buildDetailedStatsComparison(),
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
    return SizedBox(
      height: 140,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(right: 50),
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
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withOpacity(0),
                      Colors.white.withOpacity(0.8),
                      Colors.white,
                    ],
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Scroll',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
    final periodPercentage = totalPosts > 0
        ? (postsInPeriod / totalPosts * 100)
        : 0.0;

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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
    // Show selected period data
    final statusData = [
      MapEntry('Active', analytics['activeInPeriod'] as int? ?? 0),
      MapEntry('Pending', analytics['pendingInPeriod'] as int? ?? 0),
      MapEntry('Completed', analytics['completedInPeriod'] as int? ?? 0),
      MapEntry('Rejected', analytics['rejectedInPeriod'] as int? ?? 0),
    ].where((entry) => entry.value > 0).toList();

    if (statusData.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalPosts = analytics['postsInPeriod'] as int;
    final statusColors = {
      'Active': Colors.green,
      'Pending': Colors.orange,
      'Completed': Colors.blue,
      'Rejected': Colors.red,
    };

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Distribution (Selected Period)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Post status breakdown in selected period',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // Statistics List
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: statusData.length,
                itemBuilder: (context, index) {
                  final entry = statusData[index];
                  final count = entry.value;
                  final percentage = totalPosts > 0
                      ? (count / totalPosts * 100)
                      : 0.0;
                  final statusColor = statusColors[entry.key] ?? Colors.grey;

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
                              color: statusColor,
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
                  isVisible: false,
                ),
                primaryYAxis: NumericAxis(),
                legend: const Legend(isVisible: false),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<MapEntry<String, int>, String>(
                    name: 'Posts',
                    dataSource: statusData,
                    xValueMapper: (entry, _) => entry.key,
                    yValueMapper: (entry, _) => entry.value,
                    pointColorMapper: (entry, _) => statusColors[entry.key] ?? Colors.grey,
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

  Widget _buildEventChart() {
    final analytics = _analytics!;
    // Use period data
    final eventBreakdown =
        analytics['eventBreakdownInPeriod'] as Map<String, dynamic>?;

    if (eventBreakdown == null || eventBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out empty keys and ensure values are valid
    final validEvents = eventBreakdown.entries
        .where(
          (entry) =>
              entry.key.isNotEmpty &&
              entry.value != null &&
              (entry.value as int) > 0,
        )
        .toList();

    if (validEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedEvents = validEvents
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    final topEvents = sortedEvents.take(10).toList();
    final totalPosts = analytics['postsInPeriod'] as int;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Events (Selected Period)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Top 10 events by post count in selected period',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // Statistics List with scroll indicator
            Stack(
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: topEvents.length,
                    itemBuilder: (context, index) {
                      final entry = topEvents[index];
                      final count = entry.value as int;
                      final percentage = totalPosts > 0
                          ? (count / totalPosts * 100)
                          : 0.0;

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
                if (topEvents.length > 3)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(0.8),
                            Colors.white,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Scroll for more',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  isVisible: false,
                ),
                primaryYAxis: NumericAxis(),
                legend: const Legend(isVisible: false),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<MapEntry<String, dynamic>, String>(
                    name: 'Posts',
                    dataSource: topEvents,
                    xValueMapper: (entry, _) =>
                        entry.key.isNotEmpty ? entry.key : 'Unknown',
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

  Widget _buildTagsChart() {
    final analytics = _analytics!;
    // Use period data
    final tagsBreakdown =
        analytics['tagsBreakdownInPeriod'] as Map<String, dynamic>?;

    if (tagsBreakdown == null || tagsBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out empty keys and ensure values are valid
    final validTags = tagsBreakdown.entries
        .where(
          (entry) =>
              entry.key.isNotEmpty &&
              entry.value != null &&
              (entry.value as int) > 0,
        )
        .toList();

    if (validTags.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedTags = validTags
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    final topTags = sortedTags.take(10).toList();
    final totalPosts = analytics['postsInPeriod'] as int;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Tags (Selected Period)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Top 10 tags by post count in selected period',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // Statistics List with scroll indicator
            Stack(
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: topTags.length,
                    itemBuilder: (context, index) {
                      final entry = topTags[index];
                      final count = entry.value as int;
                      final percentage = totalPosts > 0
                          ? (count / totalPosts * 100)
                          : 0.0;

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
                                  color: Colors.orange[700],
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
                if (topTags.length > 3)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0),
                            Colors.white.withOpacity(0.8),
                            Colors.white,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Scroll for more',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  isVisible: false,
                ),
                primaryYAxis: NumericAxis(),
                legend: const Legend(isVisible: false),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<MapEntry<String, dynamic>, String>(
                    name: 'Posts',
                    dataSource: topTags,
                    xValueMapper: (entry, _) =>
                        entry.key.isNotEmpty ? entry.key : 'Unknown',
                    yValueMapper: (entry, _) => (entry.value as int? ?? 0),
                    color: Colors.orange,
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
    // Use period data (now using event field)
    final industryBreakdown =
        analytics['industryBreakdownInPeriod'] as Map<String, dynamic>?;

    if (industryBreakdown == null || industryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out empty keys and ensure values are valid
    final validIndustries = industryBreakdown.entries
        .where(
          (entry) =>
              entry.key.isNotEmpty &&
              entry.value != null &&
              (entry.value as int) > 0,
        )
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
              'Top Events (Selected Period)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Top 10 Events by post count in selected period',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  isVisible: false,
                ),
                primaryYAxis: NumericAxis(),
                legend: const Legend(isVisible: false),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: <CartesianSeries>[
                  ColumnSeries<MapEntry<String, dynamic>, String>(
                    name: 'Posts',
                    dataSource: topIndustries,
                    xValueMapper: (entry, _) =>
                        entry.key.isNotEmpty ? entry.key : 'Unknown',
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
    // Use period data
    final jobTypeBreakdown =
        analytics['jobTypeBreakdownInPeriod'] as Map<String, dynamic>?;

    if (jobTypeBreakdown == null || jobTypeBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out empty keys and ensure values are valid
    final validJobTypes = jobTypeBreakdown.entries
        .where(
          (entry) =>
              entry.key.isNotEmpty &&
              entry.value != null &&
              (entry.value as int) > 0,
        )
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
              'Job Type Distribution (Selected Period)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    xValueMapper: (entry, _) =>
                        entry.key.isNotEmpty ? entry.key : 'Unknown',
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
    // Use period data
    final locationBreakdown =
        analytics['locationBreakdownInPeriod'] as Map<String, dynamic>?;

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
              'Top Locations (Selected Period)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Top 10 locations by post count in selected period',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
    // Use period data
    final avgBudgetMin = analytics['avgBudgetMinInPeriod'] as double?;
    final avgBudgetMax = analytics['avgBudgetMaxInPeriod'] as double?;

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
              'Budget Analysis (Selected Period)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildStatusComparison() {
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
              'Status Distribution: All Time vs Selected Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildComparisonHeader(),
            _buildComparisonRow('Active', analytics['active'], analytics['activeInPeriod']),
            _buildComparisonRow('Pending', analytics['pending'], analytics['pendingInPeriod']),
            _buildComparisonRow('Completed', analytics['completed'], analytics['completedInPeriod']),
            _buildComparisonRow('Rejected', analytics['rejected'], analytics['rejectedInPeriod']),
          ],
        ),
      ),
    );
  }

  Widget _buildEventComparison() {
    final analytics = _analytics!;
    final allTime = analytics['eventBreakdown'] as Map<String, dynamic>? ?? {};
    final period = analytics['eventBreakdownInPeriod'] as Map<String, dynamic>? ?? {};
    
    if (allTime.isEmpty && period.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get top 5 from each
    final allTimeTop = allTime.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    final periodTop = period.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    final allKeys = {...allTimeTop.take(5).map((e) => e.key), ...periodTop.take(5).map((e) => e.key)};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Events: All Time vs Selected Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildComparisonHeader(),
            ...allKeys.take(5).map((key) => _buildComparisonRow(
              key,
              allTime[key] ?? 0,
              period[key] ?? 0,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsComparison() {
    final analytics = _analytics!;
    final allTime = analytics['tagsBreakdown'] as Map<String, dynamic>? ?? {};
    final period = analytics['tagsBreakdownInPeriod'] as Map<String, dynamic>? ?? {};
    
    if (allTime.isEmpty && period.isEmpty) {
      return const SizedBox.shrink();
    }

    final allTimeTop = allTime.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    final periodTop = period.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    final allKeys = {...allTimeTop.take(5).map((e) => e.key), ...periodTop.take(5).map((e) => e.key)};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Tags: All Time vs Selected Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildComparisonHeader(),
            ...allKeys.take(5).map((key) => _buildComparisonRow(
              key,
              allTime[key] ?? 0,
              period[key] ?? 0,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildIndustryComparison() {
    final analytics = _analytics!;
    final allTime = analytics['industryBreakdown'] as Map<String, dynamic>? ?? {};
    final period = analytics['industryBreakdownInPeriod'] as Map<String, dynamic>? ?? {};
    
    if (allTime.isEmpty && period.isEmpty) {
      return const SizedBox.shrink();
    }

    final allTimeTop = allTime.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    final periodTop = period.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    final allKeys = {...allTimeTop.take(5).map((e) => e.key), ...periodTop.take(5).map((e) => e.key)};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Industries: All Time vs Selected Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Based on event field from posts collection',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            _buildComparisonHeader(),
            ...allKeys.take(5).map((key) => _buildComparisonRow(
              key,
              allTime[key] ?? 0,
              period[key] ?? 0,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildJobTypeComparison() {
    final analytics = _analytics!;
    final allTime = analytics['jobTypeBreakdown'] as Map<String, dynamic>? ?? {};
    final period = analytics['jobTypeBreakdownInPeriod'] as Map<String, dynamic>? ?? {};
    
    if (allTime.isEmpty && period.isEmpty) {
      return const SizedBox.shrink();
    }

    final allKeys = {...allTime.keys, ...period.keys};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Job Types: All Time vs Selected Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildComparisonHeader(),
            ...allKeys.map((key) => _buildComparisonRow(
              key,
              allTime[key] ?? 0,
              period[key] ?? 0,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationComparison() {
    final analytics = _analytics!;
    final allTime = analytics['locationBreakdown'] as Map<String, dynamic>? ?? {};
    final period = analytics['locationBreakdownInPeriod'] as Map<String, dynamic>? ?? {};
    
    if (allTime.isEmpty && period.isEmpty) {
      return const SizedBox.shrink();
    }

    final allTimeTop = allTime.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    final periodTop = period.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    final allKeys = {...allTimeTop.take(5).map((e) => e.key), ...periodTop.take(5).map((e) => e.key)};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Locations: All Time vs Selected Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildComparisonHeader(),
            ...allKeys.take(5).map((key) => _buildComparisonRow(
              key,
              allTime[key] ?? 0,
              period[key] ?? 0,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetComparison() {
    final analytics = _analytics!;
    final allTimeMin = analytics['avgBudgetMin'] as double?;
    final allTimeMax = analytics['avgBudgetMax'] as double?;
    final periodMin = analytics['avgBudgetMinInPeriod'] as double?;
    final periodMax = analytics['avgBudgetMaxInPeriod'] as double?;

    if (allTimeMin == null && allTimeMax == null && periodMin == null && periodMax == null) {
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
              'Budget Analysis: All Time vs Selected Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildComparisonHeader(),
            if (allTimeMin != null || periodMin != null)
              _buildComparisonRow(
                'Average Min Budget',
                allTimeMin != null ? 'RM ${allTimeMin.toStringAsFixed(2)}' : 'N/A',
                periodMin != null ? 'RM ${periodMin.toStringAsFixed(2)}' : 'N/A',
                isString: true,
              ),
            if (allTimeMax != null || periodMax != null)
              _buildComparisonRow(
                'Average Max Budget',
                allTimeMax != null ? 'RM ${allTimeMax.toStringAsFixed(2)}' : 'N/A',
                periodMax != null ? 'RM ${periodMax.toStringAsFixed(2)}' : 'N/A',
                isString: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStatsComparison() {
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
              'Detailed Statistics: All Time vs Selected Period',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildComparisonHeader(),
            _buildComparisonRow(
              'Approval Rate',
              '${(analytics['approvalRate'] as double).toStringAsFixed(1)}%',
              '${(analytics['approvalRateInPeriod'] as double).toStringAsFixed(1)}%',
              isString: true,
            ),
            _buildComparisonRow(
              'Rejection Rate',
              '${(analytics['rejectionRate'] as double).toStringAsFixed(1)}%',
              '${(analytics['rejectionRateInPeriod'] as double).toStringAsFixed(1)}%',
              isString: true,
            ),
            _buildComparisonRow('Active Posts', analytics['active'], analytics['activeInPeriod']),
            _buildComparisonRow('Pending Posts', analytics['pending'], analytics['pendingInPeriod']),
            _buildComparisonRow('Completed Posts', analytics['completed'], analytics['completedInPeriod']),
            _buildComparisonRow('Rejected Posts', analytics['rejected'], analytics['rejectedInPeriod']),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'Metric',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              'All Time',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Selected Period',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, dynamic allTimeValue, dynamic periodValue, {bool isString = false}) {
    final allTimeStr = isString ? allTimeValue.toString() : allTimeValue.toString();
    final periodStr = isString ? periodValue.toString() : periodValue.toString();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                allTimeStr,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                periodStr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),
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
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
  State<_DateTimeRangePickerDialog> createState() =>
      _DateTimeRangePickerDialogState();
}

class _DateTimeRangePickerDialogState
    extends State<_DateTimeRangePickerDialog> {
  late DateTime _tempStartDate;
  late DateTime _tempEndDate;

  @override
  void initState() {
    super.initState();
    // Extract just the date part
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
    if (picked != null && mounted) {
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
    if (picked != null && mounted) {
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

  const _QuickDateButton({required this.label, required this.onTap});

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
