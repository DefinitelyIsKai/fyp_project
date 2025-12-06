import 'package:flutter/material.dart';

class DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? helperText;
  final bool required;

  const DatePickerField({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
    required this.firstDate,
    required this.lastDate,
    this.helperText,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            //ensure initial date no before firstdate
            final DateTime initialDate;
            if (selectedDate != null && !selectedDate!.isBefore(firstDate)) {
              initialDate = selectedDate!;
            } else {
              initialDate = firstDate;
            }
            
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: firstDate,
              lastDate: lastDate,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF00C8A0),
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              onDateSelected(picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey[400]!,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                        : 'Select date',
                    style: TextStyle(
                      color: selectedDate != null ? Colors.black : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

