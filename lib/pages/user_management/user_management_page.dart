import 'package:flutter/material.dart';
import 'package:fyp_project/pages/user_management/view_users_page.dart';
import 'package:fyp_project/pages/user_management/user_actions_page.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.people, size: 40),
              title: const Text('View User Profiles', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Access account information for job seekers and employers'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewUsersPage()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.block, size: 40),
              title: const Text('Suspend / Delete Accounts', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Take action on accounts in cases of abuse or policy violation'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserActionsPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

