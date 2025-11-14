import 'package:flutter/material.dart';
import 'package:fyp_project/models/tag_model.dart';
import 'package:fyp_project/services/tag_service.dart';

class TagsPage extends StatefulWidget {
  const TagsPage({super.key});

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  final TagService _tagService = TagService();
  List<TagModel> _tags = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTags();
    _searchController.addListener(_filterTags);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    try {
      final tags = await _tagService.getAllTags();
      setState(() => _tags = tags);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tags: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterTags() {
    // Implement tag filtering logic
  }

  Future<void> _showAddTagDialog() async {
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Tag Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _tagService.createTag(nameController.text);
                if (mounted) {
                  Navigator.pop(context);
                  _loadTags();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search tags',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tags.isEmpty
                    ? const Center(child: Text('No tags found'))
                    : ListView.builder(
                        itemCount: _tags.length,
                        itemBuilder: (context, index) {
                          final tag = _tags[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text(tag.name),
                              subtitle: Text('Used ${tag.usageCount} times'),
                              trailing: Switch(
                                value: tag.isActive,
                                onChanged: (value) async {
                                  try {
                                    await _tagService.updateTagStatus(tag.id, value);
                                    _loadTags();
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTagDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

