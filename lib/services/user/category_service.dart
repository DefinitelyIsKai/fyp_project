import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user/category.dart';

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

  Future<List<Category>> getActiveCategories() async {
    try {
      final snapshot = await _col
          .where('isActive', isEqualTo: true)
          .get();
      
      final categories = snapshot.docs
          .map((doc) => Category.fromFirestore(doc))
          .toList();
      
      categories.sort((a, b) => a.name.compareTo(b.name));
      
      return categories;
    } catch (e) {
      return [];
    }
  }

  
  Stream<List<Category>> streamActiveCategories() {
    return _col
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final categories = snapshot.docs
              .map((doc) => Category.fromFirestore(doc))
              .toList();
          
          categories.sort((a, b) => a.name.compareTo(b.name));
          
          return categories;
        });
  }

  Future<Category?> getById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) return null;
      return Category.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

 
  Future<List<Category>> getPopularCategories({int limit = 4}) async {
    try {
      final categorySnapshot = await _col
          .where('isActive', isEqualTo: true)
          .get();
      
      final categories = categorySnapshot.docs
          .map((doc) => Category.fromFirestore(doc))
          .toList();
      
     
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('isDraft', isEqualTo: false)
          .get();
      
      final Map<String, int> categoryPostCounts = {};
      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        final status = postData['status'] as String? ?? '';
        final event = postData['event'] as String? ?? '';
       
        if ((status == 'active' || status == 'completed') && event.isNotEmpty) {
          categoryPostCounts[event] = (categoryPostCounts[event] ?? 0) + 1;
        }
      }
      
      final categoriesWithCounts = categories.map((category) {
        final actualCount = categoryPostCounts[category.name] ?? 0;
        return _CategoryWithCount(category: category, count: actualCount);
      }).toList();
      
      categoriesWithCounts.sort((a, b) {
        final countComparison = b.count.compareTo(a.count);
        if (countComparison != 0) return countComparison;
        return a.category.name.compareTo(b.category.name);
      });
      
     
      return categoriesWithCounts
          .take(limit)
          .map((item) => item.category)
          .toList();
    } catch (e) {
     
      return [];
    }
  }


  Stream<List<Category>> streamPopularCategories({int limit = 4}) {
    
    return _col
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((categorySnapshot) async {
         
          final categories = categorySnapshot.docs
              .map((doc) => Category.fromFirestore(doc))
              .toList();
        
          final postsSnapshot = await _firestore
              .collection('posts')
              .where('isDraft', isEqualTo: false)
              .get();
          
          final Map<String, int> categoryPostCounts = {};
          for (final postDoc in postsSnapshot.docs) {
            final postData = postDoc.data();
            final status = postData['status'] as String? ?? '';
            final event = postData['event'] as String? ?? '';
            
            if ((status == 'active' || status == 'completed') && event.isNotEmpty) {
              categoryPostCounts[event] = (categoryPostCounts[event] ?? 0) + 1;
            }
          }
          
         
          final categoriesWithCounts = categories.map((category) {
            final actualCount = categoryPostCounts[category.name] ?? 0;
            return _CategoryWithCount(category: category, count: actualCount);
          }).toList();
          
         
          categoriesWithCounts.sort((a, b) {
            final countComparison = b.count.compareTo(a.count);
            if (countComparison != 0) return countComparison;
            return a.category.name.compareTo(b.category.name);
          });
          
        
          return categoriesWithCounts
              .take(limit)
              .map((item) => item.category)
              .toList();
        });
  }

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
  
    }
  }
}

