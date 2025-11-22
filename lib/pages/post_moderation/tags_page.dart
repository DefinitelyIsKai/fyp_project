import 'package:flutter/material.dart';
import 'package:fyp_project/models/tag_model.dart';
import 'package:fyp_project/services/tag_service.dart';
import 'dart:math';

class TagsPage extends StatefulWidget {
  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TagService _tagService = TagService();
  List<TagCategoryModel> _categories = [];
  List<TagCategoryModel> _filteredCategories = [];
  String _filterStatus = 'all';
  bool _isLoading = false;

  // Expansion state management
  final Map<String, bool> _categoryExpansionState = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_filterTags);
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _tagService.getAllTagCategoriesWithTags();
      setState(() {
        _categories = categories;
        // Initialize all categories as expanded by default
        for (var category in _categories) {
          _categoryExpansionState[category.id] = true;
        }
        _filterTags();
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load tags: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    try {
      final categories = await _tagService.getAllTagCategoriesWithTags();
      setState(() {
        _categories = categories;
        _filterTags();
      });
    } catch (e) {
      _showErrorSnackBar('Failed to refresh tags: $e');
    }
  }

  void _filterTags() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCategories = _categories
          .map((category) {
        final filteredTags = category.tags.where((tag) {
          final matchesSearch = query.isEmpty ||
              tag.name.toLowerCase().contains(query) ||
              category.title.toLowerCase().contains(query) ||
              category.description.toLowerCase().contains(query);
          final matchesFilter = _filterStatus == 'all' ||
              (_filterStatus == 'active' && tag.isActive) ||
              (_filterStatus == 'inactive' && !tag.isActive);
          return matchesSearch && matchesFilter;
        }).toList();

        final shouldShowEmptyCategory = query.isEmpty && _filterStatus == 'all';
        final categoryMatchesSearch = query.isNotEmpty &&
            (category.title.toLowerCase().contains(query) ||
                category.description.toLowerCase().contains(query));

        if (filteredTags.isNotEmpty || shouldShowEmptyCategory || categoryMatchesSearch) {
          return TagCategoryModel(
            id: category.id,
            title: category.title,
            description: category.description,
            allowMultiple: category.allowMultiple,
            isActive: category.isActive,
            tags: filteredTags,
          );
        }
        return null;
      })
          .whereType<TagCategoryModel>()
          .toList();
    });
  }

  bool _isCategoryExpanded(String categoryId) {
    return _categoryExpansionState[categoryId] ?? true;
  }

  void _toggleCategoryExpansion(String categoryId) {
    setState(() {
      _categoryExpansionState[categoryId] = !_isCategoryExpanded(categoryId);
    });
  }

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Create New',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CreateOptionCard(
                      icon: Icons.category,
                      title: 'Create Category',
                      description: 'Create a new tag category to organize tags',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        _showCategoryDialog();
                      },
                    ),
                    const SizedBox(height: 16),
                    _CreateOptionCard(
                      icon: Icons.label,
                      title: 'Create Tag',
                      description: 'Add a new tag to an existing category',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(context);
                        _showTagDialog();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryDialog({TagCategoryModel? category}) {
    final TextEditingController titleController =
    TextEditingController(text: category?.title ?? '');
    final TextEditingController descController =
    TextEditingController(text: category?.description ?? '');
    final isEdit = category != null;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple[700],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Technical Skills, Experience Level',
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.category),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a category name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

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
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Describe what this category is for...',
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),

                      const Spacer(),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              try {
                                final newCategory = TagCategoryModel(
                                  id: isEdit ? category.id : Random().nextInt(999999).toString(),
                                  title: titleController.text.trim(),
                                  description: descController.text.trim(),
                                  allowMultiple: true,
                                  isActive: true,
                                  tags: isEdit ? category.tags : [],
                                );

                                if (isEdit) {
                                  await _tagService.updateTagCategory(
                                      category!.id,
                                      newCategory.title,
                                      newCategory.description
                                  );
                                } else {
                                  await _tagService.createTagCategory(newCategory);
                                }

                                Navigator.pop(context);
                                _loadInitialData();
                                _showSuccessSnackBar(
                                    isEdit ? 'Category updated successfully' : 'Category created successfully'
                                );
                              } catch (e) {
                                _showErrorSnackBar('Failed to save category: $e');
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[700],
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTagDialog({TagCategoryModel? selectedCategory, TagModel? tag}) {
    final TextEditingController nameController =
    TextEditingController(text: tag?.name ?? '');
    final isEdit = tag != null;
    TagCategoryModel? currentCategory = selectedCategory ??
        (_categories.isNotEmpty ? _categories.first : null);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[700],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Edit Tag' : 'Create New Tag',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<TagCategoryModel>(
                          value: currentCategory,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: _categories.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(
                                category.title,
                                style: const TextStyle(fontSize: 16),
                              ),
                            );
                          }).toList(),
                          onChanged: isEdit ? null : (category) {
                            setState(() {
                              currentCategory = category;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (currentCategory != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  currentCategory!.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Text(
                        'Tag Name',
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
                          hintText: 'Enter tag name...',
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.label_outline),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a tag name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep it short and descriptive (e.g., "Flutter", "Remote", "Senior")',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),

                      const Spacer(),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate() && currentCategory != null) {
                              try {
                                if (isEdit) {
                                  await _tagService.updateTag(
                                      tag.id,
                                      nameController.text.trim()
                                  );
                                } else {
                                  final newTag = TagModel(
                                    id: '',
                                    categoryId: currentCategory!.id,
                                    name: nameController.text.trim(),
                                    isActive: true,
                                  );
                                  await _tagService.createTag(newTag);
                                }

                                Navigator.pop(context);
                                _loadInitialData();
                                _showSuccessSnackBar(
                                    isEdit ? 'Tag updated successfully' : 'Tag created successfully'
                                );
                              } catch (e) {
                                _showErrorSnackBar('Failed to save tag: $e');
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isEdit ? 'Save Changes' : 'Create Tag',
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTag(TagCategoryModel category, TagModel tag) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Tag'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${tag.name}"? '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _tagService.deleteTag(tag.id);
                Navigator.pop(context);
                _loadInitialData();
                _showSuccessSnackBar('Tag deleted successfully');
              } catch (e) {
                _showErrorSnackBar('Failed to delete tag: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _toggleTagStatus(TagCategoryModel category, TagModel tag) async {
    try {
      await _tagService.toggleTagStatus(tag.id, !tag.isActive);
      _loadInitialData();
      _showSuccessSnackBar('Tag ${!tag.isActive ? 'activated' : 'deactivated'} successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to update tag status: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tags Management',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search & Filters Section
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search tags or categories...',
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
                // Filter Chips - Updated to match CategoriesPage style
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
                              _filterTags();
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Active',
                            isSelected: _filterStatus == 'active',
                            onTap: () {
                              setState(() => _filterStatus = 'active');
                              _filterTags();
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Inactive',
                            isSelected: _filterStatus == 'inactive',
                            onTap: () {
                              setState(() => _filterStatus = 'inactive');
                              _filterTags();
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
          if (_filteredCategories.isNotEmpty && !_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Text(
                    '${_getTotalTagsCount()} tag${_getTotalTagsCount() == 1 ? '' : 's'} in ${_filteredCategories.length} categor${_filteredCategories.length == 1 ? 'y' : 'ies'}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

          // Tags List with Pull to Refresh
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredCategories.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _refreshData,
              color: Colors.blue[700],
              backgroundColor: Colors.white,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredCategories.length,
                itemBuilder: (_, index) {
                  final category = _filteredCategories[index];
                  return _TagCategorySection(
                    category: category,
                    onEditTag: (tag) => _showTagDialog(
                        selectedCategory: category,
                        tag: tag
                    ),
                    onDeleteTag: (tag) => _deleteTag(category, tag),
                    onToggleStatus: (tag) => _toggleTagStatus(category, tag),
                    onEditCategory: () => _showCategoryDialog(category: category),
                    onAddTag: () => _showTagDialog(selectedCategory: category),
                    isExpanded: _isCategoryExpanded(category.id),
                    onToggle: () => _toggleCategoryExpansion(category.id),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  int _getTotalTagsCount() {
    return _filteredCategories.fold(0, (sum, category) => sum + category.tags.length);
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading Tags...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.label_off_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty && _filterStatus == 'all'
                ? 'No categories created yet'
                : 'No categories or tags match your search',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty && _filterStatus == 'all'
                ? 'Start by creating your first category'
                : 'Try adjusting your search or filters',
            style: TextStyle(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Add this RefreshController class
class RefreshController {
  void refreshCompleted() {}
  void refreshFailed() {}
}

class _CreateOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _CreateOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// Updated FilterChip to match CategoriesPage style
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

class _TagCategorySection extends StatefulWidget {
  final TagCategoryModel category;
  final Function(TagModel) onEditTag;
  final Function(TagModel) onDeleteTag;
  final Function(TagModel) onToggleStatus;
  final VoidCallback onEditCategory;
  final VoidCallback onAddTag;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _TagCategorySection({
    required this.category,
    required this.onEditTag,
    required this.onDeleteTag,
    required this.onToggleStatus,
    required this.onEditCategory,
    required this.onAddTag,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<_TagCategorySection> createState() => _TagCategorySectionState();
}

class _TagCategorySectionState extends State<_TagCategorySection> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Start animation based on initial expanded state
    if (widget.isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_TagCategorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Header - Clickable to expand/collapse
          GestureDetector(
            onTap: widget.onToggle,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.category,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.category.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, size: 18, color: Colors.blue[700]),
                    onPressed: widget.onEditCategory,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${widget.category.tags.length} tags',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Tags List or Empty State - Animated expansion with proper up/down animation
          AnimatedBuilder(
            animation: _heightAnimation,
            builder: (context, child) {
              return SizeTransition(
                sizeFactor: _heightAnimation,
                axisAlignment: -1.0,
                child: child,
              );
            },
            child: _buildTagsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsContent() {
    if (widget.category.tags.isNotEmpty) {
      return Column(
        children: [
          const SizedBox(height: 4),
          ...widget.category.tags.map((tag) => _TagCard(
            tag: tag,
            onEdit: () => widget.onEditTag(tag),
            onDelete: () => widget.onDeleteTag(tag),
            onToggleStatus: () => widget.onToggleStatus(tag),
          )),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 8),
            Text(
              'No tags in this category yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: widget.onAddTag,
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[700],
              ),
              child: const Text(
                'Add Tag',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _TagCard extends StatelessWidget {
  final TagModel tag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const _TagCard({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Tag Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tag.isActive ? Colors.blue[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.label_outline,
                size: 18,
                color: tag.isActive ? Colors.blue[700] : Colors.grey[500],
              ),
            ),
            const SizedBox(width: 12),
            // Tag Name and Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tag.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tag.isActive ? Colors.black87 : Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tag.isActive ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: tag.isActive ? Colors.green[100]! : Colors.orange[100]!,
                      ),
                    ),
                    child: Text(
                      tag.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 10,
                        color: tag.isActive ? Colors.green[600] : Colors.orange[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Status Toggle Switch
            Switch(
              value: tag.isActive,
              onChanged: (value) => onToggleStatus(),
              activeColor: Colors.green,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            // Actions Menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[500]),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text('Delete'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}