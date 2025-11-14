import 'package:flutter/material.dart';
import 'package:fyp_project/pages/post_moderation/post_moderation_page.dart';
import 'package:fyp_project/pages/user_management/user_management_page.dart';
import 'package:fyp_project/pages/monitoring/monitoring_page.dart';
import 'package:fyp_project/pages/system_config/system_config_page.dart';
import 'package:fyp_project/pages/message_oversight/message_oversight_page.dart';
import 'package:fyp_project/pages/analytics/analytics_page.dart';
import 'package:fyp_project/services/auth_service.dart';
import 'package:fyp_project/routes/app_routes.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('JobSeek Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _DashboardCard(
            title: 'Post Moderation',
            icon: Icons.article,
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PostModerationPage()),
            ),
          ),
          _DashboardCard(
            title: 'User Management',
            icon: Icons.people,
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserManagementPage()),
            ),
          ),
          _DashboardCard(
            title: 'Monitoring & Search',
            icon: Icons.search,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MonitoringPage()),
            ),
          ),
          _DashboardCard(
            title: 'System Configuration',
            icon: Icons.settings,
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SystemConfigPage()),
            ),
          ),
          _DashboardCard(
            title: 'Message Oversight',
            icon: Icons.message,
            color: Colors.red,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessageOversightPage()),
            ),
          ),
          _DashboardCard(
            title: 'Analytics & Reporting',
            icon: Icons.analytics,
            color: Colors.teal,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

