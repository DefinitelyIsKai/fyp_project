import 'package:flutter/material.dart';
import 'package:fyp_project/pages/post_moderation/approve_reject_posts_page.dart';
import 'package:fyp_project/pages/post_moderation/manage_tags_categories_page.dart';

class PostModerationPage extends StatelessWidget {
  const PostModerationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Moderation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ModerationCard(
            title: 'Approve / Reject Posts',
            description: 'Review submitted job listings before publishing',
            icon: Icons.check_circle_outline,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ApproveRejectPostsPage()),
            ),
          ),
          const SizedBox(height: 16),
          _ModerationCard(
            title: 'Manage Tags & Categories',
            description: 'Organize job posts by industry, type, or location',
            icon: Icons.category,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageTagsCategoriesPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ModerationCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}

