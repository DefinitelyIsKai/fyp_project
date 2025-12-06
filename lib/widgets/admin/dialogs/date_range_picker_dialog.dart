import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fyp_project/utils/admin/snackbar_utils.dart';

class DateRangePickerDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const DateRangePickerDialog({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<DateRangePickerDialog> createState() => _DateRangePickerDialogState();

  static Future<Map<String, DateTime>?> show(
    BuildContext context, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (context) => DateRangePickerDialog(
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }
}

class _DateRangePickerDialogState extends State<DateRangePickerDialog> {
  late DateTime _tempStartDate;
  late DateTime _tempEndDate;

  @override
  void initState() {
    super.initState();
    
    _tempStartDate = DateTime(
      widget.startDate.year,
      widget.startDate.month,
      widget.startDate.day,
    );
    _tempEndDate = DateTime(
      widget.endDate.year,
      widget.endDate.month,
      widget.endDate.day,
    );
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempStartDate,
      firstDate: DateTime(2020),
      lastDate: _tempEndDate,
    );
    if (picked != null) {
      setState(() {
        _tempStartDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempEndDate,
      firstDate: _tempStartDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _tempEndDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Date Range'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            
            const Text(
              'Start Date',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectStartDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(_tempStartDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Icon(Icons.calendar_today, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'End Date',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectEndDate,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format(_tempEndDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Icon(Icons.calendar_today, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Quick Presets',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickDateButton(
                  label: 'Today',
                  onTap: () {
                    final now = DateTime.now();
                    setState(() {
                      _tempStartDate = DateTime(now.year, now.month, now.day);
                      _tempEndDate = DateTime(now.year, now.month, now.day);
                    });
                  },
                ),
                _QuickDateButton(
                  label: 'Last 7 Days',
                  onTap: () {
                    final now = DateTime.now();
                    final startDate = now.subtract(const Duration(days: 7));
                    setState(() {
                      _tempStartDate = DateTime(
                        startDate.year,
                        startDate.month,
                        startDate.day,
                      );
                      _tempEndDate = DateTime(now.year, now.month, now.day);
                    });
                  },
                ),
                _QuickDateButton(
                  label: 'Last 30 Days',
                  onTap: () {
                    final now = DateTime.now();
                    final startDate = now.subtract(const Duration(days: 30));
                    setState(() {
                      _tempStartDate = DateTime(
                        startDate.year,
                        startDate.month,
                        startDate.day,
                      );
                      _tempEndDate = DateTime(now.year, now.month, now.day);
                    });
                  },
                ),
                _QuickDateButton(
                  label: 'This Month',
                  onTap: () {
                    final now = DateTime.now();
                    setState(() {
                      _tempStartDate = DateTime(now.year, now.month, 1);
                      _tempEndDate = DateTime(now.year, now.month, now.day);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_tempStartDate.isAfter(_tempEndDate)) {
              SnackbarUtils.showError(
                context,
                'Start date must be before end date',
              );
              return;
            }
            Navigator.pop(context, {
              'start': _tempStartDate,
              'end': _tempEndDate,
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _QuickDateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickDateButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
