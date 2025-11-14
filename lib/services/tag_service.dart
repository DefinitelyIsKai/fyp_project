import 'package:fyp_project/models/tag_model.dart';

class TagService {
  Future<List<TagModel>> getAllTags() async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock data
    return [
      TagModel(
        id: '1',
        name: 'part-time',
        category: 'General',
        createdAt: DateTime.now(),
        isActive: true,
        usageCount: 50,
      ),
      TagModel(
        id: '2',
        name: 'remote',
        category: 'General',
        createdAt: DateTime.now(),
        isActive: true,
        usageCount: 30,
      ),
    ];
  }

  Future<void> createTag(String name, {String? category}) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> updateTagStatus(String tagId, bool isActive) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> deleteTag(String tagId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
  }
}

