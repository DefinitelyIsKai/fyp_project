import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/pages/post_moderation/approve_reject_posts_page.dart';
import 'package:fyp_project/pages/post_moderation/manage_tags_categories_page.dart';

class PostModerationPage extends StatelessWidget {
  const PostModerationPage({super.key});

  // Real-time stream: counts all posts with status = "pending"
  Stream<int> _pendingPostsCountStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.size);
  }

  // Real-time stream: counts all categories
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
          // Enhanced Header with better spacing
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue[800]!.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome message
                const Text(
                  'Content Management',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage job posts and organize content efficiently',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Quick stats row
                Row(
                  children: [
                    StreamBuilder<int>(
                      stream: _pendingPostsCountStream(),
                      builder: (context, snapshot) {
                        final pendingCount = snapshot.data ?? 0;
                        return _HeaderStat(
                          value: pendingCount,
                          label: 'Pending Posts',
                          color: Colors.orange[400]!,
                        );
                      },
                    ),
                    const SizedBox(width: 20),
                    StreamBuilder<int>(
                      stream: _categoryCountStream(),
                      builder: (context, snapshot) {
                        final categoryCount = snapshot.data ?? 0;
                        return _HeaderStat(
                          value: categoryCount,
                          label: 'Categories',
                          color: Colors.purple[300]!,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Title
                  const Text(
                    'Management Tools',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose an option to manage your content',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Single column layout for better focus
                  Expanded(
                    child: ListView(
                      children: [
                        // Approve/Reject Posts Card
                        StreamBuilder<int>(
                          stream: _pendingPostsCountStream(),
                          builder: (context, snapshot) {
                            final pendingCount = snapshot.data ?? 0;
                            return _FeatureCard(
                              title: 'Review Job Posts',
                              subtitle: 'Approve or reject pending job listings',
                              icon: Icons.assignment_turned_in,
                              iconColor: Colors.green[700]!,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.green[50]!,
                                  Colors.lightGreen[50]!,
                                ],
                              ),
                              badgeCount: pendingCount,
                              badgeColor: Colors.orange,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ApproveRejectPostsPage()),
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // Manage Tags & Categories Card
                        StreamBuilder<int>(
                          stream: _categoryCountStream(),
                          builder: (context, snapshot) {
                            final categoryCount = snapshot.data ?? 0;
                            return _FeatureCard(
                              title: 'Organize Content',
                              subtitle: 'Manage categories and tags for better organization',
                              icon: Icons.category,
                              iconColor: Colors.purple[700]!,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.purple[50]!,
                                  Colors.deepPurple[50]!,
                                ],
                              ),
                              badgeCount: categoryCount,
                              badgeColor: Colors.purple,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _HeaderStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
                height: 0.9,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label.split(' ').first,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label.split(' ').skip(1).join(' '),
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Gradient gradient;
  final int badgeCount;
  final Color badgeColor;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.gradient,
    required this.badgeCount,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: iconColor,
                ),
              ),

              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Badge and Arrow
              Column(
                children: [
                  if (badgeCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
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