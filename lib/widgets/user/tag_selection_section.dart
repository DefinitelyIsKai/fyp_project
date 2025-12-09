import 'package:flutter/material.dart';

import '../../models/user/tag_category.dart';
import '../../models/user/tag.dart';
import '../../utils/user/tag_definitions.dart';

class TagSelectionSection extends StatelessWidget {
  const TagSelectionSection({
    super.key,
    required this.selections,
    required this.onCategoryChanged,
    required this.tagCategoriesWithTags,
    this.loading = false,
  });

  final TagSelectionMap selections;
  final void Function(String categoryId, List<String> values) onCategoryChanged;
  final Map<TagCategory, List<Tag>> tagCategoriesWithTags;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (tagCategoriesWithTags.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'No tag categories available.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tagCategoriesWithTags.entries
          .where((entry) {
            final activeTags = entry.value.where((tag) => tag.isActive).toList();
            return activeTags.isNotEmpty;
          })
          .map((entry) {
        final category = entry.key;
        final tags = entry.value;
        final selected = selections[category.id] ?? const <String>[];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _TagCategoryCard(
            category: category,
            tags: tags,
            selectedValues: selected,
            onChanged: (values) => onCategoryChanged(category.id, values),
          ),
        );
      }).toList(),
    );
  }
}

class _TagCategoryCard extends StatelessWidget {
  const _TagCategoryCard({
    required this.category,
    required this.tags,
    required this.selectedValues,
    required this.onChanged,
  });

  final TagCategory category;
  final List<Tag> tags;
  final List<String> selectedValues;
  final void Function(List<String> values) onChanged;

  @override
  Widget build(BuildContext context) {
    final baseColor = const Color(0xFF00C8A0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.label_outline,
                  color: baseColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No tags available for this category.',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.where((tag) => tag.isActive).map((tag) {
                final isSelected = selectedValues.contains(tag.name);
                return FilterChip(
                  label: Text(tag.name),
                  selected: isSelected,
                  onSelected: (value) {
                    final nextValues = List<String>.from(selectedValues);
                    if (value) {
                      if (category.allowMultiple) {
                        if (!nextValues.contains(tag.name)) {
                          nextValues.add(tag.name);
                        }
                      } else {
                        nextValues
                          ..clear()
                          ..add(tag.name);
                      }
                    } else {
                      nextValues.remove(tag.name);
                    }
                    onChanged(nextValues);
                  },
                selectedColor: baseColor.withOpacity(0.15),
                checkmarkColor: baseColor,
                side: BorderSide(
                  color: isSelected ? baseColor : Colors.grey[300]!,
                ),
                backgroundColor: Colors.grey[100],
                labelStyle: TextStyle(
                  color: isSelected ? baseColor : Colors.black87,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                showCheckmark: true,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

