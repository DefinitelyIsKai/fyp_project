import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user/tag_category.dart';
import '../../models/user/tag.dart';

class TagService {
  TagService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _tagCategoriesCol =>
      _firestore.collection('tagCategories');

  CollectionReference<Map<String, dynamic>> get _tagsCol =>
      _firestore.collection('tags');

  /// Fetch all active tag categories with their tags from Firestore
  Future<Map<TagCategory, List<Tag>>> getActiveTagCategoriesWithTags() async {
    try {
      // Fetch active tag categories
      final categoriesSnapshot = await _tagCategoriesCol
          .where('isActive', isEqualTo: true)
          .get();

      final categories = categoriesSnapshot.docs
          .map((doc) => TagCategory.fromFirestore(doc))
          .toList();

      // Fetch all active tags
      final tagsSnapshot = await _tagsCol
          .where('isActive', isEqualTo: true)
          .get();

      final allTags = tagsSnapshot.docs
          .map((doc) => Tag.fromFirestore(doc))
          .toList();

      // Group tags by categoryId
      final Map<TagCategory, List<Tag>> result = {};
      for (final category in categories) {
        final categoryTags = allTags
            .where((tag) => tag.categoryId == category.id)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        result[category] = categoryTags;
      }

      // Sort categories by title
      final sortedEntries = result.entries.toList()
        ..sort((a, b) => a.key.title.compareTo(b.key.title));

      return Map.fromEntries(sortedEntries);
    } catch (e) {
      // Return empty map on error
      return {};
    }
  }

  /// Stream all active tag categories with their tags from Firestore
  Stream<Map<TagCategory, List<Tag>>> streamActiveTagCategoriesWithTags() {
    return _tagCategoriesCol
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((categoriesSnapshot) async {
      final categories = categoriesSnapshot.docs
          .map((doc) => TagCategory.fromFirestore(doc))
          .toList();

      // Fetch all active tags
      final tagsSnapshot = await _tagsCol
          .where('isActive', isEqualTo: true)
          .get();

      final allTags = tagsSnapshot.docs
          .map((doc) => Tag.fromFirestore(doc))
          .toList();

      // Group tags by categoryId
      final Map<TagCategory, List<Tag>> result = {};
      for (final category in categories) {
        final categoryTags = allTags
            .where((tag) => tag.categoryId == category.id)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        result[category] = categoryTags;
      }

      // Sort categories by title
      final sortedEntries = result.entries.toList()
        ..sort((a, b) => a.key.title.compareTo(b.key.title));

      return Map.fromEntries(sortedEntries);
    });
  }

  /// Fetch a single tag category by ID
  Future<TagCategory?> getTagCategoryById(String id) async {
    try {
      final doc = await _tagCategoriesCol.doc(id).get();
      if (!doc.exists) return null;
      return TagCategory.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Fetch all tags for a specific category
  Future<List<Tag>> getTagsByCategoryId(String categoryId) async {
    try {
      final snapshot = await _tagsCol
          .where('categoryId', isEqualTo: categoryId)
          .where('isActive', isEqualTo: true)
          .get();

      final tags = snapshot.docs
          .map((doc) => Tag.fromFirestore(doc))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      return tags;
    } catch (e) {
      return [];
    }
  }
}

