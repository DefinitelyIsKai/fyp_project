import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:fyp_project/models/admin/analytics_model.dart';
import 'package:fyp_project/services/admin/analytics_service.dart';
import 'package:fyp_project/utils/admin/analytics_formatter.dart';
import 'package:fyp_project/widgets/admin/cards/user_analytics_quick_stat_card.dart';
import 'package:fyp_project/widgets/admin/common/analytics_comparison_item.dart';
import 'package:fyp_project/widgets/admin/common/user_analytics_metric_row.dart';
import 'package:fyp_project/widgets/admin/dialogs/date_range_picker_dialog.dart' as custom;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:fyp_project/utils/admin/app_colors.dart';

class UserAnalyticsPage extends StatefulWidget {
  const UserAnalyticsPage({super.key});

  @override
  State<UserAnalyticsPage> createState() => _UserAnalyticsPageState();
}

class _UserAnalyticsPageState extends State<UserAnalyticsPage> {
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isLoading = true;
  AnalyticsModel? _analytics;
  AnalyticsModel? _allTimeAnalytics;
  List<AnalyticsModel> _weeklyAnalytics = [];
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
      // Use the selected date range for analytics
      final analytics = await _analyticsService.getAnalyticsForRange(_startDate, _endDate);
      
      // Get all-time analytics (from beginning to end date)
      final allTimeAnalytics = await _analyticsService.getAnalyticsForRange(
        DateTime(2020, 1, 1),
        _endDate,
      );
      
      // Load data for charts - use the selected date range
      List<AnalyticsModel> weekly = [];
      final daysDiff = _endDate.difference(_startDate).inDays;
      final daysToLoad = daysDiff > 7 ? 7 : daysDiff;
      
      // Calculate step size to evenly distribute points across the range
      final step = daysDiff > 0 ? daysDiff / daysToLoad : 1;
      
