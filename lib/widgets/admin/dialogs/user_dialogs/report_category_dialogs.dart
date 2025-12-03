import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/report_category_model.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class ReportCategoryDetailsDialog extends StatefulWidget {
  final ReportCategoryModel category;
  final Function(ReportCategoryModel) onUpdate;

  const ReportCategoryDetailsDialog({
    super.key,
    required this.category,
    required this.onUpdate,
  });

  @override
  State<ReportCategoryDetailsDialog> createState() => _ReportCategoryDetailsDialogState();
}

class _ReportCategoryDetailsDialogState extends State<ReportCategoryDetailsDialog> {
  late ReportCategoryModel _editedCategory;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _creditDeductionController = TextEditingController();
  bool _isLoading = false;
  String? _nameError;
  String? _descriptionError;
  String? _creditError;
  
  void Function(void Function())? _setDialogState;

  @override
  void initState() {
    super.initState();
    _editedCategory = widget.category;
    _nameController.text = _editedCategory.name;
    _descriptionController.text = _editedCategory.description;
    _creditDeductionController.text = _editedCategory.creditDeduction.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _creditDeductionController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    
    _nameError = null;
    _descriptionError = null;
    _creditError = null;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final creditText = _creditDeductionController.text.trim();

    if (name.isEmpty) {
      if (_setDialogState != null) {
        _setDialogState!(() {
          _nameError = 'Please enter category name';
        });
      }
      return;
    }

    if (description.isEmpty) {
      if (_setDialogState != null) {
        _setDialogState!(() {
          _descriptionError = 'Please enter category description';
        });
      }
      return;
    }

    final creditDeduction = int.tryParse(creditText);
    if (creditDeduction == null || creditDeduction < 0) {
      if (_setDialogState != null) {
        _setDialogState!(() {
          _creditError = 'Please enter a valid number (0 or greater)';
        });
      }
      return;
    }

    if (_setDialogState != null) {
      _setDialogState!(() {
        _isLoading = true;
      });
    }

    final updatedCategory = _editedCategory.copyWith(
      name: name,
      description: description,
      creditDeduction: creditDeduction,
      type: _editedCategory.type,
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context);
    await widget.onUpdate(updatedCategory);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return StatefulBuilder(
      builder: (context, setDialogState) {
        _setDialogState = setDialogState;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardRed,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _editedCategory.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_editedCategory.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _editedCategory.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        
                        TextField(
                          controller: _nameController,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'Category Name *',
                            hintText: 'Enter category name',
                            prefixIcon: const Icon(Icons.label),
                            errorText: _nameError,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          onChanged: (value) {
                            if (_nameError != null && _setDialogState != null) {
                              _setDialogState!(() => _nameError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: _descriptionController,
                          enabled: !_isLoading,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Description *',
                            hintText: 'Enter category description',
                            prefixIcon: const Icon(Icons.description),
                            errorText: _descriptionError,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          onChanged: (value) {
                            if (_descriptionError != null && _setDialogState != null) {
                              _setDialogState!(() => _descriptionError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        SwitchListTile(
                          title: const Text('Enable Category'),
                          subtitle: const Text('Turn this report category on or off'),
                          value: _editedCategory.isEnabled,
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  if (_setDialogState != null) {
                                    _setDialogState!(() {
                                      _editedCategory = _editedCategory.copyWith(isEnabled: value);
                                    });
                                  }
                                },
                        ),
                        const SizedBox(height: 16),
                        
                        const Text(
                          'Category Type *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Jobseeker'),
                                subtitle: const Text('For reporting jobseekers'),
                                value: 'jobseeker',
                                groupValue: _editedCategory.type,
                                onChanged: _isLoading
                                    ? null
                                    : (value) {
                                        if (value != null && _setDialogState != null) {
                                          _setDialogState!(() {
                                            _editedCategory = _editedCategory.copyWith(type: value);
                                          });
                                        }
                                      },
                                activeColor: Colors.purple[700],
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Recruiter'),
                                subtitle: const Text('For reporting recruiters'),
                                value: 'recruiter',
                                groupValue: _editedCategory.type,
                                onChanged: _isLoading
                                    ? null
                                    : (value) {
                                        if (value != null && _setDialogState != null) {
                                          _setDialogState!(() {
                                            _editedCategory = _editedCategory.copyWith(type: value);
                                          });
                                        }
                                      },
                                activeColor: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: _creditDeductionController,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Credit Deduction Amount *',
                            hintText: 'Enter number of credits to deduct',
                            prefixIcon: Icon(
                              Icons.account_balance_wallet,
                              color: _creditError != null ? Colors.red : AppColors.cardRed,
                            ),
                            errorText: _creditError,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          onChanged: (value) {
                            if (_creditError != null && _setDialogState != null) {
                              _setDialogState!(() => _creditError = null);
                            }
                          },
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
                        if (_isLoading) ...[
                          const SizedBox(height: 24),
                          const Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text(
                                  'Saving changes...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isLoading ? null : () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: Colors.grey[300]!),
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
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _saveCategory,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.cardRed,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
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
                                    : const Text(
                                        'Save Changes',
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class CreateReportCategoryDialog extends StatefulWidget {
  final Function({
    required String name,
    required String description,
    required int creditDeduction,
    required String type,
    bool isEnabled,
  }) onCreate;

  const CreateReportCategoryDialog({
    super.key,
    required this.onCreate,
  });

  @override
  State<CreateReportCategoryDialog> createState() => _CreateReportCategoryDialogState();
}

class _CreateReportCategoryDialogState extends State<CreateReportCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _creditDeductionController = TextEditingController();
  String _selectedType = 'jobseeker';
  bool _isEnabled = true;
  bool _isLoading = false;
  String? _nameError;
  String? _descriptionError;
  String? _creditError;
  
  void Function(void Function())? _setDialogState;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _creditDeductionController.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    
    _nameError = null;
    _descriptionError = null;
    _creditError = null;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final creditText = _creditDeductionController.text.trim();

    if (name.isEmpty) {
      if (_setDialogState != null) {
        _setDialogState!(() {
          _nameError = 'Please enter category name';
        });
      }
      return;
    }

    if (description.isEmpty) {
      if (_setDialogState != null) {
        _setDialogState!(() {
          _descriptionError = 'Please enter category description';
        });
      }
      return;
    }

    final creditDeduction = int.tryParse(creditText);
    if (creditDeduction == null || creditDeduction < 0) {
      if (_setDialogState != null) {
        _setDialogState!(() {
          _creditError = 'Please enter a valid number (0 or greater)';
        });
      }
      return;
    }

    if (_setDialogState != null) {
      _setDialogState!(() {
        _isLoading = true;
      });
    }

    Navigator.pop(context);
    await widget.onCreate(
      name: name,
      description: description,
      creditDeduction: creditDeduction,
      type: _selectedType,
      isEnabled: _isEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return StatefulBuilder(
      builder: (context, setDialogState) {
        _setDialogState = setDialogState;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.cardRed,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Create New Report Category',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Add a new category for reporting jobseekers or recruiters',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          TextField(
                            controller: _nameController,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'Category Name *',
                              hintText: 'Enter category name',
                              prefixIcon: const Icon(Icons.label),
                              errorText: _nameError,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            onChanged: (value) {
                              if (_nameError != null && _setDialogState != null) {
                                _setDialogState!(() => _nameError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          TextField(
                            controller: _descriptionController,
                            enabled: !_isLoading,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Description *',
                              hintText: 'Enter category description',
                              prefixIcon: const Icon(Icons.description),
                              errorText: _descriptionError,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            onChanged: (value) {
                              if (_descriptionError != null && _setDialogState != null) {
                                _setDialogState!(() => _descriptionError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          const Text(
                            'Category Type *',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Jobseeker'),
                                  subtitle: const Text('For reporting jobseekers'),
                                  value: 'jobseeker',
                                  groupValue: _selectedType,
                                  onChanged: _isLoading
                                      ? null
                                      : (value) {
                                          if (value != null && _setDialogState != null) {
                                            _setDialogState!(() {
                                              _selectedType = value;
                                            });
                                          }
                                        },
                                  activeColor: Colors.purple[700],
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Recruiter'),
                                  subtitle: const Text('For reporting recruiters'),
                                  value: 'recruiter',
                                  groupValue: _selectedType,
                                  onChanged: _isLoading
                                      ? null
                                      : (value) {
                                          if (value != null && _setDialogState != null) {
                                            _setDialogState!(() {
                                              _selectedType = value;
                                            });
                                          }
                                        },
                                  activeColor: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          TextField(
                            controller: _creditDeductionController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Credit Deduction Amount *',
                              hintText: 'Enter number of credits to deduct',
                              prefixIcon: Icon(
                                Icons.account_balance_wallet,
                                color: _creditError != null ? Colors.red : AppColors.cardRed,
                              ),
                              errorText: _creditError,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            onChanged: (value) {
                              if (_creditError != null && _setDialogState != null) {
                                _setDialogState!(() => _creditError = null);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          SwitchListTile(
                            title: const Text('Enable Category'),
                            subtitle: const Text('Turn this report category on or off'),
                            value: _isEnabled,
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    if (_setDialogState != null) {
                                      _setDialogState!(() {
                                        _isEnabled = value;
                                      });
                                    }
                                  },
                          ),
                          if (_isLoading) ...[
                            const SizedBox(height: 24),
                            const Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text(
                                    'Creating category...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: BorderSide(color: Colors.grey[300]!),
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
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _createCategory,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.cardRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
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
                                      : const Text(
                                          'Create Category',
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
