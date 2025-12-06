import 'package:flutter/material.dart';

class ReportInternalNotesSection extends StatelessWidget {
  final TextEditingController notesController;
  final bool isResolved;

  const ReportInternalNotesSection({
    super.key,
    required this.notesController,
    required this.isResolved,
  });

  @override
  Widget build(BuildContext context) {
    if (isResolved) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Internal Notes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  hintText: 'Add internal notes about this report...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.all(16),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