      for (int i = 0; i <= daysToLoad; i++) {
        final dayOffset = (step * i).round();
        final day = _startDate.add(Duration(days: dayOffset));
        if (day.isBefore(_endDate.add(const Duration(days: 1)))) {
          // Get analytics for this specific day
          final dayStart = DateTime(day.year, day.month, day.day);
          final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);
          weekly.add(await _analyticsService.getAnalyticsForRange(dayStart, dayEnd));
        }
      }

      if (mounted) {
        setState(() {
          _analytics = analytics;
          _allTimeAnalytics = allTimeAnalytics;
          _weeklyAnalytics = weekly;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading analytics: $e', isError: true);
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



  Future<void> _downloadPDF() async {
    if (_analytics == null || _allTimeAnalytics == null) return;

    try {
      final pdf = pw.Document();
      final analytics = _analytics!;
      final allTime = _allTimeAnalytics!;

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
                    'User Analytics Report',
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
                      '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
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
                  ['Total Users', allTime.totalUsers.toString(), analytics.totalUsers.toString()],
                  ['Active Users', allTime.activeUsers.toString(), analytics.activeUsers.toString()],
                  ['Inactive Users', allTime.inactiveUsers.toString(), analytics.inactiveUsers.toString()],
                  ['New Registrations', allTime.newRegistrations.toString(), analytics.newRegistrations.toString()],
                ],
              ),
              pw.SizedBox(height: 20),

              // User Engagement
              pw.Text(
                'User Engagement',
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
                  ['Engagement Rate', '${AnalyticsFormatter.capEngagementRate(allTime.engagementRate).toStringAsFixed(1)}%', '${AnalyticsFormatter.capEngagementRate(analytics.engagementRate).toStringAsFixed(1)}%'],
                  ['Job Applications', allTime.totalApplications.toString(), analytics.totalApplications.toString()],
                  ['Messages Sent', allTime.totalMessages.toString(), analytics.totalMessages.toString()],
                ],
              ),
              pw.SizedBox(height: 20),

              // User Reports & Moderation
              pw.Text(
                'User Reports & Moderation',
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
                  ['Total Reports', allTime.totalReports.toString(), analytics.totalReports.toString()],
                  ['Pending Reports', allTime.pendingReports.toString(), analytics.pendingReports.toString()],
                  ['Resolved Reports', allTime.resolvedReports.toString(), analytics.resolvedReports.toString()],
                  ['Dismissed Reports', allTime.dismissedReports.toString(), analytics.dismissedReports.toString()],
                  ['Report Resolution Rate', '${allTime.reportResolutionRate.toStringAsFixed(1)}%', '${analytics.reportResolutionRate.toStringAsFixed(1)}%'],
                ],
              ),
              pw.SizedBox(height: 20),

              // Growth Rates
              pw.Text(
                'Growth Rates',
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
                headers: ['Metric', 'Growth Rate'],
                data: [
                  ['User Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.userGrowthRate, 'userGrowth', analytics)],
                  ['Active User Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.activeUserGrowth, 'activeUserGrowth', analytics)],
                  ['Registration Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.registrationGrowth, 'registrationGrowth', analytics)],
                  ['Engagement Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.engagementGrowth, 'engagementGrowth', analytics)],
                  ['Message Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.messageGrowth, 'messageGrowth', analytics)],
                  ['Application Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.applicationGrowth, 'applicationGrowth', analytics)],
                  ['Report Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.reportGrowth, 'reportGrowth', analytics)],
                ],
              ),
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
    if (_analytics == null || _allTimeAnalytics == null) return;

    try {
      final pdf = pw.Document();
      final analytics = _analytics!;
      final allTime = _allTimeAnalytics!;

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
                    'User Analytics Report',
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
                      '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
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
                  ['Total Users', allTime.totalUsers.toString(), analytics.totalUsers.toString()],
                  ['Active Users', allTime.activeUsers.toString(), analytics.activeUsers.toString()],
                  ['Inactive Users', allTime.inactiveUsers.toString(), analytics.inactiveUsers.toString()],
                  ['New Registrations', allTime.newRegistrations.toString(), analytics.newRegistrations.toString()],
                ],
              ),
              pw.SizedBox(height: 20),

              // User Engagement
              pw.Text(
                'User Engagement',
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
                  ['Engagement Rate', '${AnalyticsFormatter.capEngagementRate(allTime.engagementRate).toStringAsFixed(1)}%', '${AnalyticsFormatter.capEngagementRate(analytics.engagementRate).toStringAsFixed(1)}%'],
                  ['Job Applications', allTime.totalApplications.toString(), analytics.totalApplications.toString()],
                  ['Messages Sent', allTime.totalMessages.toString(), analytics.totalMessages.toString()],
                ],
              ),
              pw.SizedBox(height: 20),

              // User Reports & Moderation
              pw.Text(
                'User Reports & Moderation',
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
                  ['Total Reports', allTime.totalReports.toString(), analytics.totalReports.toString()],
                  ['Pending Reports', allTime.pendingReports.toString(), analytics.pendingReports.toString()],
                  ['Resolved Reports', allTime.resolvedReports.toString(), analytics.resolvedReports.toString()],
                  ['Dismissed Reports', allTime.dismissedReports.toString(), analytics.dismissedReports.toString()],
                  ['Report Resolution Rate', '${allTime.reportResolutionRate.toStringAsFixed(1)}%', '${analytics.reportResolutionRate.toStringAsFixed(1)}%'],
                ],
              ),
              pw.SizedBox(height: 20),

              // Growth Rates
              pw.Text(
                'Growth Rates',
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
                headers: ['Metric', 'Growth Rate'],
                data: [
                  ['User Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.userGrowthRate, 'userGrowth', analytics)],
                  ['Active User Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.activeUserGrowth, 'activeUserGrowth', analytics)],
                  ['Registration Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.registrationGrowth, 'registrationGrowth', analytics)],
                  ['Engagement Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.engagementGrowth, 'engagementGrowth', analytics)],
                  ['Message Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.messageGrowth, 'messageGrowth', analytics)],
                  ['Application Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.applicationGrowth, 'applicationGrowth', analytics)],
                  ['Report Growth', AnalyticsFormatter.formatGrowthRateForPDF(analytics.reportGrowth, 'reportGrowth', analytics)],
                ],
              ),
            ];
          },
        ),
      );

      // Save PDF to temporary file and share
      final bytes = await pdf.save();
      final directory = await getTemporaryDirectory();
      final fileName = 'User_Analytics_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // Share the file
      try {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'User Analytics Report',
          subject: 'User Analytics Report - ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
        );

        // Clean up temporary file after a delay (to allow sharing to complete)
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('User Analytics'),
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
                  'User Analytics & Insights',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track user growth, engagement, and activity patterns',
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
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Loading analytics...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please wait a moment',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quick Stats Row
                            _buildQuickStats(),
                            const SizedBox(height: 20),

                            // Period Overview
                            _buildPeriodOverview(),
                            const SizedBox(height: 20),

                            // User Activity Charts
                            _buildChartsSection(),
                            const SizedBox(height: 20),

                            // User Statistics Section
                            _buildUserStatisticsSection(),
                            const SizedBox(height: 20),

                            // User Engagement Section
                            _buildUserEngagementSection(),
                            const SizedBox(height: 20),

                            // User Reports Section
                            _buildUserReportsSection(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            child: UserAnalyticsQuickStatCard(
              title: 'Total Users',
              value: _analytics!.totalUsers.toString(),
              subtitle: 'All registered',
              color: Colors.blue,
              icon: Icons.people,
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.userGrowthRate),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            child: UserAnalyticsQuickStatCard(
              title: 'Active Users',
              value: _analytics!.activeUsers.toString(),
              subtitle: 'Currently online',
              color: Colors.green,
              icon: Icons.online_prediction,
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.activeUserGrowth),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            child: UserAnalyticsQuickStatCard(
              title: 'New Users',
              value: _analytics!.newRegistrations.toString(),
              subtitle: 'This period',
              color: Colors.orange,
              icon: Icons.person_add,
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.registrationGrowth),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            child: UserAnalyticsQuickStatCard(
              title: 'Inactive Users',
              value: _analytics!.inactiveUsers.toString(),
              subtitle: 'Not active',
              color: Colors.grey,
              icon: Icons.person_off,
              trend: 0.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodOverview() {
    final totalUsers = _analytics!.totalUsers;
    final newRegistrations = _analytics!.newRegistrations;
    final periodPercentage = totalUsers > 0 ? (newRegistrations / totalUsers * 100) : 0.0;

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
                  child: AnalyticsComparisonItem(
                    label: 'New Users in Period',
                    value: newRegistrations.toString(),
                    percentage: periodPercentage,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnalyticsComparisonItem(
                    label: 'Total Users (All Time)',
                    value: totalUsers.toString(),
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

  Widget _buildUserStatisticsSection() {
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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.people_alt, size: 24, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Text(
                  'User Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            UserAnalyticsMetricRow(
              label: 'Total Users',
              value: _analytics!.totalUsers.toString(),
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.userGrowthRate),
            ),
            UserAnalyticsMetricRow(
              label: 'Active Users',
              value: '${_analytics!.activeUsers.toString()} (${_analytics!.activeUserPercentage.toStringAsFixed(1)}%)',
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.activeUserGrowth),
              subMetrics: {
                'Inactive': _analytics!.inactiveUsers.toString(),
              },
            ),
            UserAnalyticsMetricRow(
              label: 'New Registrations',
              value: _analytics!.newRegistrations.toString(),
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.registrationGrowth),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserEngagementSection() {
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
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.trending_up, size: 24, color: Colors.green),
                ),
                const SizedBox(width: 12),
                const Text(
                  'User Engagement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            UserAnalyticsMetricRow(
              label: 'Engagement Rate',
              value: '${AnalyticsFormatter.capEngagementRate(_analytics!.engagementRate).toStringAsFixed(1)}%',
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.engagementGrowth),
            ),
            UserAnalyticsMetricRow(
              label: 'Messages Sent',
              value: _analytics!.totalMessages.toString(),
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.messageGrowth),
            ),
            UserAnalyticsMetricRow(
              label: 'Job Applications',
              value: _analytics!.totalApplications.toString(),
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.applicationGrowth),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection() {
    return Column(
      children: [
        // Line Chart
        _buildLineChart(),
        const SizedBox(height: 16),
        // Pie Chart
        _buildPieChart(),
      ],
    );
  }

  Widget _buildLineChart() {
    if (_weeklyAnalytics.isEmpty) return _buildEmptyChart('No chart data available');

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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.show_chart, size: 24, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Text(
                  'User Growth Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  labelRotation: 45,
                  majorGridLines: const MajorGridLines(width: 0),
                  labelStyle: const TextStyle(fontSize: 12),
                ),
                primaryYAxis: NumericAxis(
                  minimum: 0,
                  majorGridLines: const MajorGridLines(width: 0.5, color: Colors.grey),
                  labelStyle: const TextStyle(fontSize: 12),
                ),
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  header: '',
                  format: 'point.x\npoint.y users',
                ),
                series: <CartesianSeries<AnalyticsModel, String>>[
                  LineSeries<AnalyticsModel, String>(
                    name: 'Total Users',
                    dataSource: _weeklyAnalytics,
                    xValueMapper: (model, _) => DateFormat('MMM dd').format(model.date),
                    yValueMapper: (model, _) => model.totalUsers,
                    markerSettings: const MarkerSettings(isVisible: true, height: 6, width: 6),
                    color: Colors.blue,
                    width: 3,
                  ),
                  LineSeries<AnalyticsModel, String>(
                    name: 'Active Users',
                    dataSource: _weeklyAnalytics,
                    xValueMapper: (model, _) => DateFormat('MMM dd').format(model.date),
                    yValueMapper: (model, _) => model.activeUsers,
                    markerSettings: const MarkerSettings(isVisible: true, height: 6, width: 6),
                    color: Colors.green,
                    width: 3,
                  ),
                  LineSeries<AnalyticsModel, String>(
                    name: 'New Registrations',
                    dataSource: _weeklyAnalytics,
                    xValueMapper: (model, _) => DateFormat('MMM dd').format(model.date),
                    yValueMapper: (model, _) => model.newRegistrations,
                    markerSettings: const MarkerSettings(isVisible: true, height: 6, width: 6),
                    color: Colors.orange,
                    width: 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    if (_analytics == null) return _buildEmptyChart('No data available');

    final active = _analytics!.activeUsers.toDouble();
    final inactive = _analytics!.inactiveUsers.toDouble();
    final total = _analytics!.totalUsers.toDouble();

    if (total == 0) return _buildEmptyChart('No user data');

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
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.pie_chart, size: 24, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Text(
                  'User Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: SfCircularChart(
                legend: Legend(
                  isVisible: true,
                  position: LegendPosition.bottom,
                  overflowMode: LegendItemOverflowMode.wrap,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'point.x : point.y%',
                ),
                series: <CircularSeries>[
                  DoughnutSeries<ChartData, String>(
                    dataSource: [
                      ChartData('Active Users', active, Colors.green),
                      ChartData('Inactive Users', inactive, Colors.orange),
                    ],
                    xValueMapper: (data, _) => data.label,
                    yValueMapper: (data, _) => data.value,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.outside,
                      textStyle: TextStyle(fontSize: 12),
                    ),
                    radius: '70%',
                    innerRadius: '60%',
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatInfo('Active', '${((active / total) * 100).toStringAsFixed(1)}%', Colors.green),
                  _buildStatInfo('Inactive', '${((inactive / total) * 100).toStringAsFixed(1)}%', Colors.orange),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatInfo(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildUserReportsSection() {
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
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.flag, size: 24, color: Colors.red),
                ),
                const SizedBox(width: 12),
                const Text(
                  'User Reports & Moderation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            UserAnalyticsMetricRow(
              label: 'Total Reports',
              value: _analytics!.totalReports.toString(),
              trend: AnalyticsFormatter.capGrowthRate(_analytics!.reportGrowth),
              subMetrics: {
                'Pending': _analytics!.pendingReports.toString(),
                'Resolved': _analytics!.resolvedReports.toString(),
                'Dismissed': _analytics!.dismissedReports.toString(),
              },
            ),
            UserAnalyticsMetricRow(
              label: 'Report Resolution Rate',
              value: '${_analytics!.reportResolutionRate.toStringAsFixed(1)}%',
              trend: 0.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                ),
              ),
            ],
          ),
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
            Icons.people_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No User Analytics Data',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'User analytics data will appear here once available',
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

// Helper Widgets

class ChartData {
  final String label;
  final double value;
  final Color color;

  ChartData(this.label, this.value, [this.color = Colors.blue]);
}
