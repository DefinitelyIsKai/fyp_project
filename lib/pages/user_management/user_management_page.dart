import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/pages/user_management/view_users_page.dart';
import 'package:fyp_project/pages/user_management/user_actions_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  bool _isStatsExpanded = true;

  void _toggleStatsExpansion() {
    setState(() {
      _isStatsExpanded = !_isStatsExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Detect scroll down to collapse
          if (notification is ScrollUpdateNotification) {
            if (notification.metrics.pixels <= 0 && 
                notification.scrollDelta! > 10 && 
                _isStatsExpanded) {
              _toggleStatsExpansion();
              return true;
            }
            // Detect scroll up to expand when at top
            else if (notification.metrics.pixels <= 0 && 
                     notification.scrollDelta! < -10 && 
                     !_isStatsExpanded) {
              _toggleStatsExpansion();
              return true;
            }
          }
          return false;
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            _buildStatsSection(),
            Expanded(child: _buildOptionsGrid(context)),
          ],
        ),
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
            'User Management',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage job seekers and employer accounts',
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
  // REAL-TIME STATS with Expand/Collapse
  // -------------------------------------------------------
  Widget _buildStatsSection() {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // Expand/Collapse Header
          GestureDetector(
            onTap: _toggleStatsExpansion,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'User Statistics',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.swipe,
                        size: 16,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pull down to close',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isStatsExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[500],
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Stats Cards with Animation
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isStatsExpanded 
                ? CrossFadeState.showFirst 
                : CrossFadeState.showSecond,
            firstChild: _buildStatsCards(),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(
        children: [
          // Total Users
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return _StatCard(
                  title: 'Total Users',
                  value: count.toString(),
                  icon: Icons.people_outline,
                  color: Colors.blue,
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          // Active Today
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where(
                    'status',
                    isEqualTo: 'Active',
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return _StatCard(
                  title: 'Active Today',
                  value: count.toString(),
                  icon: Icons.online_prediction,
                  color: Colors.green,
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          // Suspended
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('status', isEqualTo: 'Suspended')
                  .snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return _StatCard(
                  title: 'Suspended',
                  value: count.toString(),
                  icon: Icons.block,
                  color: Colors.orange,
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
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            delegate: SliverChildListDelegate([
              _ManagementCard(
                title: 'View User Profiles',
                description: 'Access account information',
                icon: Icons.people_alt,
                iconColor: Colors.blue[700]!,
                backgroundColor: Colors.blue[50]!,
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ViewUsersPage()));
                },
                stats: 'View all users',
              ),
              _ManagementCard(
                title: 'Account Actions',
                description: 'Suspend, delete, or modify user accounts',
                icon: Icons.admin_panel_settings,
                iconColor: Colors.red[700]!,
                backgroundColor: Colors.red[50]!,
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const UserActionsPage()));
                },
                stats: 'Manage accounts',
              ),
              _ManagementCard(
                title: 'User Analytics',
                description: 'View user growth and engagement statistics',
                icon: Icons.analytics,
                iconColor: Colors.purple[700]!,
                backgroundColor: Colors.purple[50]!,
                onTap: () {},
                stats: 'View analytics',
              ),
              _ManagementCard(
                title: 'Bulk Operations',
                description: 'Perform batch actions on multiple users',
                icon: Icons.playlist_add_check,
                iconColor: Colors.green[700]!,
                backgroundColor: Colors.green[50]!,
                onTap: () {},
                stats: 'Bulk tools',
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------
// Reusable Management Card
// -------------------------------------------------------
class _ManagementCard extends StatelessWidget {
  final String title;
  final String description;
  final String stats;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _ManagementCard({
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
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
        ),
      ),
    );
  }
}

// -------------------------------------------------------
// Reusable Stat Card (Top Dashboard Stats)
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