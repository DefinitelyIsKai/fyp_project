import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/report_category_model.dart';
import 'package:fyp_project/services/admin/system_config_service.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class ReportCategoryConfigPage extends StatefulWidget {
  const ReportCategoryConfigPage({super.key});

  @override
  State<ReportCategoryConfigPage> createState() => _ReportCategoryConfigPageState();
}

class _ReportCategoryConfigPageState extends State<ReportCategoryConfigPage> {
  final SystemConfigService _configService = SystemConfigService();
  List<ReportCategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _configService.getReportCategories();
      if (categories.isEmpty) {
        await _configService.initializeDefaultReportCategories();
        final updatedCategories = await _configService.getReportCategories();
        setState(() => _categories = updatedCategories);
      } else {
        setState(() => _categories = categories);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateCategory(ReportCategoryModel category) async {
    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Updating category...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final updatedBy = authService.currentAdmin?.email;
      
      await _configService.updateReportCategory(category, updatedBy: updatedBy);
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        _loadCategories();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating category: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCategoryDetails(ReportCategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => _ReportCategoryDetailsDialog(
        category: category,
        onUpdate: _updateCategory,
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will reset all report categories to their default values. Existing customizations will be lost. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _configService.initializeDefaultReportCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Categories reset to defaults successfully')),
          );
          _loadCategories();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error resetting categories: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Category Configuration'),
        backgroundColor: AppColors.cardRed,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCategories,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'reset') {
                _resetToDefaults();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore, size: 20),
                    SizedBox(width: 8),
                    Text('Reset to Defaults'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flag_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No report categories found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await _configService.initializeDefaultReportCategories();
                          _loadCategories();
                        },
                        child: const Text('Initialize Default Categories'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.red[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Configure credit deductions for each report category. When a user is reported under a category, the specified credits will be deducted from their account.',
                                  style: TextStyle(color: Colors.red[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._categories.map((category) => _buildCategoryCard(category)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCategoryCard(ReportCategoryModel category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showCategoryDetails(category),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: category.isEnabled,
                    onChanged: (value) {
                      final updatedCategory = category.copyWith(isEnabled: value);
                      _updateCategory(updatedCategory);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Show credit deduction preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Credit Deduction: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${category.creditDeduction} credits',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showCategoryDetails(category),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit Category'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCategoryDetailsDialog extends StatefulWidget {
  final ReportCategoryModel category;
  final Function(ReportCategoryModel) onUpdate;

  const _ReportCategoryDetailsDialog({
    required this.category,
    required this.onUpdate,
  });

  @override
  State<_ReportCategoryDetailsDialog> createState() => _ReportCategoryDetailsDialogState();
}

class _ReportCategoryDetailsDialogState extends State<_ReportCategoryDetailsDialog> {
  late ReportCategoryModel _editedCategory;
  final TextEditingController _creditDeductionController = TextEditingController();
  bool _isLoading = false;
  String? _creditError;

  @override
  void initState() {
    super.initState();
    _editedCategory = widget.category;
    _creditDeductionController.text = _editedCategory.creditDeduction.toString();
  }

  @override
  void dispose() {
    _creditDeductionController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    // Reset errors
    _creditError = null;

    // Validate credit deduction
    final creditText = _creditDeductionController.text.trim();
    if (creditText.isEmpty) {
      setState(() {
        _creditError = 'Please enter credit deduction amount';
      });
      return;
    }

    final creditDeduction = int.tryParse(creditText);
    if (creditDeduction == null || creditDeduction < 0) {
      setState(() {
        _creditError = 'Please enter a valid number (0 or greater)';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final updatedCategory = _editedCategory.copyWith(
      creditDeduction: creditDeduction,
      updatedAt: DateTime.now(),
    );

    // Close dialog first, then update 
    Navigator.pop(context);
    await widget.onUpdate(updatedCategory);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[700],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editedCategory.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _editedCategory.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enable/Disable
                    SwitchListTile(
                      title: const Text('Enable Category'),
                      subtitle: const Text('Turn this report category on or off'),
                      value: _editedCategory.isEnabled,
                      onChanged: (value) {
                        setState(() {
                          _editedCategory = _editedCategory.copyWith(isEnabled: value);
                        });
                      },
                    ),
                    const Divider(),
                    // Credit Deduction
                    const Text(
                      'Credit Deduction',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Amount of credits to deduct from the reported user when this category is selected',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _creditDeductionController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        if (_creditError != null) {
                          setState(() => _creditError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Credit Deduction Amount *',
                        hintText: 'Enter number of credits to deduct',
                        prefixIcon: Icon(
                          Icons.account_balance_wallet,
                          color: _creditError != null ? Colors.red : Colors.red[700],
                        ),
                        errorText: _creditError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _creditError != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _creditError != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _creditError != null ? Colors.red : Colors.red[700]!,
                            width: 2,
                          ),
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                        filled: true,
                        fillColor: _creditError != null ? Colors.red[50] : Colors.grey[50],
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'When a user is reported under this category, ${_creditDeductionController.text.isEmpty ? "X" : _creditDeductionController.text} credits will be automatically deducted from their account.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardRed,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

