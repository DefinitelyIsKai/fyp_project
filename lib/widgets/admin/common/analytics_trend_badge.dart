import 'package:flutter/material.dart';

class AnalyticsTrendBadge extends StatelessWidget {
  final double trend;

  const AnalyticsTrendBadge({
    super.key,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    const double newDataIndicator = -999.0;
    
    if (trend == newDataIndicator) {
      return const SizedBox.shrink();
    }
    
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

