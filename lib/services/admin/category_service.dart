import 'package:cloud_firestore/cloud_firestore.dart';
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
}