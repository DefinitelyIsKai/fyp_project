import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/pages/admin/user_management/view_users_page.dart';
import 'package:fyp_project/pages/admin/user_management/user_actions_page.dart';
import 'package:fyp_project/pages/admin/user_management/user_analytics_page.dart';
import 'package:fyp_project/pages/admin/user_management/wallet_management_page.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

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

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          
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

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('verificationStatus', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return _StatCard(
                  title: 'Pending Verify',
                  value: count.toString(),
                  icon: Icons.verified_user_outlined,
                  color: Colors.orange,
                );
              },
            ),
          ),

          const SizedBox(width: 12),

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

  Widget _buildOptionsGrid(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentAdmin = authService.currentAdmin;
    final userRole = currentAdmin?.role.toLowerCase() ?? '';

    final cards = <Widget>[
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
      Builder(
        builder: (context) {
          final authService = Provider.of<AuthService>(context, listen: false);
          final currentAdmin = authService.currentAdmin;
          final canAccessAnalytics = currentAdmin != null && 
              (currentAdmin.permissions.contains('all') || 
               currentAdmin.permissions.contains('analytics'));
          
          if (!canAccessAnalytics) {
            return const SizedBox.shrink();
          }
          
          return _ManagementCard(
            title: 'User Analytics',
            description: 'View user growth and engagement statistics',
            icon: Icons.analytics,
            iconColor: Colors.purple[700]!,
            backgroundColor: Colors.purple[50]!,
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const UserAnalyticsPage()));
            },
            stats: 'View Analytics',
          );
        },
      ),
    ];

    if (userRole != 'staff') {
      cards.add(
        _ManagementCard(
          title: 'Wallet Management',
          description: 'Manage user wallet balances and transactions',
          icon: Icons.account_balance_wallet,
          iconColor: Colors.teal[700]!,
          backgroundColor: Colors.teal[50]!,
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WalletManagementPage()));
          },
          stats: 'Manage wallets',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        children: cards,
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