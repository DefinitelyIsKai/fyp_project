import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:fyp_project/models/analytics_model.dart';
import 'package:fyp_project/services/analytics_service.dart';
import 'package:intl/intl.dart';

class UserAnalyticsPage extends StatefulWidget {
  const UserAnalyticsPage({super.key});

  @override
  State<UserAnalyticsPage> createState() => _UserAnalyticsPageState();
}

class _UserAnalyticsPageState extends State<UserAnalyticsPage> {
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isLoading = true;
  AnalyticsModel? _analytics;
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
          _weeklyAnalytics = weekly;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('User Analytics'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh',
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
                ? const Center(child: CircularProgressIndicator())
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
            child: _QuickStatCard(
              title: 'Total Users',
              value: _analytics!.totalUsers.toString(),
              subtitle: 'All registered',
              color: Colors.blue,
              icon: Icons.people,
              trend: _analytics!.userGrowthRate,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            child: _QuickStatCard(
              title: 'Active Users',
              value: _analytics!.activeUsers.toString(),
              subtitle: 'Currently online',
              color: Colors.green,
              icon: Icons.online_prediction,
              trend: _analytics!.activeUserGrowth,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            child: _QuickStatCard(
              title: 'New Users',
              value: _analytics!.newRegistrations.toString(),
              subtitle: 'This period',
              color: Colors.orange,
              icon: Icons.person_add,
              trend: _analytics!.registrationGrowth,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            child: _QuickStatCard(
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
                  child: _ComparisonItem(
                    label: 'New Users in Period',
                    value: newRegistrations.toString(),
                    percentage: periodPercentage,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ComparisonItem(
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
            _MetricRow(
              label: 'Total Users',
              value: _analytics!.totalUsers.toString(),
              trend: _analytics!.userGrowthRate,
            ),
            _MetricRow(
              label: 'Active Users',
              value: '${_analytics!.activeUsers.toString()} (${_analytics!.activeUserPercentage.toStringAsFixed(1)}%)',
              trend: _analytics!.activeUserGrowth,
              subMetrics: {
                'Inactive': _analytics!.inactiveUsers.toString(),
              },
            ),
            _MetricRow(
              label: 'New Registrations',
              value: _analytics!.newRegistrations.toString(),
              trend: _analytics!.registrationGrowth,
            ),
            _MetricRow(
              label: 'Average Session Duration',
              value: '${_analytics!.avgSessionDuration.toStringAsFixed(1)} min',
              trend: _analytics!.sessionGrowth,
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
            _MetricRow(
              label: 'Engagement Rate',
              value: '${_analytics!.engagementRate.toStringAsFixed(1)}%',
              trend: _analytics!.engagementGrowth,
            ),
            _MetricRow(
              label: 'Profile Views',
              value: _analytics!.profileViews.toString(),
              trend: _analytics!.profileViewGrowth,
            ),
            _MetricRow(
              label: 'Messages Sent',
              value: _analytics!.totalMessages.toString(),
              trend: _analytics!.messageGrowth,
            ),
            _MetricRow(
              label: 'Job Applications',
              value: _analytics!.totalApplications.toString(),
              trend: _analytics!.applicationGrowth,
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
            _MetricRow(
              label: 'Total Reports',
              value: _analytics!.totalReports.toString(),
              trend: _analytics!.reportGrowth,
              subMetrics: {
                'Pending': _analytics!.pendingReports.toString(),
                'Resolved': _analytics!.resolvedReports.toString(),
              },
            ),
            _MetricRow(
              label: 'Reported Messages',
              value: _analytics!.reportedMessages.toString(),
              trend: _analytics!.reportedMessageGrowth,
            ),
            _MetricRow(
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
    required this.trend,
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
                if (trend != 0)
                  _TrendBadge(trend),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
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

// Helper widget for trend badges
class _TrendBadge extends StatelessWidget {
  final double trend;

  const _TrendBadge(this.trend);

  @override
  Widget build(BuildContext context) {
    // Special value -999 indicates "new" data (previous was 0, current > 0)
    const double newDataIndicator = -999.0;
    
    if (trend == newDataIndicator) {
      // Show "New" badge for new data
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.blue[100]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.new_releases,
              size: 12,
              color: Colors.blue[700],
            ),
            const SizedBox(width: 2),
            Text(
              'New',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
      );
    }
    
    // Regular growth/decline badge
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: trend > 0 ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: trend > 0 ? Colors.green[100]! : Colors.red[100]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trend > 0 ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: trend > 0 ? Colors.green[700] : Colors.red[700],
          ),
          const SizedBox(width: 2),
          Text(
            '${trend.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: trend > 0 ? Colors.green[700] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final double trend;
  final Map<String, String>? subMetrics;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.trend,
    this.subMetrics,
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
                  _TrendBadge(trend),
              ],
            ),
          ],
        ),
        if (subMetrics != null && subMetrics!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: subMetrics!.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
    // Extract just the date part (remove time)
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

class ChartData {
  final String label;
  final double value;
  final Color color;

  ChartData(this.label, this.value, [this.color = Colors.blue]);
}
