import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/pages/admin/monitoring/search_filter_page.dart';
import 'package:fyp_project/pages/admin/monitoring/map_oversight_page.dart';
import 'package:fyp_project/pages/admin/monitoring/admin_logs_page.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class MonitoringPage extends StatelessWidget {
  const MonitoringPage({super.key});

  // Real-time stream: counts total posts (excluding drafts)
  Stream<int> _totalPostsCountStream() {
    return FirebaseFirestore.instance
        .collection('posts')
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

  // Real-time stream: counts total users
  Stream<int> _totalUsersCountStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((snap) => snap.size);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monitoring & Search',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.cardOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.cardOrange, Color(0xFFFF6F00)],
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
                  'Real-time monitoring of platform activity and content moderation',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Real-time Stats Section
          _buildStatsSection(),

          // Main Options Grid
          Expanded(child: _buildOptionsGrid(context)),
        ],
      ),
    );
  }

  // REAL-TIME STATS
  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<int>(
              stream: _totalPostsCountStream(),
              builder: (context, snapshot) {
                final totalPosts = snapshot.data ?? 0;
                return _StatCard(
                  title: 'Total Posts',
                  value: totalPosts.toString(),
                  icon: Icons.work_outline,
                  color: Colors.blue,
                  subtitle: 'All job posts',
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<int>(
              stream: _totalUsersCountStream(),
              builder: (context, snapshot) {
                final totalUsers = snapshot.data ?? 0;
                return _StatCard(
                  title: 'Total Users',
                  value: totalUsers.toString(),
                  icon: Icons.people_outline,
                  color: Colors.green,
                  subtitle: 'All registered users',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Grid options
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
          // Search & Filter Card
          _ManagementCard(
                title: 'Search & Filter',
                description: 'Search users and posts by keywords, category, or status',
                icon: Icons.search,
                iconColor: Colors.blue[700]!,
                backgroundColor: Colors.blue[50]!,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchFilterPage()),
                  );
                },
                stats: 'Quick search',
                badgeCount: 0,
              ),

          // Map Oversight Card
          _ManagementCard(
            title: 'Map Oversight',
            description: 'Visualize users and job posts on an interactive map',
            icon: Icons.map,
            iconColor: Colors.green[700]!,
            backgroundColor: Colors.green[50]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapOversightPage()),
              );
            },
            stats: 'View on map',
            badgeCount: 0,
          ),

          // Admin Logs Card
          _ManagementCard(
            title: 'Admin Logs',
            description: 'View all admin activity logs and system actions',
            icon: Icons.description,
            iconColor: Colors.orange[700]!,
            backgroundColor: Colors.orange[50]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLogsPage()),
              );
            },
            stats: 'View logs',
            badgeCount: 0,
          ),
        ],
      ),
    );
  }
}

// Management Card
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

//  Stat Card
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
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
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
