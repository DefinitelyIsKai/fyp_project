import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/pages/monitoring/search_filter_page.dart';
import 'package:fyp_project/pages/monitoring/flagged_content_page.dart';
import 'package:fyp_project/pages/monitoring/map_oversight_page.dart';

class MonitoringPage extends StatelessWidget {
  const MonitoringPage({super.key});

  // Real-time stream: counts pending reports
  Stream<int> _pendingReportsCountStream() {
    return FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.size);
  }

  // Real-time stream: counts flagged messages
  Stream<int> _flaggedMessagesCountStream() {
    return FirebaseFirestore.instance
        .collection('messages')
        .where('status', isEqualTo: 'reported')
        .snapshots()
        .map((snap) => snap.size);
  }

  // Real-time stream: counts reported users
  Stream<int> _reportedUsersCountStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('reportCount', isGreaterThan: 0)
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
        backgroundColor: Colors.orange[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange[700],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Platform Monitoring',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
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

  // -------------------------------------------------------
  // REAL-TIME STATS
  // -------------------------------------------------------
  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
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
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<int>(
              stream: _flaggedMessagesCountStream(),
              builder: (context, snapshot) {
                final flaggedCount = snapshot.data ?? 0;
                return _StatCard(
                  title: 'Flagged Messages',
                  value: flaggedCount.toString(),
                  icon: Icons.message_outlined,
                  color: Colors.orange,
                  subtitle: 'Under review',
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<int>(
              stream: _reportedUsersCountStream(),
              builder: (context, snapshot) {
                final reportedCount = snapshot.data ?? 0;
                return _StatCard(
                  title: 'Reported Users',
                  value: reportedCount.toString(),
                  icon: Icons.person_off_outlined,
                  color: Colors.purple,
                  subtitle: 'Needs review',
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
// Reusable Stat Card
// -------------------------------------------------------
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
