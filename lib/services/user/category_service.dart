import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user/category.dart';

/// Helper class to hold category with its actual post count
class _CategoryWithCount {
  final Category category;
  final int count;
  
  _CategoryWithCount({required this.category, required this.count});
}

class CategoryService {
  CategoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('categories');

  /// Fetch all active categories from Firestore
  Future<List<Category>> getActiveCategories() async {
    try {
      final snapshot = await _col
          .where('isActive', isEqualTo: true)
          .get();
      
      final categories = snapshot.docs
          .map((doc) => Category.fromFirestore(doc))
          .toList();
      
      // Sort by name alphabetically
      categories.sort((a, b) => a.name.compareTo(b.name));
      
      return categories;
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }

  /// Stream all active categories from Firestore
  Stream<List<Category>> streamActiveCategories() {
    return _col
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => Category.fromFirestore(doc))
              .toList();
          
          // Sort by name alphabetically
          categories.sort((a, b) => a.name.compareTo(b.name));
          
          return categories;
        });
  }

  /// Fetch a single category by ID
  Future<Category?> getById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) return null;
      return Category.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  /// Fetch popular categories sorted by active/completed post count (descending)
  /// Only counts published, active or completed posts (isDraft == false && (status == 'active' || status == 'completed')) for popularity
  Future<List<Category>> getPopularCategories({int limit = 4}) async {
    try {
      // Get all active categories
      final categorySnapshot = await _col
          .where('isActive', isEqualTo: true)
          .get();
      
      final categories = categorySnapshot.docs
          .map((doc) => Category.fromFirestore(doc))
          .toList();
      
      // Query all non-draft posts to count per category
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('isDraft', isEqualTo: false)
          .get();
      
      // Count active or completed, non-draft posts per category/event
      final Map<String, int> categoryPostCounts = {};
      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        final status = postData['status'] as String? ?? '';
        final event = postData['event'] as String? ?? '';
        // Only count if status is 'active' or 'completed' and event is not empty
        if ((status == 'active' || status == 'completed') && event.isNotEmpty) {
          categoryPostCounts[event] = (categoryPostCounts[event] ?? 0) + 1;
        }
      }
      
      // Create a map of categories with their actual active/completed post counts
      final categoriesWithCounts = categories.map((category) {
        final actualCount = categoryPostCounts[category.name] ?? 0;
        return _CategoryWithCount(category: category, count: actualCount);
      }).toList();
      
      // Sort by actual active/completed post count descending, then by name
      categoriesWithCounts.sort((a, b) {
        final countComparison = b.count.compareTo(a.count);
        if (countComparison != 0) return countComparison;
        return a.category.name.compareTo(b.category.name);
      });
      
      // Return top N categories
      return categoriesWithCounts
          .take(limit)
          .map((item) => item.category)
          .toList();
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }

  /// Stream popular categories sorted by active/completed post count (descending)
  /// Only counts published, active or completed posts (isDraft == false && (status == 'active' || status == 'completed')) for popularity
  Stream<List<Category>> streamPopularCategories({int limit = 4}) {
    // Combine category stream with posts stream to calculate real-time popularity
    return _col
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((categorySnapshot) async {
          // Get all active categories
          final categories = categorySnapshot.docs
              .map((doc) => Category.fromFirestore(doc))
              .toList();
          
          // Query all non-draft posts to count per category
          final postsSnapshot = await _firestore
              .collection('posts')
              .where('isDraft', isEqualTo: false)
              .get();
          
          // Count active or completed, non-draft posts per category/event
          final Map<String, int> categoryPostCounts = {};
          for (final postDoc in postsSnapshot.docs) {
            final postData = postDoc.data();
            final status = postData['status'] as String? ?? '';
            final event = postData['event'] as String? ?? '';
            // Only count if status is 'active' or 'completed' and event is not empty
            if ((status == 'active' || status == 'completed') && event.isNotEmpty) {
              categoryPostCounts[event] = (categoryPostCounts[event] ?? 0) + 1;
            }
          }
          
          // Create a map of categories with their actual active/completed post counts
          final categoriesWithCounts = categories.map((category) {
            final actualCount = categoryPostCounts[category.name] ?? 0;
            return _CategoryWithCount(category: category, count: actualCount);
          }).toList();
          
          // Sort by actual active/completed post count descending, then by name
          categoriesWithCounts.sort((a, b) {
            final countComparison = b.count.compareTo(a.count);
            if (countComparison != 0) return countComparison;
            return a.category.name.compareTo(b.category.name);
          });
          
          // Return top N categories
          return categoriesWithCounts
              .take(limit)
              .map((item) => item.category)
              .toList();
        });
  }

  /// Find category by name (case-insensitive)
  Future<Category?> findByName(String name) async {
    try {
      final snapshot = await _col
          .where('isActive', isEqualTo: true)
          .get();
      
      final categories = snapshot.docs
          .map((doc) => Category.fromFirestore(doc))
          .toList();
      
      return categories.firstWhere(
        (cat) => cat.name.toLowerCase() == name.toLowerCase(),
        orElse: () => throw StateError('Category not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Increment jobCount for a category by name
  Future<void> incrementJobCount(String categoryName) async {
    try {
      final category = await findByName(categoryName);
      if (category != null) {
        await _col.doc(category.id).update({
          'jobCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Ignore errors - category might not exist
    }
  }
}

