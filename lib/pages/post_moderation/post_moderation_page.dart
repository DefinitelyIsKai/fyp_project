import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/pages/post_moderation/approve_reject_posts_page.dart';
import 'package:fyp_project/pages/post_moderation/manage_tags_categories_page.dart';

class PostModerationPage extends StatelessWidget {
  const PostModerationPage({super.key});

  /// 🔥 Real-time stream: counts all posts with status = "pending"
  Stream<int> _pendingPostsCountStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.size);
  }

  /// 🔥 Real-time stream: counts all categories
  Stream<int> _categoryCountStream() {
    return FirebaseFirestore.instance
        .collection('categories')
        .snapshots()
        .map((snap) => snap.size);
  }

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
          // 🌟 Blue Header
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
                const Text(
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

          // 🌟 Cards
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.88, // FIX overflow for smaller screens
                children: [
                  // --- Approve / Reject Posts ---
                  StreamBuilder<int>(
                    stream: _pendingPostsCountStream(),
                    builder: (context, snapshot) {
                      final pendingCount = snapshot.data ?? 0;
                      return _ModerationCard(
                        title: 'Approve / Reject Posts',
                        description: 'Review submitted job listings before publishing',
                        icon: Icons.assignment_turned_in,
                        iconColor: Colors.green,
                        backgroundColor: Colors.green[50]!,
                        stats: '$pendingCount pending',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ApproveRejectPostsPage()),
                          );
                        },
                      );
                    },
                  ),

                  // --- Manage Tags & Categories ---
                  StreamBuilder<int>(
                    stream: _categoryCountStream(),
                    builder: (context, snapshot) {
                      final categoryCount = snapshot.data ?? 0;
                      return _ModerationCard(
                        title: 'Manage Tags & Categories',
                        description: 'Organize job posts by industry, type, or location',
                        icon: Icons.category,
                        iconColor: Colors.purple,
                        backgroundColor: Colors.purple[50]!,
                        stats: '$categoryCount categories',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ManageTagsCategoriesPage()),
                          );
                        },
                      );
                    },
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
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: iconColor),
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 6),

              // Description
              Expanded(
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stats,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[600]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}