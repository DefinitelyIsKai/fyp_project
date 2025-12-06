import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:fyp_project/models/admin/category_model.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<CategoryModel>> getAllCategories() async {
    final snapshot = await _firestore.collection('categories').get();
    return snapshot.docs
        .map((doc) => CategoryModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<void> createCategory(String name, String description) async {
    final docRef = _firestore.collection('categories').doc();

    await docRef.set({
      'name': name,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'jobCount': 0,
    });
  }

  Future<void> updateCategory(String id, String name, String? description) async {
    await _firestore.collection('categories').doc(id).update({
      'name': name,
      'description': description,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleCategoryStatus(String id, bool isActive) async {
    await _firestore.collection('categories').doc(id).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<int> getJobCountForCategory(String categoryName) async {
    try {
      
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('isDraft', isEqualTo: false)
          .get();
      
      int count = 0;
      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        final status = postData['status'] as String? ?? '';
        final category = postData['category'] as String? ?? '';
        final event = postData['event'] as String? ?? '';
        
        if ((status == 'active' || status == 'completed')) {
          if (category.toLowerCase() == categoryName.toLowerCase() || 
              event.toLowerCase() == categoryName.toLowerCase()) {
            count++;
          }
        }
      }
      return count;
    } catch (e) {
      debugPrint('Error calculating job count for category $categoryName: $e');
      return 0;
    }
  }

  Future<List<CategoryModel>> getAllCategoriesWithJobCounts() async {
    try {
      
      final categories = await getAllCategories();
      
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('isDraft', isEqualTo: false)
          .get();
      
      final Map<String, int> categoryCounts = {};
      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        final status = postData['status'] as String? ?? '';
        
        if (status == 'active' || status == 'completed') {
          
          final category = postData['category'] as String? ?? '';
          final event = postData['event'] as String? ?? '';
          
          final categoryName = category.isNotEmpty ? category : event;
          
          if (categoryName.isNotEmpty) {
            final key = categoryName.toLowerCase().trim();
            if (key.isNotEmpty) {
              categoryCounts[key] = (categoryCounts[key] ?? 0) + 1;
            }
          }
        }
      }
      
      final categoriesWithCounts = categories.map((category) {
        final categoryNameLower = category.name.toLowerCase();
        final count = categoryCounts[categoryNameLower] ?? 0;
        return CategoryModel(
          id: category.id,
          name: category.name,
          description: category.description,
          jobCount: count,
          isActive: category.isActive,
          createdAt: category.createdAt,
          updatedAt: category.updatedAt,
        );
      }).toList();
      
      return categoriesWithCounts;
    } catch (e) {
      debugPrint('Error getting categories with job counts: $e');
      
      return await getAllCategories();
    }
  }
}