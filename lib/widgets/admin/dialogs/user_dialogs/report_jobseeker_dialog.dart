import 'package:flutter/material.dart';
import '../../../../utils/user/button_styles.dart';
import '../../../../services/user/report_service.dart';
import '../../../../models/admin/report_category_model.dart';

class ReportJobseekerDialog extends StatefulWidget {
  final String jobseekerName;

  const ReportJobseekerDialog({
    super.key,
    required this.jobseekerName,
  });

  @override
  State<ReportJobseekerDialog> createState() => _ReportJobseekerDialogState();
}

class _ReportJobseekerDialogState extends State<ReportJobseekerDialog> {
  String _selectedReason = '';
  String? _customReason;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customReasonController = TextEditingController();
  final ReportService _reportService = ReportService();
  List<ReportCategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      
      final categories = await _reportService.getReportCategoriesByUserRole();
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading report categories: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF00C8A0);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.report_problem,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report Jobseeker',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.jobseekerName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 20,
                      color: Colors.black54,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Reason for reporting:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              ...[
                
                if (_categories.isNotEmpty)
                  ..._categories.map((category) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _selectedReason == category.name
                          ? Colors.red.withOpacity(0.05)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedReason == category.name
                            ? Colors.red
                            : Colors.grey[300]!,
                        width: _selectedReason == category.name ? 2 : 1,
                      ),
                    ),
                    child: RadioListTile<String>(
                      title: Text(
                        category.name,
                        style: TextStyle(
                          fontWeight: _selectedReason == category.name
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedReason == category.name
                              ? Colors.red[700]
                              : Colors.black87,
                        ),
                      ),
                      subtitle: category.description.isNotEmpty
                          ? Text(
                              category.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            )
                          : null,
                      value: category.name,
                      groupValue: _selectedReason,
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() {
                          _selectedReason = value ?? '';
                          _customReason = null;
                          _customReasonController.clear();
                        });
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                  );
                  }),
                
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: _selectedReason == 'Other'
                        ? Colors.red.withOpacity(0.05)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedReason == 'Other'
                          ? Colors.red
                          : Colors.grey[300]!,
                      width: _selectedReason == 'Other' ? 2 : 1,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: const Text(
                      'Other',
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        color: Colors.black87,
                      ),
                    ),
                    value: 'Other',
                    groupValue: _selectedReason,
                    activeColor: Colors.red,
                    onChanged: (value) {
                      setState(() {
                        _selectedReason = value ?? '';
                        _customReason = '';
                      });
                    },
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                ),
                
                if (_selectedReason == 'Other')
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _customReasonController,
                      decoration: InputDecoration(
                        hintText: 'Please specify the reason...',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintStyle: TextStyle(color: Colors.grey[500]),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _customReason = value.trim();
                        });
                      },
                    ),
                  ),
              ],
            const SizedBox(height: 20),
            
            const Text(
              'Description (optional):',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Please provide more details...',
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_selectedReason.isEmpty ||
                            (_selectedReason == 'Other' &&
                                (_customReason == null ||
                                    _customReason!.isEmpty)))
                        ? null
                        : () => Navigator.pop(context, {
                              'reason': _selectedReason == 'Other'
                                  ? _customReason!
                                  : _selectedReason,
                              'description': _descriptionController.text.trim(),
                            }),
                    style: ButtonStyles.destructive(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Submit Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
