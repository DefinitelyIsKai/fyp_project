import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:fyp_project/models/admin/analytics_model.dart';

class AnalyticsTrendCharts extends StatelessWidget {
  final List<AnalyticsModel> trendData;

  const AnalyticsTrendCharts({
    super.key,
    required this.trendData,
  });

  @override
  Widget build(BuildContext context) {
    if (trendData.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        
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
                        dataSource: trendData,
                        xValueMapper: (model, _) => DateFormat('MMM dd').format(model.date),
                        yValueMapper: (model, _) => model.totalUsers,
                        color: Colors.blue,
                        width: 3,
                        markerSettings: const MarkerSettings(isVisible: true),
                      ),
                      LineSeries<AnalyticsModel, String>(
                        name: 'Active Users',
                        dataSource: trendData,
                        xValueMapper: (model, _) => DateFormat('MMM dd').format(model.date),
                        yValueMapper: (model, _) => model.activeUsers,
                        color: Colors.green,
                        width: 3,
                        markerSettings: const MarkerSettings(isVisible: true),
                      ),
                      LineSeries<AnalyticsModel, String>(
                        name: 'New Registrations',
                        dataSource: trendData,
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
                      labelRotation: trendData.length > 7 ? -45 : 0,
                      majorGridLines: const MajorGridLines(width: 0),
                    ),
                    primaryYAxis: NumericAxis(),
                    tooltipBehavior: TooltipBehavior(enable: true),
                    series: <CartesianSeries<AnalyticsModel, String>>[
                      LineSeries<AnalyticsModel, String>(
                        name: 'Job Posts',
                        dataSource: trendData,
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
                    primaryYAxis: NumericAxis(
                      numberFormat: NumberFormat('#'),
                      interval: 1,
                    ),
                    legend: Legend(
                      isVisible: true,
                      position: LegendPosition.bottom,
                    ),
                    tooltipBehavior: TooltipBehavior(enable: true),
                    series: <CartesianSeries<AnalyticsModel, String>>[
                      LineSeries<AnalyticsModel, String>(
                        name: 'Total Reports',
                        dataSource: trendData,
                        xValueMapper: (model, _) => DateFormat('MMM dd').format(model.date),
                        yValueMapper: (model, _) => model.totalReports,
                        color: Colors.red,
                        width: 3,
                        markerSettings: const MarkerSettings(isVisible: true),
                      ),
                      LineSeries<AnalyticsModel, String>(
                        name: 'Pending Reports',
                        dataSource: trendData,
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
}
