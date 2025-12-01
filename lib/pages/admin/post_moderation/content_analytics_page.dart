import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:fyp_project/services/admin/post_analytics_service.dart';
import 'package:fyp_project/widgets/admin/cards/content_analytics_budget_card.dart';
import 'package:fyp_project/widgets/admin/dialogs/date_range_picker_dialog.dart' as custom;
import 'package:fyp_project/widgets/admin/common/content_analytics_quick_stats.dart';
import 'package:fyp_project/widgets/admin/common/content_analytics_date_range_selector.dart';
import 'package:fyp_project/widgets/admin/common/content_analytics_comparison_widgets.dart';
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
          ContentAnalyticsDateRangeSelector(
            dateRangeText: _getDateRangeText(),
            onTap: _selectDateTimeRange,
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
                        ContentAnalyticsQuickStats(analytics: _analytics!),
                        const SizedBox(height: 20),

                        // Period Comparison
                        ContentAnalyticsPeriodComparison(
                          totalPosts: _analytics!['totalPosts'] as int,
                          postsInPeriod: _analytics!['postsInPeriod'] as int,
                        ),
                        const SizedBox(height: 20),

                        // Daily Trend Chart
                        _buildDailyTrendChart(),
                        const SizedBox(height: 20),

                        // Status Distribution Chart
                        _buildStatusChart(),
                        const SizedBox(height: 20),

                        // Status Comparison
                        ContentAnalyticsStatusComparison(analytics: _analytics!),
                        const SizedBox(height: 20),

                        // Event Breakdown
                        _buildEventChart(),
                        const SizedBox(height: 20),

                        // Event Comparison
                        ContentAnalyticsBreakdownComparison(
                          title: 'Top Events: All Time vs Selected Period',
                          allTime: _analytics!['eventBreakdown'] as Map<String, dynamic>? ?? {},
                          period: _analytics!['eventBreakdownInPeriod'] as Map<String, dynamic>? ?? {},
                        ),
                        const SizedBox(height: 20),

                        // Tags Breakdown
                        _buildTagsChart(),
                        const SizedBox(height: 20),

                        // Tags Comparison
                        ContentAnalyticsBreakdownComparison(
                          title: 'Top Tags: All Time vs Selected Period',
                          allTime: _analytics!['tagsBreakdown'] as Map<String, dynamic>? ?? {},
                          period: _analytics!['tagsBreakdownInPeriod'] as Map<String, dynamic>? ?? {},
                        ),
                        const SizedBox(height: 20),

                        // Industry Breakdown
                        _buildIndustryChart(),
                        const SizedBox(height: 20),

                        // Industry Comparison
                        ContentAnalyticsBreakdownComparison(
                          title: 'Top Industries: All Time vs Selected Period',
                          subtitle: 'Based on event field from posts collection',
                          allTime: _analytics!['industryBreakdown'] as Map<String, dynamic>? ?? {},
                          period: _analytics!['industryBreakdownInPeriod'] as Map<String, dynamic>? ?? {},
                        ),
                        const SizedBox(height: 20),

                        // Job Type Breakdown
                        _buildJobTypeChart(),
                        const SizedBox(height: 20),

                        // Job Type Comparison
                        ContentAnalyticsBreakdownComparison(
                          title: 'Job Types: All Time vs Selected Period',
                          allTime: _analytics!['jobTypeBreakdown'] as Map<String, dynamic>? ?? {},
                          period: _analytics!['jobTypeBreakdownInPeriod'] as Map<String, dynamic>? ?? {},
                          topCount: 10,
                        ),
                        const SizedBox(height: 20),

                        // Location Breakdown
                        _buildLocationChart(),
                        const SizedBox(height: 20),

                        // Location Comparison
                        ContentAnalyticsBreakdownComparison(
                          title: 'Top Locations: All Time vs Selected Period',
                          allTime: _analytics!['locationBreakdown'] as Map<String, dynamic>? ?? {},
                          period: _analytics!['locationBreakdownInPeriod'] as Map<String, dynamic>? ?? {},
                        ),
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
                    child: ContentAnalyticsBudgetCard(
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
                    child: ContentAnalyticsBudgetCard(
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
            const ContentAnalyticsComparisonHeader(),
            if (allTimeMin != null || periodMin != null)
              ContentAnalyticsComparisonRow(
                label: 'Average Min Budget',
                allTimeValue: allTimeMin != null ? 'RM ${allTimeMin.toStringAsFixed(2)}' : 'N/A',
                periodValue: periodMin != null ? 'RM ${periodMin.toStringAsFixed(2)}' : 'N/A',
                isString: true,
              ),
            if (allTimeMax != null || periodMax != null)
              ContentAnalyticsComparisonRow(
                label: 'Average Max Budget',
                allTimeValue: allTimeMax != null ? 'RM ${allTimeMax.toStringAsFixed(2)}' : 'N/A',
                periodValue: periodMax != null ? 'RM ${periodMax.toStringAsFixed(2)}' : 'N/A',
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
            const ContentAnalyticsComparisonHeader(),
            ContentAnalyticsComparisonRow(
              label: 'Approval Rate',
              allTimeValue: '${(analytics['approvalRate'] as double).toStringAsFixed(1)}%',
              periodValue: '${(analytics['approvalRateInPeriod'] as double).toStringAsFixed(1)}%',
              isString: true,
            ),
            ContentAnalyticsComparisonRow(
              label: 'Rejection Rate',
              allTimeValue: '${(analytics['rejectionRate'] as double).toStringAsFixed(1)}%',
              periodValue: '${(analytics['rejectionRateInPeriod'] as double).toStringAsFixed(1)}%',
              isString: true,
            ),
            ContentAnalyticsComparisonRow(
              label: 'Active Posts',
              allTimeValue: analytics['active'],
              periodValue: analytics['activeInPeriod'],
            ),
            ContentAnalyticsComparisonRow(
              label: 'Pending Posts',
              allTimeValue: analytics['pending'],
              periodValue: analytics['pendingInPeriod'],
            ),
            ContentAnalyticsComparisonRow(
              label: 'Completed Posts',
              allTimeValue: analytics['completed'],
              periodValue: analytics['completedInPeriod'],
            ),
            ContentAnalyticsComparisonRow(
              label: 'Rejected Posts',
              allTimeValue: analytics['rejected'],
              periodValue: analytics['rejectedInPeriod'],
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
