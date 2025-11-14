import 'package:fyp_project/models/job_post_model.dart';

class PostService {
  Future<List<JobPostModel>> getPendingPosts() async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock data
    return [
      JobPostModel(
        id: '1',
        employerId: 'emp1',
        title: 'Senior React Developer',
        description: 'Looking for an experienced React developer...',
        category: 'Technology',
        tags: ['react', 'javascript', 'frontend'],
        location: 'San Francisco',
        salary: 120000.0,
        salaryType: 'monthly',
        postedAt: DateTime.now().subtract(const Duration(days: 2)),
        status: JobPostStatus.pending,
        applicationCount: 5,
        viewCount: 20,
        submitterName: 'John Smith',
        submitterId: 'user1',
      ),
      JobPostModel(
        id: '2',
        employerId: 'emp2',
        title: 'Marketing Manager',
        description: 'Seeking a creative marketing manager...',
        category: 'Marketing',
        tags: ['marketing', 'management'],
        location: 'New York',
        salary: 80000.0,
        salaryType: 'monthly',
        postedAt: DateTime.now().subtract(const Duration(days: 1)),
        status: JobPostStatus.pending,
        applicationCount: 3,
        viewCount: 15,
        submitterName: 'Sarah Johnson',
        submitterId: 'user2',
      ),
      JobPostModel(
        id: '3',
        employerId: 'emp3',
        title: 'Data Scientist',
        description: 'Join our data science team...',
        category: 'Technology',
        tags: ['data', 'python', 'ml'],
        location: 'Seattle',
        salary: 130000.0,
        salaryType: 'monthly',
        postedAt: DateTime.now().subtract(const Duration(days: 3)),
        status: JobPostStatus.pending,
        applicationCount: 8,
        viewCount: 30,
        submitterName: 'Mike Chen',
        submitterId: 'user3',
      ),
    ];
  }

  Future<List<JobPostModel>> getApprovedPosts() async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  Future<List<JobPostModel>> getRejectedPosts() async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  Future<List<JobPostModel>> searchPosts(String query) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  Future<void> approvePost(String postId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> rejectPost(String postId, String reason) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
  }
}

