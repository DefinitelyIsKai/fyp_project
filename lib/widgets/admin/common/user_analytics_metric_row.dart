import 'package:flutter/material.dart';
import 'analytics_trend_badge.dart';

class UserAnalyticsMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final double trend;
  final Map<String, String>? subMetrics;

  const UserAnalyticsMetricRow({
    super.key,
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
                if (trend != 0 && value != '0' && !value.startsWith('0 '))
                  AnalyticsTrendBadge(trend: trend),
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

