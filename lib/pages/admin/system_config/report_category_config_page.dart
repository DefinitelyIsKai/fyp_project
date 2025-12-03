import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/report_category_model.dart';
import 'package:fyp_project/services/admin/system_config_service.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:fyp_project/widgets/admin/dialogs/user_dialogs/report_category_dialogs.dart';

class ReportCategoryConfigPage extends StatefulWidget {
  const ReportCategoryConfigPage({super.key});

  @override
  State<ReportCategoryConfigPage> createState() => _ReportCategoryConfigPageState();
}

class _ReportCategoryConfigPageState extends State<ReportCategoryConfigPage> {
  final SystemConfigService _configService = SystemConfigService();
  List<ReportCategoryModel> _categories = [];
  List<ReportCategoryModel> _filteredCategories = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _selectedType = 'all';
  String _selectedStatus = 'all'; 
  bool _isFiltersExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _configService.getReportCategories();
      categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _categories = categories;
        _applyFilters();
      });
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

  void _applyFilters() {
    var filtered = List<ReportCategoryModel>.from(_categories);

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((category) {
        return category.name.toLowerCase().contains(query) ||
            category.description.toLowerCase().contains(query);
      }).toList();
    }

    if (_selectedType != 'all') {
      filtered = filtered.where((category) => category.type == _selectedType).toList();
    }

    if (_selectedStatus != 'all') {
      if (_selectedStatus == 'enabled') {
        filtered = filtered.where((category) => category.isEnabled).toList();
      } else {
        filtered = filtered.where((category) => !category.isEnabled).toList();
      }
    }

    setState(() {
      _filteredCategories = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedType = 'all';
      _selectedStatus = 'all';
    });
    _applyFilters();
  }

  void _resetFilters() {
    setState(() {
      _selectedType = 'all';
      _selectedStatus = 'all';
    });
    _applyFilters();
  }

  bool _hasActiveFilters() {
    return _searchController.text.isNotEmpty ||
        _selectedType != 'all' ||
        _selectedStatus != 'all';
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_searchController.text.isNotEmpty) count++;
    if (_selectedType != 'all') count++;
    if (_selectedStatus != 'all') count++;
    return count;
  }

  Future<void> _createCategory({
    required String name,
    required String description,
    required int creditDeduction,
    required String type,
    bool isEnabled = true,
  }) async {
    
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
                  Text('Creating category...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final createdBy = authService.currentAdmin?.email;
      
      await _configService.createReportCategory(
        name: name,
        description: description,
        creditDeduction: creditDeduction,
        type: type,
        isEnabled: isEnabled,
        createdBy: createdBy,
      );
      
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category created successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        _loadCategories();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating category: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateCategoryDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => CreateReportCategoryDialog(
        onCreate: _createCategory,
      ),
    );
  }

  Future<void> _updateCategory(ReportCategoryModel category) async {
    
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
        Navigator.pop(context); 
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
        Navigator.pop(context); 
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => ReportCategoryDetailsDialog(
        category: category,
        onUpdate: _updateCategory,
      ),
    );
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
                      Text(
                        'Tap the button below to create your first category',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search categories...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        _applyFilters();
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (_) => _applyFilters(),
                          ),
                          const SizedBox(height: 12),
                          
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isFiltersExpanded = !_isFiltersExpanded;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.filter_list,
                                    size: 20,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Filters',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_hasActiveFilters())
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[700],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_getActiveFilterCount()}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Icon(
                                    _isFiltersExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: Colors.grey[600],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          ClipRect(
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: _isFiltersExpanded
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _FilterChip(
                                                  label: 'Type',
                                                  value: _selectedType == 'all'
                                                      ? 'All'
                                                      : _selectedType == 'jobseeker'
                                                          ? 'Jobseeker'
                                                          : 'Recruiter',
                                                  onTap: () => _showTypeFilter(),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: _FilterChip(
                                                  label: 'Status',
                                                  value: _selectedStatus == 'all'
                                                      ? 'All'
                                                      : _selectedStatus == 'enabled'
                                                          ? 'Enabled'
                                                          : 'Disabled',
                                                  onTap: () => _showStatusFilter(),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_hasActiveFilters()) ...[
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[50],
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    '${_getActiveFilterCount()} filter${_getActiveFilterCount() > 1 ? 's' : ''} active',
                                                    style: TextStyle(
                                                      color: Colors.blue[700],
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                TextButton.icon(
                                                  onPressed: _resetFilters,
                                                  icon: const Icon(Icons.clear_all, size: 16),
                                                  label: const Text('Clear All'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          
                          if (_filteredCategories.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Found ${_filteredCategories.length} categor${_filteredCategories.length == 1 ? 'y' : 'ies'}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue[900],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: _filteredCategories.isEmpty
                          ? Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.search_off,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'No categories found',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your search criteria or filters',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    OutlinedButton.icon(
                                      onPressed: _clearFilters,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Clear All Filters'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
                                  ..._filteredCategories.map((category) => _buildCategoryCard(category)),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCategoryDialog,
        backgroundColor: AppColors.cardRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
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
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: category.type == 'recruiter' ? Colors.blue[50] : Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: category.type == 'recruiter' ? Colors.blue[200]! : Colors.purple[200]!,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category.type == 'recruiter' ? Icons.business : Icons.person,
                      color: category.type == 'recruiter' ? Colors.blue[700] : Colors.purple[700],
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      category.type == 'recruiter' ? 'Recruiter' : 'Jobseeker',
                      style: TextStyle(
                        fontSize: 12,
                        color: category.type == 'recruiter' ? Colors.blue[700] : Colors.purple[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
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

  void _showTypeFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...['all', 'jobseeker', 'recruiter'].map((type) {
              String displayName;
              switch (type) {
                case 'all':
                  displayName = 'All Types';
                  break;
                case 'jobseeker':
                  displayName = 'Jobseeker';
                  break;
                case 'recruiter':
                  displayName = 'Recruiter';
                  break;
                default:
                  displayName = type;
              }
              return ListTile(
                title: Text(displayName),
                trailing: _selectedType == type
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _selectedType = type);
                  Navigator.pop(context);
                  _applyFilters();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showStatusFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...['all', 'enabled', 'disabled'].map((status) {
              String displayName;
              switch (status) {
                case 'all':
                  displayName = 'All Status';
                  break;
                case 'enabled':
                  displayName = 'Enabled';
                  break;
                case 'disabled':
                  displayName = 'Disabled';
                  break;
                default:
                  displayName = status;
              }
              return ListTile(
                title: Text(displayName),
                trailing: _selectedStatus == status
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _selectedStatus = status);
                  Navigator.pop(context);
                  _applyFilters();
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != 'All';
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
