import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/tag_model.dart';

class TagService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<TagCategoryModel>> getAllTagCategories() async {
    try {
      final snapshot = await _firestore.collection('tagCategories').get();
      return snapshot.docs.map((doc) {
        return TagCategoryModel.fromJson({
          ...doc.data(),
          'id': doc.id,
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch tag categories: $e');
    }
  }

  Future<List<TagModel>> getAllTags() async {
    try {
      final snapshot = await _firestore.collection('tags').get();
      return snapshot.docs.map((doc) {
        return TagModel.fromJson({
          ...doc.data(),
          'id': doc.id,
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch tags: $e');
    }
  }

  Future<List<TagCategoryModel>> getAllTagCategoriesWithTags() async {
    try {
      
      final categories = await getAllTagCategories();

      final allTags = await getAllTags();

      for (final category in categories) {
        category.tags = allTags.where((tag) => tag.categoryId == category.id).toList();
      }

      return categories;
    } catch (e) {
      throw Exception('Failed to fetch tag categories with tags: $e');
    }
  }

  Future<String> createTagCategory(TagCategoryModel category) async {
    try {
      final categoryData = category.toJson();
      categoryData.remove('id'); 
      categoryData.remove('tags'); 

      final docRef = await _firestore
          .collection('tagCategories')
          .add(categoryData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create tag category: $e');
    }
  }

  Future<void> updateTagCategory(String categoryId, String title, String? description) async {
    try {
      final updateData = <String, dynamic>{
        'title': title,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (description != null) {
        updateData['description'] = description;
      }

      await _firestore
          .collection('tagCategories')
          .doc(categoryId)
          .update(updateData);
    } catch (e) {
      throw Exception('Failed to update tag category: $e');
    }
  }

  Future<void> toggleCategoryStatus(String categoryId, bool isActive) async {
    try {
      await _firestore
          .collection('tagCategories')
          .doc(categoryId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to toggle category status: $e');
    }
  }

  Future<String> createTag(TagModel tag) async {
    try {
      final tagData = tag.toJson();
      tagData.remove('id'); 

      final docRef = await _firestore
          .collection('tags')
          .add(tagData);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create tag: $e');
    }
  }

  Future<void> updateTag(String tagId, String name) async {
    try {
      await _firestore
          .collection('tags')
          .doc(tagId)
          .update({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update tag: $e');
    }
  }

  Future<void> toggleTagStatus(String tagId, bool isActive) async {
    try {
      await _firestore
          .collection('tags')
          .doc(tagId)
          .update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to toggle tag status: $e');
    }
  }

  Future<void> deleteTag(String tagId) async {
    try {
      await _firestore
          .collection('tags')
          .doc(tagId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete tag: $e');
    }
  }

  Future<List<TagModel>> getTagsByCategory(String categoryId) async {
    try {
      final snapshot = await _firestore
          .collection('tags')
          .where('categoryId', isEqualTo: categoryId)
          .get();

      return snapshot.docs.map((doc) {
        return TagModel.fromJson({
          ...doc.data(),
          'id': doc.id,
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch tags by category: $e');
    }
  }

  Future<List<TagModel>> searchTags(String query) async {
    try {
      final snapshot = await _firestore
          .collection('tags')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      return snapshot.docs.map((doc) {
        return TagModel.fromJson({
          ...doc.data(),
          'id': doc.id,
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to search tags: $e');
    }
  }

  Future<List<TagModel>> getActiveTags() async {
    try {
      final snapshot = await _firestore
          .collection('tags')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
        return TagModel.fromJson({
          ...doc.data(),
          'id': doc.id,
        });
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch active tags: $e');
    }
  }

  Future<Map<String, int>> getTagCountsByCategory() async {
    try {
      final snapshot = await _firestore.collection('tags').get();
      final counts = <String, int>{};

      for (final doc in snapshot.docs) {
        final tagData = doc.data();
        final categoryId = tagData['categoryId'] as String?;
        if (categoryId != null) {
          counts[categoryId] = (counts[categoryId] ?? 0) + 1;
        }
      }

      return counts;
    } catch (e) {
      throw Exception('Failed to fetch tag counts: $e');
    }
  }

  Future<void> deleteTagCategory(String categoryId) async {
    try {
      
      final tags = await getTagsByCategory(categoryId);
      final batch = _firestore.batch();

      for (final tag in tags) {
        batch.delete(_firestore.collection('tags').doc(tag.id));
      }

      batch.delete(_firestore.collection('tagCategories').doc(categoryId));

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete tag category: $e');
    }
  }
}