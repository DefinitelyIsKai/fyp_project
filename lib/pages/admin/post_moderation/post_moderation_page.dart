import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/pages/admin/post_moderation/approve_reject_posts_page.dart';
import 'package:fyp_project/pages/admin/post_moderation/manage_tags_categories_page.dart';
import 'package:fyp_project/pages/admin/post_moderation/content_analytics_page.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class PostModerationPage extends StatelessWidget {
  const PostModerationPage({super.key});

  Stream<int> _pendingPostsCountStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          
          int count = 0;
          for (final doc in snap.docs) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;
            final isDraft = data['isDraft'] as bool?;
            
            if (isDraft != true) {
              count++;
            }
          }
          return count;
        });
  }

  Stream<int> _categoryCountStream() {
    return FirebaseFirestore.instance
        .collection('categories')
        .snapshots()
        .map((snap) => snap.size);
  }

  Stream<int> _rejectedPostsCountStream() {
    return FirebaseFirestore.instance
        .collection('posts')
        .where('status', isEqualTo: 'rejected')
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
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
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

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primaryMedium],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          
          Expanded(
            child: SizedBox(
              height: 120, 
              child: StreamBuilder<int>(
                stream: _pendingPostsCountStream(),
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data ?? 0;
                  return _StatCard(
                    title: 'Pending',
                    value: pendingCount.toString(),
                    icon: Icons.article_outlined,
                    color: Colors.orange,
                  );
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: SizedBox(
              height: 120,
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
          ),

          const SizedBox(width: 12),

          Expanded(
            child: SizedBox(
              height: 120,
              child: StreamBuilder<int>(
                stream: _rejectedPostsCountStream(),
                builder: (context, snapshot) {
                  final rejectedCount = snapshot.data ?? 0;
                  return _StatCard(
                    title: 'Rejected',
                    value: rejectedCount.toString(),
                    icon: Icons.cancel_outlined,
                    color: Colors.red,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        ],
      ),
    );
  }
}

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
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 28, color: iconColor),
                  ),

                  const SizedBox(height: 12),

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
          mainAxisSize: MainAxisSize.min,
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