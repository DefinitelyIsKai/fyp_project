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

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now();
      final todayData = await _analyticsService.getAnalytics(today);

      List<AnalyticsModel> weekly = [];
      for (int i = 6; i >= 0; i--) {
        final day = today.subtract(Duration(days: i));
        weekly.add(await _analyticsService.getAnalytics(day));
      }

      setState(() {
        _todayAnalytics = todayData;
        _weeklyAnalytics = weekly;
      });
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

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    if (_weeklyAnalytics.isEmpty) return const SizedBox();

    return SizedBox(
      height: 250,
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(
          labelRotation: 45,
          majorGridLines: const MajorGridLines(width: 0),
        ),
        primaryYAxis: NumericAxis(
          minimum: 0,
          majorGridLines: const MajorGridLines(width: 0.5),
        ),
        legend: Legend(isVisible: true),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<AnalyticsModel, String>>[
          LineSeries<AnalyticsModel, String>(
            name: 'Total Users',
            dataSource: _weeklyAnalytics,
            xValueMapper: (model, _) => DateFormat('E').format(model.date),
            yValueMapper: (model, _) => model.totalUsers,
            markerSettings: const MarkerSettings(isVisible: true),
            color: Colors.blue,
          ),
          LineSeries<AnalyticsModel, String>(
            name: 'Active Users',
            dataSource: _weeklyAnalytics,
            xValueMapper: (model, _) => DateFormat('E').format(model.date),
            yValueMapper: (model, _) => model.activeUsers,
            markerSettings: const MarkerSettings(isVisible: true),
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    if (_todayAnalytics == null) return const SizedBox();
    final active = _todayAnalytics!.activeUsers.toDouble();
    final inactive = (_todayAnalytics!.totalUsers - _todayAnalytics!.activeUsers).toDouble();

    return SizedBox(
      height: 200,
      child: SfCircularChart(
        legend: Legend(isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CircularSeries>[
          PieSeries<ChartData, String>(
            dataSource: [
              ChartData('Active', active),
              ChartData('Inactive', inactive),
            ],
            xValueMapper: (data, _) => data.label,
            yValueMapper: (data, _) => data.value,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
            explode: true,
            explodeIndex: 0,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Analytics'),
        backgroundColor: Colors.purple[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatCard('Total Users', '${_todayAnalytics?.totalUsers ?? 0}', Colors.blue),
                _buildStatCard('Active Users', '${_todayAnalytics?.activeUsers ?? 0}', Colors.green),
              ],
            ),
            Row(
              children: [
                _buildStatCard('Reported Users', '${_todayAnalytics?.totalReports ?? 0}', Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            const Text('User Growth (Last 7 Days)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildLineChart(),
            const SizedBox(height: 16),
            const Text('Active vs Inactive Users', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildPieChart(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final result = await _analyticsService.generateReport(
                  DateTime.now().subtract(const Duration(days: 7)),
                  DateTime.now(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700]),
              child: const Text('Generate Report'),
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
  ChartData(this.label, this.value);
}
