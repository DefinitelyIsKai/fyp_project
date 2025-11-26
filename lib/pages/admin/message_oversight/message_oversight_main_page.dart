import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/pages/admin/message_oversight/flagged_content_page.dart';
import 'package:fyp_project/pages/admin/message_oversight/manage_ratings_page.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class MessageOversightMainPage extends StatelessWidget {
  const MessageOversightMainPage({super.key});

  // Real-time stream: counts total ratings/reviews
  Stream<int> _totalRatingsCountStream() {
    return FirebaseFirestore.instance
        .collection('reviews')
        .snapshots()
        .map((snap) => snap.size);
  }

  // Real-time stream: counts pending reports
  Stream<int> _pendingReportsCountStream() {
    return FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.size);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Message Oversight',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.cardRed,
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
                colors: [AppColors.cardRed, AppColors.error],
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
                  'Manage ratings and review flagged content',
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
              stream: _totalRatingsCountStream(),
              builder: (context, snapshot) {
                final totalRatings = snapshot.data ?? 0;
                return _StatCard(
                  title: 'Total Ratings',
                  value: totalRatings.toString(),
                  icon: Icons.star_outline,
                  color: Colors.amber,
                  subtitle: 'All reviews',
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<int>(
              stream: _pendingReportsCountStream(),
              builder: (context, snapshot) {
                final pendingCount = snapshot.data ?? 0;
                return _StatCard(
                  title: 'Pending Reports',
                  value: pendingCount.toString(),
                  icon: Icons.flag_outlined,
                  color: Colors.red,
                  subtitle: 'Requires attention',
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
          // Manage Rating Card
          _ManagementCard(
            title: 'Manage Rating',
            description: 'View and manage user ratings and reviews',
            icon: Icons.star,
            iconColor: Colors.amber[700]!,
            backgroundColor: Colors.amber[50]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageRatingsPage()),
              );
            },
            stats: 'View ratings',
            badgeCount: 0,
          ),

          // Flagged Content Card with real-time badge
          StreamBuilder<int>(
            stream: _pendingReportsCountStream(),
            builder: (context, snapshot) {
              final pendingCount = snapshot.data ?? 0;
              return _ManagementCard(
                title: 'Flagged Content',
                description: 'Monitor and review flagged content and user reports',
                icon: Icons.flag,
                iconColor: Colors.red[700]!,
                backgroundColor: Colors.red[50]!,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FlaggedContentPage()),
                  );
                },
                stats: 'Review reports',
                badgeCount: pendingCount,
              );
            },
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

// Stat Card
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

