import 'package:flutter/material.dart';
import 'package:fyp_project/models/user_model.dart';
import 'package:fyp_project/services/user_service.dart';

class UserDetailPage extends StatelessWidget {
  final UserModel user;

  const UserDetailPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    return Scaffold(
      appBar: AppBar(title: Text(user.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                child: Text(user.name[0].toUpperCase(), style: const TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 24),
            _DetailRow(label: 'Name', value: user.name),
            _DetailRow(label: 'Email', value: user.email),
            _DetailRow(label: 'Role', value: user.role),
            if (user.phone != null) _DetailRow(label: 'Phone', value: user.phone!),
            _DetailRow(label: 'Status', value: user.isActive ? 'Active' : 'Inactive'),
            _DetailRow(
              label: 'Suspended',
              value: user.isSuspended ? 'Yes' : 'No',
            ),
            if (user.reportCount != null)
              _DetailRow(label: 'Reports', value: user.reportCount.toString()),
            _DetailRow(
              label: 'Joined',
              value: user.createdAt.toString().split(' ')[0],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!context.mounted) return;
                      try {
                        await userService.suspendUser(user.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User suspended successfully')),
                        );
                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Suspend'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!context.mounted) return;
                      
                      try {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Delete User'),
                            content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (!context.mounted) return;

                        if (confirm == true) {
                          try {
                            await userService.deleteUser(user.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User deleted successfully')),
                            );
                            if (context.mounted) {
                              Navigator.pop(context, true);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error showing dialog: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

