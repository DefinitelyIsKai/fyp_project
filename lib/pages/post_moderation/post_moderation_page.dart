import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/pages/post_moderation/approve_reject_posts_page.dart';
import 'package:fyp_project/pages/post_moderation/manage_tags_categories_page.dart';
import 'package:fyp_project/pages/post_moderation/content_analytics_page.dart';
import 'package:fyp_project/pages/post_moderation/bulk_actions_page.dart';

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
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(),
          _buildStatsSection(),
          Expanded(child: _buildOptionsGrid(context)),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Header
  // -------------------------------------------------------
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
          const Text(
            'Post Moderation',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage job posts and organize content efficiently',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // REAL-TIME STATS
  // -------------------------------------------------------
  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          // Pending Posts
          Expanded(
            child: StreamBuilder<int>(
              stream: _pendingPostsCountStream(),
              builder: (context, snapshot) {
                final pendingCount = snapshot.data ?? 0;
                return _StatCard(
                  title: 'Pending Posts',
                  value: pendingCount.toString(),
                  icon: Icons.article_outlined,
                  color: Colors.orange,
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          // Total Categories
          Expanded(
            child: StreamBuilder<int>(
              stream: _categoryCountStream(),
              builder: (context, snapshot) {
                final categoryCount = snapshot.data ?? 0;
                return _StatCard(
                  title: 'Categories',
                  value: categoryCount.toString(),
                  icon: Icons.category,
                  color: Colors.purple,
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          // Approved Posts
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('status', isEqualTo: 'approved')
                  .snapshots(),
              builder: (context, snapshot) {
                final approvedCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return _StatCard(
                  title: 'Approved',
                  value: approvedCount.toString(),
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Grid options
  // -------------------------------------------------------
  Widget _buildOptionsGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        children: [
          // Review Job Posts Card with StreamBuilder for badge
          StreamBuilder<int>(
            stream: _pendingPostsCountStream(),
            builder: (context, snapshot) {
              final pendingCount = snapshot.data ?? 0;
              return _ManagementCard(
                title: 'Review Job Posts',
                description: 'Approve or reject pending job listings',
                icon: Icons.assignment_turned_in,
                iconColor: Colors.blue[700]!,
                backgroundColor: Colors.blue[50]!,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ApproveRejectPostsPage()),
                  );
                },
                stats: 'Manage posts',
                badgeCount: pendingCount,
              );
            },
          ),

          _ManagementCard(
            title: 'Organize Content',
            description: 'Manage categories and tags for better organization',
            icon: Icons.category,
            iconColor: Colors.purple[700]!,
            backgroundColor: Colors.purple[50]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageTagsCategoriesPage()),
              );
            },
            stats: 'Manage categories',
            badgeCount: 0,
          ),
          _ManagementCard(
            title: 'Content Analytics',
            description: 'View post performance and engagement statistics',
            icon: Icons.analytics,
            iconColor: Colors.teal[700]!,
            backgroundColor: Colors.teal[50]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ContentAnalyticsPage(),
                ),
              );
            },
            stats: 'View analytics',
            badgeCount: 0,
          ),
          _ManagementCard(
            title: 'Bulk Actions',
            description: 'Perform batch operations on multiple posts',
            icon: Icons.playlist_add_check,
            iconColor: Colors.green[700]!,
            backgroundColor: Colors.green[50]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BulkActionsPage(),
                ),
              );
            },
            stats: 'Bulk tools',
            badgeCount: 0,
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------
// Reusable Management Card (Updated with badge support)
// -------------------------------------------------------
class _ManagementCard extends StatelessWidget {
  final String title;
  final String description;
  final String stats;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;
  final int badgeCount;

  const _ManagementCard({
    required this.title,
    required this.description,
    required this.stats,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon with badge
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
                  SizedBox(
                    height: 40,
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Description
                  Expanded(
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stats,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ],
              ),

              // Badge in top-right corner
              if (badgeCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------
// Reusable Stat Card (Same as User Management)
// -------------------------------------------------------
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}