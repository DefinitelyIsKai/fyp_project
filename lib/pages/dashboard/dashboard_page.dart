import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fyp_project/pages/post_moderation/post_moderation_page.dart';
import 'package:fyp_project/pages/user_management/user_management_page.dart';
import 'package:fyp_project/pages/monitoring/monitoring_page.dart';
import 'package:fyp_project/pages/system_config/system_config_page.dart';
import 'package:fyp_project/pages/message_oversight/message_oversight_page.dart';
import 'package:fyp_project/pages/analytics/analytics_page.dart';
import 'package:fyp_project/services/auth_service.dart';
import 'package:fyp_project/services/dashboard_service.dart';
import 'package:fyp_project/routes/app_routes.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService _dashboardService = DashboardService();

  int _pendingPosts = 0;
  int _activeUsers = 0;
  int _messages = 0;
  bool _isLoading = true;

  // Role-based page access
  // Note: This is a fallback. The permission system in auth_service should be the source of truth.
  final Map<String, List<String>> roleAccess = {
    'manager': [
      'Post Moderation',
      'User Management',
      'Monitoring & Search',
      'System Configuration',
      'Message Oversight',
      'Analytics & Reporting',
    ],
    'hr': [
      'Post Moderation',
      'User Management',
      'Monitoring & Search',
      'Analytics & Reporting',
    ],
    'staff': [
      'Post Moderation',
      'User Management',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final posts = await _dashboardService.getPendingPostsCount();
      final users = await _dashboardService.getActiveUsersCount();
      final messages = await _dashboardService.getMessagesCount();

      if (mounted) {
        setState(() {
          _pendingPosts = posts;
          _activeUsers = users;
          _messages = messages;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final role = authService.currentAdmin?.role.toLowerCase() ?? 'staff';
    final allowedPages = roleAccess[role] ?? [];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('JobSeek Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await authService.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderSection(),
                _buildStatsSection(),
                Expanded(child: _buildDashboardGrid(allowedPages)),
              ],
            ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue[700],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome back!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Here\'s what\'s happening today',
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9))),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: 'Pending Posts',
              value: _pendingPosts.toString(),
              color: Colors.orange,
              icon: Icons.article,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: 'Active Users',
              value: _activeUsers.toString(),
              color: Colors.green,
              icon: Icons.people,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              title: 'Messages',
              value: _messages.toString(),
              color: Colors.purple,
              icon: Icons.message,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid(List<String> allowedPages) {
    final cards = [
      _DashboardCard(
        title: 'Post Moderation',
        icon: Icons.article,
        color: Colors.blue[700]!,
        subtitle: '$_pendingPosts pending reviews',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostModerationPage()),
        ),
      ),
      _DashboardCard(
        title: 'User Management',
        icon: Icons.people_alt,
        color: Colors.green[700]!,
        subtitle: '$_activeUsers active users',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserManagementPage()),
        ),
      ),
      _DashboardCard(
        title: 'Monitoring & Search',
        icon: Icons.search,
        color: Colors.orange[700]!,
        subtitle: 'Monitor activities',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MonitoringPage()),
        ),
      ),
      _DashboardCard(
        title: 'System Configuration',
        icon: Icons.settings,
        color: Colors.purple[700]!,
        subtitle: 'System settings',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SystemConfigPage()),
        ),
      ),
      _DashboardCard(
        title: 'Message Oversight',
        icon: Icons.chat_bubble,
        color: Colors.red[700]!,
        subtitle: '$_messages messages',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MessageOversightPage()),
        ),
      ),
      _DashboardCard(
        title: 'Analytics & Reporting',
        icon: Icons.analytics,
        color: Colors.teal[700]!,
        subtitle: 'View reports',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnalyticsPage()),
        ),
      ),
    ];

    // Filter cards based on role
    final filteredCards = cards.where((c) => allowedPages.contains(c.title)).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
        children: filteredCards,
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
