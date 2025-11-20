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
  AnalyticsModel? _todayAnalytics;
  List<AnalyticsModel> _weeklyAnalytics = [];
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
      final today = DateTime.now();
      // Use comprehensive analytics for richer data
      final todayData = await _analyticsService.getComprehensiveAnalytics(today);

      List<AnalyticsModel> weekly = [];
      for (int i = 6; i >= 0; i--) {
        final day = today.subtract(Duration(days: i));
        weekly.add(await _analyticsService.getComprehensiveAnalytics(day));
      }

      setState(() {
        _todayAnalytics = todayData;
        _weeklyAnalytics = weekly;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading analytics: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
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

  Widget _buildStatCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.all(6),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrowthIndicator(double growth, {bool isPositiveGood = true}) {
    final isPositive = growth > 0;
    final color = isPositiveGood ? (isPositive ? Colors.green : Colors.red) : (isPositive ? Colors.red : Colors.green);
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${growth.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    if (_weeklyAnalytics.isEmpty) return _buildEmptyChart('No data available');

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SfCartesianChart(
            title: ChartTitle(text: 'User Growth Trend'),
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
      ),
    );
  }

  Widget _buildPieChart() {
    if (_todayAnalytics == null) return _buildEmptyChart('No data available');

    final active = _todayAnalytics!.activeUsers.toDouble();
    final inactive = (_todayAnalytics!.totalUsers - _todayAnalytics!.activeUsers).toDouble();
    final total = _todayAnalytics!.totalUsers.toDouble();

    if (total == 0) return _buildEmptyChart('No user data');

    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'User Distribution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
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

  Widget _buildEmptyChart(String message) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Widget _buildEngagementMetrics() {
    if (_todayAnalytics == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Engagement Metrics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Engagement Rate',
                      '${_todayAnalytics!.engagementRate.toStringAsFixed(1)}%',
                      Icons.trending_up,
                      Colors.purple,
                      _todayAnalytics!.engagementGrowth,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'New Users',
                      _todayAnalytics!.newRegistrations.toString(),
                      Icons.person_add,
                      Colors.blue,
                      _todayAnalytics!.registrationGrowth,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Active Rate',
                      '${_todayAnalytics!.activeUserPercentage.toStringAsFixed(1)}%',
                      Icons.online_prediction,
                      Colors.green,
                      _todayAnalytics!.activeUserGrowth,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Reports',
                      _todayAnalytics!.totalReports.toString(),
                      Icons.flag,
                      Colors.orange,
                      _todayAnalytics!.reportGrowth,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(String title, String value, IconData icon, Color color, double growth) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              _buildGrowthIndicator(growth),
            ],
          ),
          const SizedBox(height: 8),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'User Analytics Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.purple[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadAnalytics,
        color: Colors.purple[700],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Users',
                      '${_todayAnalytics?.totalUsers ?? 0}',
                      'All registered users',
                      Colors.blue,
                      Icons.people,
                    ),
                  ),
                  Expanded(
                    child: _buildStatCard(
                      'Active Users',
                      '${_todayAnalytics?.activeUsers ?? 0}',
                      'Currently online',
                      Colors.green,
                      Icons.online_prediction,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'New Registrations',
                      '${_todayAnalytics?.newRegistrations ?? 0}',
                      'This period',
                      Colors.orange,
                      Icons.person_add,
                    ),
                  ),
                  Expanded(
                    child: _buildStatCard(
                      'Reported Users',
                      '${_todayAnalytics?.totalReports ?? 0}',
                      'Total reports',
                      Colors.red,
                      Icons.flag,
                    ),
                  ),
                ],
              ),

              // Engagement Metrics
              _buildEngagementMetrics(),

              // Charts
              _buildLineChart(),
              _buildPieChart(),

              // Action Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await _analyticsService.generateComprehensiveReport(
                        DateTime.now().subtract(const Duration(days: 7)),
                        DateTime.now(),
                      );
                      if (mounted) {
                        _showSnackBar('Report generated successfully!');
                        // You could also show a dialog with the report
                        print(result); // For now, just print to console
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.analytics),
                    label: const Text(
                      'Generate Comprehensive Report',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
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