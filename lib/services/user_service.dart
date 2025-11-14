import 'package:fyp_project/models/user_model.dart';

class UserService {
  Future<List<UserModel>> getAllUsers() async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock data
    return [
      UserModel(
        id: '1',
        email: 'user@example.com',
        name: 'John Doe',
        role: 'job_seeker',
        phone: '123-456-7890',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        isActive: true,
        isSuspended: false,
        reportCount: 0,
      ),
      UserModel(
        id: '2',
        email: 'employer@example.com',
        name: 'Jane Smith',
        role: 'employer',
        phone: '098-765-4321',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        isActive: true,
        isSuspended: false,
        reportCount: 2,
      ),
    ];
  }

  Future<List<UserModel>> searchUsers(String query) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  Future<List<UserModel>> getSuspendedUsers() async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  Future<List<UserModel>> getReportedUsers() async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock reported users for testing
    return [
      UserModel(
        id: '3',
        email: 'reported@example.com',
        name: 'Reported User',
        role: 'job_seeker',
        phone: '555-1234',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        isActive: true,
        isSuspended: false,
        reportCount: 5,
      ),
      UserModel(
        id: '4',
        email: 'abusive@example.com',
        name: 'Abusive Employer',
        role: 'employer',
        phone: '555-5678',
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        isActive: true,
        isSuspended: false,
        reportCount: 12,
      ),
    ];
  }

  Future<void> suspendUser(String userId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> unsuspendUser(String userId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> deleteUser(String userId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
  }
}

