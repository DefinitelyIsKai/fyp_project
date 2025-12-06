import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final Color? color;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.status,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = color ?? _getStatusColor(status);
    final statusIcon = icon ?? _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      case 'suspended':
        return Colors.red;
      case 'approved':
        return Colors.green;
      case 'reported':
        return Colors.orange;
      case 'resolved':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'active':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'completed':
        return Icons.done_all;
      case 'suspended':
        return Icons.block;
      case 'approved':
        return Icons.check_circle;
      case 'reported':
        return Icons.flag;
      case 'resolved':
        return Icons.check;
      default:
        return Icons.help_outline;
    }
  }
}
