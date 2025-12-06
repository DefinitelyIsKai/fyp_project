import 'package:flutter/material.dart';
import 'package:fyp_project/widgets/admin/common/analytics_comparison_item.dart';

class ContentAnalyticsComparisonHeader extends StatelessWidget {
  const ContentAnalyticsComparisonHeader({super.key});

  @override
  Widget build(BuildContext context) {
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
}

class ContentAnalyticsComparisonRow extends StatelessWidget {
  final String label;
  final dynamic allTimeValue;
  final dynamic periodValue;
  final bool isString;

  const ContentAnalyticsComparisonRow({
    super.key,
    required this.label,
    required this.allTimeValue,
    required this.periodValue,
    this.isString = false,
  });

  @override
  Widget build(BuildContext context) {
    final allTimeStr = allTimeValue.toString();
    final periodStr = periodValue.toString();
    
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
            child: Text(
              allTimeStr,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              periodStr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class ContentAnalyticsPeriodComparison extends StatelessWidget {
  final int totalPosts;
  final int postsInPeriod;

  const ContentAnalyticsPeriodComparison({
    super.key,
    required this.totalPosts,
    required this.postsInPeriod,
  });

  @override
  Widget build(BuildContext context) {
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
                  child: AnalyticsComparisonItem(
                    label: 'Posts in Selected Period',
                    value: postsInPeriod.toString(),
                    percentage: periodPercentage,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AnalyticsComparisonItem(
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
}

class ContentAnalyticsBreakdownComparison extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Map<String, dynamic> allTime;
  final Map<String, dynamic> period;
  final int topCount;

  const ContentAnalyticsBreakdownComparison({
    super.key,
    required this.title,
    this.subtitle,
    required this.allTime,
    required this.period,
    this.topCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (allTime.isEmpty && period.isEmpty) {
      return const SizedBox.shrink();
    }

    final allTimeTop = allTime.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    final periodTop = period.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    final allKeys = {...allTimeTop.take(topCount).map((e) => e.key), ...periodTop.take(topCount).map((e) => e.key)};

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 16),
            const ContentAnalyticsComparisonHeader(),
            ...allKeys.take(topCount).map((key) => ContentAnalyticsComparisonRow(
              label: key,
              allTimeValue: allTime[key] ?? 0,
              periodValue: period[key] ?? 0,
            )),
          ],
        ),
      ),
    );
  }
}

class ContentAnalyticsStatusComparison extends StatelessWidget {
  final Map<String, dynamic> analytics;

  const ContentAnalyticsStatusComparison({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
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
            const ContentAnalyticsComparisonHeader(),
            ContentAnalyticsComparisonRow(
              label: 'Active',
              allTimeValue: analytics['active'],
              periodValue: analytics['activeInPeriod'],
            ),
            ContentAnalyticsComparisonRow(
              label: 'Pending',
              allTimeValue: analytics['pending'],
              periodValue: analytics['pendingInPeriod'],
            ),
            ContentAnalyticsComparisonRow(
              label: 'Completed',
              allTimeValue: analytics['completed'],
              periodValue: analytics['completedInPeriod'],
            ),
            ContentAnalyticsComparisonRow(
              label: 'Rejected',
              allTimeValue: analytics['rejected'],
              periodValue: analytics['rejectedInPeriod'],
            ),
          ],
        ),
      ),
    );
  }
}
