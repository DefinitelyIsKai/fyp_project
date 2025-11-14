import 'package:fyp_project/models/category_model.dart';

class CategoryService {
  Future<List<CategoryModel>> getAllCategories() async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock data
    return [
      CategoryModel(
        id: '1',
        name: 'Retail',
        description: 'Retail jobs',
        createdAt: DateTime.now(),
        isActive: true,
        jobCount: 10,
      ),
      CategoryModel(
        id: '2',
        name: 'Food Service',
        description: 'Food service jobs',
        createdAt: DateTime.now(),
        isActive: true,
        jobCount: 15,
      ),
    ];
  }

  Future<void> createCategory(String name, String? description) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> updateCategory(String categoryId, String name, String? description) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> deleteCategory(String categoryId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
  }
}

