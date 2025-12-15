import 'dart:async';
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


  Future<Map<TagCategory, List<Tag>>> getActiveTagCategoriesWithTags() async {
    try {
      final categoriesSnapshot = await _tagCategoriesCol
          .where('isActive', isEqualTo: true)
          .get();

      final categories = categoriesSnapshot.docs
          .map((doc) => TagCategory.fromFirestore(doc))
          .toList();

  
      final tagsSnapshot = await _tagsCol
          .where('isActive', isEqualTo: true)
          .get();

      final allTags = tagsSnapshot.docs
          .map((doc) => Tag.fromFirestore(doc))
          .toList();
      final Map<TagCategory, List<Tag>> result = {};
      for (final category in categories) {
        final categoryTags = allTags
            .where((tag) => tag.categoryId == category.id)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        result[category] = categoryTags;
      }

      final sortedEntries = result.entries.toList()
        ..sort((a, b) => a.key.title.compareTo(b.key.title));

      return Map.fromEntries(sortedEntries);
    } catch (e) {
      return {};
    }
  }

  Stream<Map<TagCategory, List<Tag>>> streamActiveTagCategoriesWithTags() {
    final categoriesStream = _tagCategoriesCol
        .where('isActive', isEqualTo: true)
        .snapshots();
    
    final tagsStream = _tagsCol
        .where('isActive', isEqualTo: true)
        .snapshots();

    final controller = StreamController<Map<TagCategory, List<Tag>>>();
    QuerySnapshot<Map<String, dynamic>>? lastCategoriesSnapshot;
    QuerySnapshot<Map<String, dynamic>>? lastTagsSnapshot;

    void emitIfReady() {
      if (lastCategoriesSnapshot != null && lastTagsSnapshot != null) {
        final categories = lastCategoriesSnapshot!.docs
            .map((doc) => TagCategory.fromFirestore(doc))
            .toList();

        final allTags = lastTagsSnapshot!.docs
            .map((doc) => Tag.fromFirestore(doc))
            .toList();

        final Map<TagCategory, List<Tag>> result = {};
        for (final category in categories) {
          final categoryTags = allTags
              .where((tag) => tag.categoryId == category.id)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          result[category] = categoryTags;
        }

        final sortedEntries = result.entries.toList()
          ..sort((a, b) => a.key.title.compareTo(b.key.title));

        if (!controller.isClosed) {
          controller.add(Map.fromEntries(sortedEntries));
        }
      }
    }

    final categoriesSubscription = categoriesStream.listen((snapshot) {
      lastCategoriesSnapshot = snapshot;
      emitIfReady();
    }, onError: (error) {
      if (!controller.isClosed) {
        controller.addError(error);
      }
    });

    final tagsSubscription = tagsStream.listen((snapshot) {
      lastTagsSnapshot = snapshot;
      emitIfReady();
    }, onError: (error) {
      if (!controller.isClosed) {
        controller.addError(error);
      }
    });

    controller.onCancel = () {
      categoriesSubscription.cancel();
      tagsSubscription.cancel();
    };

    return controller.stream;
  }


  Future<TagCategory?> getTagCategoryById(String id) async {
    try {
      final doc = await _tagCategoriesCol.doc(id).get();
      if (!doc.exists) return null;
      return TagCategory.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

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

