import 'package:flutter/material.dart';
import 'package:fyp_project/pages/post_moderation/approve_reject_posts_page.dart';
import 'package:fyp_project/pages/post_moderation/manage_tags_categories_page.dart';

class PostModerationPage extends StatelessWidget {
  const PostModerationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Post Moderation',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Container(
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
                Text(
                  'Content Management',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage job posts and categories',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          
          // Cards Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                children: [
                  _ModerationCard(
                    title: 'Approve / Reject Posts',
                    description: 'Review submitted job listings before publishing',
                    icon: Icons.assignment_turned_in,
                    iconColor: Colors.green,
                    backgroundColor: Colors.green[50]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ApproveRejectPostsPage()),
                    ),
                    stats: '12 pending',
                  ),
                  _ModerationCard(
                    title: 'Manage Tags & Categories',
                    description: 'Organize job posts by industry, type, or location',
                    icon: Icons.category,
                    iconColor: Colors.purple,
                    backgroundColor: Colors.purple[50]!,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ManageTagsCategoriesPage()),
                    ),
                    stats: '45 categories',
                  ),
                ],
              ),
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
  final String stats;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ModerationCard({
    required this.title,
    required this.description,
    required this.stats,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),
              
              const SizedBox(height: 16),
              
              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 8),
              
              // Description
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                maxLines: 3,
              ),
              
              const Spacer(),
              
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stats,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}