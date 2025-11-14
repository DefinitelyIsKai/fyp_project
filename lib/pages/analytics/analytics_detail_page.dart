import 'package:flutter/material.dart';
import 'package:fyp_project/models/analytics_model.dart';

class AnalyticsDetailPage extends StatelessWidget {
  final AnalyticsModel analytics;

  const AnalyticsDetailPage({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detailed Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Usage Statistics',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _MetricCard(
              title: 'User Statistics',
              metrics: {
                'Total Users': analytics.totalUsers,
                'Active Users': analytics.activeUsers,
              },
            ),
            const SizedBox(height: 16),
            _MetricCard(
              title: 'Job Post Statistics',
              metrics: {
                'Total Job Posts': analytics.totalJobPosts,
                'Pending Job Posts': analytics.pendingJobPosts,
                'Approved Job Posts': analytics.approvedJobPosts,
              },
            ),
            const SizedBox(height: 16),
            _MetricCard(
              title: 'Application Statistics',
              metrics: {
                'Total Applications': analytics.totalApplications,
              },
            ),
            const SizedBox(height: 16),
            _MetricCard(
              title: 'Report Statistics',
              metrics: {
                'Total Reports': analytics.totalReports,
                'Pending Reports': analytics.pendingReports,
              },
            ),
            const SizedBox(height: 16),
            _MetricCard(
              title: 'Message Statistics',
              metrics: {
                'Total Messages': analytics.totalMessages,
                'Reported Messages': analytics.reportedMessages,
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Generate and export report
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report generation feature coming soon')),
                );
              },
              child: const Text('Generate Summary Report'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final Map<String, int> metrics;

  const _MetricCard({required this.title, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...metrics.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

