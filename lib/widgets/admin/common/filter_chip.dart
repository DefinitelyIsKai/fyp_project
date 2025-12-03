import 'package:flutter/material.dart';

class AdminFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final String? inactiveValue; 

  const AdminFilterChip({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.inactiveValue,
  });

  @override
  Widget build(BuildContext context) {
    final defaultInactive = inactiveValue ?? 'All';
    final isActive = value != defaultInactive && 
                     value != 'All Actions' && 
                     value != 'All Dates' &&
                     value != 'All Categories';
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.blue[300]! : Colors.grey[300]!,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.blue[700] : Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isActive ? Colors.blue[700] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}
