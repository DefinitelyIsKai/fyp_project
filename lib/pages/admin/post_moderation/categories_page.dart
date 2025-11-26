import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/category_model.dart';
import 'package:fyp_project/services/admin/category_service.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final CategoryService _categoryService = CategoryService();
  final TextEditingController _searchController = TextEditingController();
  List<CategoryModel> _categories = [];
  List<CategoryModel> _filteredCategories = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _searchController.addListener(_filterCategories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _categoryService.getAllCategories();
      setState(() => _categories = categories);
      _filterCategories();
    } catch (e) {
      _showSnackBar('Error loading categories: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCategories = _categories.where((category) {
        final matchesSearch = query.isEmpty ||
            category.name.toLowerCase().contains(query) ||
            (category.description ?? '').toLowerCase().contains(query);

        final matchesFilter = _filterStatus == 'all' ||
            (_filterStatus == 'active' && (category.isActive ?? true)) ||
            (_filterStatus == 'inactive' && !(category.isActive ?? true));

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _showCategoryDialog({CategoryModel? category}) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(text: category?.description ?? '');
    final isEdit = category != null;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Edit Category' : 'Create New Category',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Icon Preview
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Icon(
                            Icons.category,
                            size: 40,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Category Name Field
                      Text(
                        'Category Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Technology, Marketing, Design',
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          prefixIcon: const Icon(Icons.label_outline),
                        ),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a category name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Description Field
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: descController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Brief description of this category...',
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          alignLabelWithHint: true,
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Optional - helps users understand what this category includes',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),

                      // Status Toggle (for edit mode)
                      if (isEdit) ...[
                        const SizedBox(height: 32),
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                category!.isActive ?? true
                                    ? Icons.check_circle
                                    : Icons.remove_circle,
                                color: category.isActive ?? true
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.isActive ?? true
                                          ? 'Active'
                                          : 'Inactive',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: category.isActive ?? true
                                            ? Colors.green[700]
                                            : Colors.orange[700],
                                      ),
                                    ),
                                    Text(
                                      category.isActive ?? true
                                          ? 'This category is visible and available for job posts'
                                          : 'This category is hidden and not available for new jobs',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Switch(
                                value: category.isActive ?? true,
                                onChanged: (value) {
                                  _confirmStatusChange(category, value);
                                },
                                activeColor: Colors.green,
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  if (isEdit) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _confirmDelete(category!),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.red[300]!),
                        ),
                        child: Text(
                          category!.isActive ?? true ? 'Deactivate' : 'Activate',
                          style: TextStyle(
                            color: category.isActive ?? true ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: isEdit ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          try {
                            if (isEdit) {
                              await _categoryService.updateCategory(
                                category!.id,
                                nameController.text.trim(),
                                descController.text.trim(),
                              );
                              _showSnackBar('Category updated successfully');
                            } else {
                              await _categoryService.createCategory(
                                nameController.text.trim(),
                                descController.text.trim(),
                              );
                              _showSnackBar('Category created successfully');
                            }

                            if (mounted) {
                              Navigator.pop(context);
                              _loadCategories();
                            }
                          } catch (e) {
                            _showSnackBar('Error: $e', isError: true);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isEdit ? 'Save Changes' : 'Create Category',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmStatusChange(CategoryModel category, bool newStatus) async {
    final action = newStatus ? 'Activate' : 'Deactivate';

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              newStatus ? Icons.check_circle : Icons.pause_circle,
              color: newStatus ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Text('$action Category'),
          ],
        ),
        content: Text(
          'Are you sure you want to $action "${category.name}"? '
              '${newStatus ? 'Activated categories will be available for job posts.' : 'Deactivated categories will not be available for new job posts.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _categoryService.toggleCategoryStatus(category.id, newStatus);
                if (mounted) {
                  Navigator.pop(context); // Close confirmation dialog
                  Navigator.pop(context); // Close edit dialog
                  _showSnackBar('Category ${newStatus ? 'activated' : 'deactivated'} successfully');
                  _loadCategories();
                }
              } catch (e) {
                _showSnackBar('Error: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? Colors.green : Colors.orange,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(CategoryModel category) async {
    final action = category.isActive ?? true ? 'Deactivate' : 'Activate';

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              category.isActive ?? true ? Icons.pause_circle : Icons.play_arrow,
              color: category.isActive ?? true ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 12),
            Text('$action Category'),
          ],
        ),
        content: Text(
          'Are you sure you want to $action "${category.name}"? '
              '${category.isActive ?? true ? 'Deactivated categories will not be available for new job posts.' : 'Activated categories will be available for job posts.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _categoryService.toggleCategoryStatus(category.id, !(category.isActive ?? true));
                if (mounted) {
                  Navigator.pop(context); // Close confirmation dialog
                  Navigator.pop(context); // Close edit dialog
                  _showSnackBar('Category ${category.isActive ?? true ? 'deactivated' : 'activated'} successfully');
                  _loadCategories();
                }
              } catch (e) {
                _showSnackBar('Error: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: category.isActive ?? true ? Colors.orange : Colors.green,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories Management',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search categories...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            isSelected: _filterStatus == 'all',
                            onTap: () {
                              setState(() => _filterStatus = 'all');
                              _filterCategories();
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Active',
                            isSelected: _filterStatus == 'active',
                            onTap: () {
                              setState(() => _filterStatus = 'active');
                              _filterCategories();
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Inactive',
                            isSelected: _filterStatus == 'inactive',
                            onTap: () {
                              setState(() => _filterStatus = 'inactive');
                              _filterCategories();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results Count
          if (_filteredCategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${_filteredCategories.length} categor${_filteredCategories.length == 1 ? 'y' : 'ies'} found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Categories List with Pull-to-Refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadCategories,
              color: Colors.blue[700],
              backgroundColor: Colors.white,
              child: _isLoading
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading categories...'),
                  ],
                ),
              )
                  : _filteredCategories.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _filteredCategories.length,
                itemBuilder: (_, index) {
                  final category = _filteredCategories[index];
                  return _CategoryCard(
                    category: category,
                    onTap: () => _showCategoryDialog(category: category),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        backgroundColor: AppColors.primaryDark,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.category,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty && _filterStatus == 'all'
                    ? 'No categories found'
                    : 'No categories match your search',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchController.text.isEmpty && _filterStatus == 'all'
                    ? 'Add your first category to get started'
                    : 'Try adjusting your search or filters',
                style: TextStyle(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_searchController.text.isEmpty && _filterStatus == 'all')
                ElevatedButton(
                  onPressed: () => _showCategoryDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Create First Category',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[700] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue[700]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = category.isActive ?? true;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isActive ? Colors.blue[50] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.category,
                  color: isActive ? Colors.blue[700] : Colors.grey[500],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.black87 : Colors.grey[600],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green[50] : Colors.orange[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isActive ? Colors.green[100]! : Colors.orange[100]!,
                            ),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.green[700] : Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.description ?? 'No description',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: category.description == null ? FontStyle.italic : FontStyle.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.work_outline, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          '${category.jobCount ?? 0} job${category.jobCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}