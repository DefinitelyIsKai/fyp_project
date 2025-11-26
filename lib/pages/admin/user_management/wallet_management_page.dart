import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:fyp_project/services/admin/reward_service.dart';
import 'package:fyp_project/services/user/notification_service.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:intl/intl.dart';

class WalletManagementPage extends StatefulWidget {
  const WalletManagementPage({super.key});

  @override
  State<WalletManagementPage> createState() => _WalletManagementPageState();
}

class _WalletManagementPageState extends State<WalletManagementPage> {
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();
  final RewardService _rewardService = RewardService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryLight,
      appBar: AppBar(
        title: const Text(
          'Wallet Management',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.card_giftcard, size: 22),
            onPressed: () => _showRewardSystemDialog(),
            tooltip: 'Monthly Rewards',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: () {
              setState(() {});
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with Stats
          _buildHeaderSection(),
          
          // Search Bar
          _buildSearchSection(),

          // Wallets List
          Expanded(
            child: _buildWalletsList(),
          ),
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
          colors: [
            AppColors.primaryDark,
            AppColors.primaryDark.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet Balance Overview',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('wallets').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Text(
                            'Loading wallets...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          );
                        }

                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: _getNonAdminWallets(snapshot.data!.docs),
                          builder: (context, walletSnapshot) {
                            if (walletSnapshot.connectionState == ConnectionState.waiting) {
                              return Text(
                                'Calculating...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              );
                            }

                            final nonAdminWallets = walletSnapshot.data ?? [];
                            double totalBalance = 0;
                            int positiveCount = 0;
                            int negativeCount = 0;

                            for (final wallet in nonAdminWallets) {
                              final balance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
                              totalBalance += balance;
                              if (balance >= 0) {
                                positiveCount++;
                              } else {
                                negativeCount++;
                              }
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${nonAdminWallets.length} Wallets',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${totalBalance.toStringAsFixed(0)} Credits',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: Colors.green[300],
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.green.withOpacity(0.5),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$positiveCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: Colors.red[300],
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.red.withOpacity(0.5),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '$negativeCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by name or email...',
            prefixIcon: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.search, color: AppColors.primaryDark, size: 20),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.clear, size: 18, color: Colors.grey),
                    ),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
          },
        ),
      ),
    );
  }

  Widget _buildWalletsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wallets')
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final wallets = snapshot.data?.docs ?? [];
        
        if (wallets.isEmpty) {
          return _buildEmptyState();
        }

        return FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _filterNonAdminWallets(wallets),
          builder: (context, filteredSnapshot) {
            if (filteredSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            final nonAdminWallets = filteredSnapshot.data ?? [];
            
            if (nonAdminWallets.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: nonAdminWallets.length,
              itemBuilder: (context, index) {
                final walletDoc = nonAdminWallets[index];
                return _buildWalletCard(walletDoc);
              },
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getNonAdminWallets(List<QueryDocumentSnapshot> wallets) async {
    final nonAdminWallets = <Map<String, dynamic>>[];
    
    for (final wallet in wallets) {
      final walletData = wallet.data() as Map<String, dynamic>;
      final userId = walletData['userId'] as String? ?? wallet.id;
      
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          final role = userData?['role'] as String?;
          
          // Exclude admin roles (manager, hr, staff)
          if (role != 'manager' && role != 'hr' && role != 'staff') {
            nonAdminWallets.add(walletData);
          }
        }
      } catch (e) {
        debugPrint('Error checking user role for wallet $userId: $e');
      }
    }
    
    return nonAdminWallets;
  }

  Future<List<QueryDocumentSnapshot>> _filterNonAdminWallets(List<QueryDocumentSnapshot> wallets) async {
    final walletUserPairs = <Map<String, dynamic>>[];
    
    for (final wallet in wallets) {
      final walletData = wallet.data() as Map<String, dynamic>;
      final userId = walletData['userId'] as String? ?? wallet.id;
      
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          final role = userData?['role'] as String?;
          
          // Exclude admin roles (manager, hr, staff)
          if (role != 'manager' && role != 'hr' && role != 'staff') {
            final userName = userData?['fullName'] as String? ?? 'Unknown User';
            walletUserPairs.add({
              'wallet': wallet,
              'userName': userName,
            });
          }
        }
      } catch (e) {
        debugPrint('Error checking user role for wallet $userId: $e');
      }
    }
    
    // Sort by user name alphabetically
    walletUserPairs.sort((a, b) => 
      (a['userName'] as String).toLowerCase().compareTo((b['userName'] as String).toLowerCase())
    );
    
    // Return only the wallets in sorted order
    return walletUserPairs.map((pair) => pair['wallet'] as QueryDocumentSnapshot).toList();
  }

  Widget _buildWalletCard(QueryDocumentSnapshot walletDoc) {
    final walletData = walletDoc.data() as Map<String, dynamic>;
    final userId = walletData['userId'] as String? ?? walletDoc.id;
    final balance = (walletData['balance'] as num?)?.toDouble() ?? 0.0;
    final updatedAt = walletData['updatedAt'] as Timestamp?;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildWalletCardSkeleton();
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final userName = userData?['fullName'] ?? 'Unknown User';
        final userEmail = userData?['email'] ?? 'No email';

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          if (!userName.toLowerCase().contains(query) &&
              !userEmail.toLowerCase().contains(query)) {
            return const SizedBox.shrink();
          }
        }

        final userRole = userData?['role'] as String? ?? 'user';
        final initials = _getInitials(userName);
        final isPositive = balance >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            elevation: 0,
            borderRadius: BorderRadius.circular(16),
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                border: Border.all(
                  color: isPositive ? Colors.green[100]! : Colors.red[100]!,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // User Avatar with Initials
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isPositive
                                ? [Colors.green[400]!, Colors.green[600]!]
                                : [Colors.red[400]!, Colors.red[600]!],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: (isPositive ? Colors.green : Colors.red).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // User Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    userName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(userRole).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    userRole.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _getRoleColor(userRole),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.email_outlined, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    userEmail,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (updatedAt != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Updated ${_formatTimeAgo(updatedAt.toDate())}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Balance and Actions
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isPositive
                                    ? [Colors.green[50]!, Colors.green[100]!]
                                    : [Colors.red[50]!, Colors.red[100]!],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPositive ? Colors.green[200]! : Colors.red[200]!,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${balance.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isPositive ? Colors.green[800] : Colors.red[800],
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'credits',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isPositive ? Colors.green[700] : Colors.red[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildActionButton(
                                icon: Icons.add_circle_outline,
                                color: Colors.green,
                                onTap: () => _showAddCreditDialog(userId, userName, balance),
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                icon: Icons.remove_circle_outline,
                                color: Colors.red,
                                onTap: () => _showDeductCreditDialog(userId, userName, balance),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color == Colors.green ? Colors.green[700]! : Colors.red[700]!,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'jobseeker':
        return Colors.blue;
      case 'recruiter':
        return Colors.purple;
      case 'manager':
        return Colors.orange;
      case 'hr':
        return Colors.teal;
      case 'staff':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildWalletCardSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 180,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Loading State
  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => _buildWalletCardSkeleton(),
    );
  }

  // Error State
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Unable to Load Wallets',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Wallets Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'There are no wallet accounts created yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    return DateFormat('dd MMM yyyy').format(date);
  }

  void _showAddCreditDialog(String userId, String userName, double currentBalance) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    bool isLoading = false;
    String? amountError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_circle, color: Colors.green[700], size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Add Credit',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'User: $userName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Current Balance: RM ${currentBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                enabled: !isLoading,
                onChanged: (value) {
                  if (amountError != null) {
                    setDialogState(() => amountError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Amount (RM) *',
                  hintText: 'Enter amount to add',
                  prefixIcon: Icon(
                    Icons.attach_money,
                    color: amountError != null ? Colors.red : Colors.green,
                  ),
                  errorText: amountError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: amountError != null ? Colors.red : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: amountError != null ? Colors.red : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: amountError != null ? Colors.red : Colors.green,
                      width: 2,
                    ),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  focusedErrorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  filled: true,
                  fillColor: amountError != null ? Colors.red[50] : Colors.grey[50],
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                enabled: !isLoading,
                decoration: InputDecoration(
                  labelText: 'Reason (Optional)',
                  hintText: 'Enter reason for adding credit',
                  prefixIcon: const Icon(Icons.note, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 3,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final amountText = amountController.text.trim();

                              // Reset errors
                              amountError = null;

                              // Validate amount
                              if (amountText.isEmpty) {
                                setDialogState(() {
                                  amountError = 'Please enter an amount';
                                });
                                return;
                              }

                              final amount = double.tryParse(amountText);
                              if (amount == null || amount <= 0) {
                                setDialogState(() {
                                  amountError = 'Please enter a valid amount greater than 0';
                                });
                                return;
                              }

                              isLoading = true;
                              setDialogState(() {});

                              Navigator.pop(context);
                              await _addCredit(userId, amount, reasonController.text, userName);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Add Credit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showDeductCreditDialog(String userId, String userName, double currentBalance) {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    bool isLoading = false;
    String? amountError;
    String? reasonError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.remove_circle, color: Colors.red[700], size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Deduct Credit',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'User: $userName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Current Balance: RM ${currentBalance.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              if (currentBalance < 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[700], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'User has negative balance',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                enabled: !isLoading,
                onChanged: (value) {
                  if (amountError != null) {
                    setDialogState(() => amountError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Amount (RM) *',
                  hintText: 'Enter amount to deduct',
                  prefixIcon: Icon(
                    Icons.attach_money,
                    color: amountError != null ? Colors.red : Colors.red,
                  ),
                  errorText: amountError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: amountError != null ? Colors.red : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: amountError != null ? Colors.red : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: amountError != null ? Colors.red : Colors.red,
                      width: 2,
                    ),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  focusedErrorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  filled: true,
                  fillColor: amountError != null ? Colors.red[50] : Colors.grey[50],
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                enabled: !isLoading,
                onChanged: (value) {
                  if (reasonError != null) {
                    setDialogState(() => reasonError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Reason (Required) *',
                  hintText: 'Enter reason for deducting credit',
                  prefixIcon: Icon(
                    Icons.note,
                    color: reasonError != null ? Colors.red : Colors.red,
                  ),
                  errorText: reasonError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: reasonError != null ? Colors.red : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: reasonError != null ? Colors.red : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: reasonError != null ? Colors.red : Colors.red,
                      width: 2,
                    ),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  focusedErrorBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                  filled: true,
                  fillColor: reasonError != null ? Colors.red[50] : Colors.grey[50],
                ),
                maxLines: 3,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final amountText = amountController.text.trim();
                              final reasonText = reasonController.text.trim();

                              // Reset errors
                              amountError = null;
                              reasonError = null;

                              // Validate amount
                              if (amountText.isEmpty) {
                                setDialogState(() {
                                  amountError = 'Please enter an amount';
                                });
                                return;
                              }

                              final amount = double.tryParse(amountText);
                              if (amount == null || amount <= 0) {
                                setDialogState(() {
                                  amountError = 'Please enter a valid amount greater than 0';
                                });
                                return;
                              }

                              // Validate reason
                              if (reasonText.isEmpty) {
                                setDialogState(() {
                                  reasonError = 'Please enter a reason';
                                });
                                return;
                              }

                              isLoading = true;
                              setDialogState(() {});

                              Navigator.pop(context);
                              await _deductCredit(userId, amount, reasonText);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Deduct Credit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _addCredit(String userId, double amount, String reason, String userName) async {
    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              const SizedBox(height: 16),
              Text(
                'Adding credit...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we process your request',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      setState(() => _isLoading = true);

      // Get current admin user ID for logging
      final currentAdminId = FirebaseAuth.instance.currentUser?.uid;
      
      // Get user info for logging and notifications
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final userName = userData?['fullName'] ?? 'Unknown User';

      final walletRef = FirebaseFirestore.instance.collection('wallets').doc(userId);
      final transactionsRef = walletRef.collection('transactions');
      final txnRef = transactionsRef.doc();
      
      // Ensure wallet exists first
      final walletDoc = await walletRef.get();
      if (!walletDoc.exists) {
        await walletRef.set({
          'userId': userId,
          'balance': 0,
          'heldCredits': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Use Firestore transaction to atomically update balance and create transaction record
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(walletRef);
        final data = snap.data() ?? <String, dynamic>{'balance': 0};
        final int current = (data['balance'] as num?)?.toInt() ?? 0;
        final int amountInt = amount.toInt();
        final int next = current + amountInt;
        
        // Update wallet balance
        tx.update(walletRef, {
          'balance': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Create transaction record in subcollection
        tx.set(txnRef, {
          'id': txnRef.id,
          'userId': userId,
          'type': 'credit',
          'amount': amountInt,
          'description': reason.isEmpty ? 'Credit added by admin' : reason,
          'createdAt': FieldValue.serverTimestamp(),
          'referenceId': null,
        });
      });

      // Get final balance for logging
      final finalWalletDoc = await walletRef.get();
      final finalData = finalWalletDoc.data();
      final finalBalance = (finalData?['balance'] as num?)?.toDouble() ?? 0.0;
      final previousBalance = finalBalance - amount;

      // Create log entry
      try {
        await FirebaseFirestore.instance.collection('logs').add({
          'actionType': 'add_credit',
          'userId': userId,
          'userName': userName,
          'amount': amount,
          'previousBalance': previousBalance,
          'newBalance': finalBalance,
          'reason': reason.isEmpty ? 'Credit added by admin' : reason,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentAdminId,
        });
      } catch (logError) {
        debugPrint('Error creating log entry: $logError');
      }

      // Send notification to user
      try {
        await _notificationService.notifyWalletCredit(
          userId: userId,
          amount: amount.toInt(),
          reason: reason.isEmpty ? 'Credit added by admin' : reason,
        );
      } catch (notifError) {
        debugPrint('Error sending notification: $notifError');
        // Don't fail the operation if notification fails
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        // Get final balance for display
        final displayWalletDoc = await walletRef.get();
        final displayData = displayWalletDoc.data();
        final displayBalance = (displayData?['balance'] as num?)?.toDouble() ?? 0.0;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Successfully added ${amount.toInt()} credits to $userName. New balance: ${displayBalance.toInt()} credits',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deductCredit(String userId, double amount, String reason) async {
    try {
      setState(() => _isLoading = true);

      final result = await _userService.deductCredit(
        userId: userId,
        amount: amount,
        reason: reason,
      );

      if (result['success'] == true) {
        // Send notification to user
        try {
          await _notificationService.notifyWalletDebit(
            userId: userId,
            amount: amount.toInt(),
            reason: reason,
          );
        } catch (notifError) {
          debugPrint('Error sending notification: $notifError');
          // Don't fail the operation if notification fails
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Successfully deducted RM ${amount.toStringAsFixed(2)}. New balance: RM ${result['newBalance'].toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Error: ${result['error']}')),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRewardSystemDialog() {
    showDialog(
      context: context,
      builder: (context) => _RewardSystemDialog(
        rewardService: _rewardService,
        notificationService: _notificationService,
      ),
    );
  }
}

class _RewardSystemDialog extends StatefulWidget {
  final RewardService rewardService;
  final NotificationService notificationService;

  const _RewardSystemDialog({
    required this.rewardService,
    required this.notificationService,
  });

  @override
  State<_RewardSystemDialog> createState() => _RewardSystemDialogState();
}

class _RewardSystemDialogState extends State<_RewardSystemDialog> {
  final TextEditingController _minRatingController = TextEditingController(text: '4.0');
  final TextEditingController _minTasksController = TextEditingController(text: '3');
  final TextEditingController _rewardAmountController = TextEditingController(text: '100');
  bool _isCalculating = false;
  int _selectedTab = 0; // 0 = Calculate, 1 = History
  String? _ratingError;
  String? _tasksError;
  String? _amountError;

  @override
  void dispose() {
    _minRatingController.dispose();
    _minTasksController.dispose();
    _rewardAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.card_giftcard, color: Colors.orange[700], size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Monthly Reward System',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tabs
            Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    label: 'Calculate Rewards',
                    isSelected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton(
                    label: 'Reward History',
                    isSelected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content
            Expanded(
              child: _selectedTab == 0 ? _buildCalculateTab() : _buildHistoryTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculateTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Reward Criteria',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Users will be rewarded if they meet both criteria:\n'
                  '• Average rating ≥ minimum rating\n'
                  '• Approved applications for completed posts ≥ minimum posts',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[800],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Settings
          Text(
            'Reward Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),

          // Minimum Rating
          TextField(
            controller: _minRatingController,
            decoration: InputDecoration(
              labelText: 'Minimum Average Rating',
              hintText: 'e.g., 4.0',
              prefixIcon: Icon(Icons.star, color: _ratingError != null ? Colors.red : Colors.orange),
              errorText: _ratingError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _ratingError != null ? Colors.red : Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _ratingError != null ? Colors.red : Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _ratingError != null ? Colors.red : AppColors.primaryDark,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: _ratingError != null ? Colors.red[50] : Colors.grey[50],
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 16),
            onChanged: (value) {
              if (_ratingError != null) {
                setState(() => _ratingError = null);
              }
            },
          ),
          const SizedBox(height: 16),

          // Minimum Tasks
          TextField(
            controller: _minTasksController,
            decoration: InputDecoration(
              labelText: 'Minimum Completed Posts',
              hintText: 'e.g., 3',
              prefixIcon: Icon(Icons.task_alt, color: _tasksError != null ? Colors.red : Colors.green),
              errorText: _tasksError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _tasksError != null ? Colors.red : Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _tasksError != null ? Colors.red : Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _tasksError != null ? Colors.red : AppColors.primaryDark,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: _tasksError != null ? Colors.red[50] : Colors.grey[50],
            ),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16),
            onChanged: (value) {
              if (_tasksError != null) {
                setState(() => _tasksError = null);
              }
            },
          ),
          const SizedBox(height: 16),

          // Reward Amount
          TextField(
            controller: _rewardAmountController,
            decoration: InputDecoration(
              labelText: 'Reward Amount (Credits)',
              hintText: 'e.g., 100',
              prefixIcon: Icon(Icons.account_balance_wallet, color: _amountError != null ? Colors.red : Colors.purple),
              errorText: _amountError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _amountError != null ? Colors.red : Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _amountError != null ? Colors.red : Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _amountError != null ? Colors.red : AppColors.primaryDark,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: _amountError != null ? Colors.red[50] : Colors.grey[50],
            ),
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16),
            onChanged: (value) {
              if (_amountError != null) {
                setState(() => _amountError = null);
              }
            },
          ),
          const SizedBox(height: 24),

          // Calculate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCalculating ? null : _calculateRewards,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isCalculating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Calculating...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calculate, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Calculate & Distribute Rewards',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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

  Widget _buildHistoryTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.rewardService.streamRewardHistory(limit: 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading history: ${snapshot.error}',
              style: TextStyle(color: Colors.red[700]),
            ),
          );
        }

        final rewards = snapshot.data ?? [];

        if (rewards.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No reward history yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: rewards.length,
          itemBuilder: (context, index) {
            final reward = rewards[index];
            final month = reward['month'] as String? ?? 'Unknown';
            final eligibleUsers = reward['eligibleUsers'] as int? ?? 0;
            final successCount = reward['successCount'] as int? ?? 0;
            final failCount = reward['failCount'] as int? ?? 0;
            final calculatedAt = reward['calculatedAt'] as DateTime?;
            final rewardAmount = reward['rewardAmount'] as int? ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.calendar_month, color: Colors.orange[700], size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Month: $month',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            if (calculatedAt != null)
                              Text(
                                'Calculated: ${DateFormat('dd MMM yyyy, hh:mm a').format(calculatedAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.people,
                          label: 'Eligible',
                          value: eligibleUsers.toString(),
                          color: Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.check_circle,
                          label: 'Success',
                          value: successCount.toString(),
                          color: Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.error,
                          label: 'Failed',
                          value: failCount.toString(),
                          color: Colors.red,
                        ),
                      ),
                      Expanded(
                        child: _buildStatItem(
                          icon: Icons.account_balance_wallet,
                          label: 'Amount',
                          value: '$rewardAmount',
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _runCalculationInChunks(
    double minRating,
    int minTasks,
    int rewardAmount,
  ) async {
    debugPrint('🔵 [CHUNKS] _runCalculationInChunks: START');
    debugPrint('🔵 [CHUNKS] Parameters: rating=$minRating, tasks=$minTasks, amount=$rewardAmount');
    
    // Ensure UI has fully rendered the loading dialog before starting
    debugPrint('🔵 [CHUNKS] Waiting 100ms for UI');
    await Future.delayed(const Duration(milliseconds: 100));
    debugPrint('🔵 [CHUNKS] Waiting for endOfFrame');
    await WidgetsBinding.instance.endOfFrame;
    debugPrint('🔵 [CHUNKS] Waiting 50ms more');
    await Future.delayed(const Duration(milliseconds: 50));
    debugPrint('🔵 [CHUNKS] UI should be ready, calling previewEligibleUsers');
    
    // Start the calculation
    final result = await widget.rewardService.previewEligibleUsers(
      minRating: minRating,
      minCompletedTasks: minTasks,
      rewardAmount: rewardAmount,
    );
    debugPrint('✅ [CHUNKS] previewEligibleUsers completed');
    debugPrint('🔵 [CHUNKS] _runCalculationInChunks: END');
    return result;
  }

  Future<void> _calculateRewards() async {
    debugPrint('🔵 [REWARD] _calculateRewards: START');
    
    // Reset errors
    setState(() {
      _ratingError = null;
      _tasksError = null;
      _amountError = null;
    });
    debugPrint('🔵 [REWARD] Errors reset');

    final minRating = double.tryParse(_minRatingController.text);
    final minTasks = int.tryParse(_minTasksController.text);
    final rewardAmount = int.tryParse(_rewardAmountController.text);
    debugPrint('🔵 [REWARD] Parsed values: rating=$minRating, tasks=$minTasks, amount=$rewardAmount');

    bool hasError = false;

    if (minRating == null || minRating <= 0 || minRating > 5) {
      setState(() {
        _ratingError = 'Please enter a valid rating';
      });
      hasError = true;
      debugPrint('🔴 [REWARD] Rating validation failed');
    }

    if (minTasks == null || minTasks <= 0) {
      setState(() {
        _tasksError = 'Please enter a valid number of posts';
      });
      hasError = true;
      debugPrint('🔴 [REWARD] Tasks validation failed');
    }

    if (rewardAmount == null || rewardAmount <= 0) {
      setState(() {
        _amountError = 'Please enter a valid reward amount';
      });
      hasError = true;
      debugPrint('🔴 [REWARD] Amount validation failed');
    }

    if (hasError) {
      debugPrint('🔴 [REWARD] Validation errors found, returning');
      return;
    }

    // At this point, all values are validated and non-null
    final validMinRating = minRating!;
    final validMinTasks = minTasks!;
    final validRewardAmount = rewardAmount!;
    debugPrint('✅ [REWARD] Validation passed: rating=$validMinRating, tasks=$validMinTasks, amount=$validRewardAmount');

    // Show loading while calculating preview
    debugPrint('🔵 [REWARD] Setting _isCalculating = true');
    setState(() => _isCalculating = true);
    
    // Show a non-dismissible loading dialog to prevent user interaction
    if (!mounted) {
      debugPrint('🔴 [REWARD] Widget not mounted, returning');
      return;
    }
    
    debugPrint('🔵 [REWARD] Showing loading dialog');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Calculating rewards...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'This may take a moment',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    debugPrint('🔵 [REWARD] Loading dialog shown');
    
    // Force UI to update
    debugPrint('🔵 [REWARD] Yielding to UI thread');
    await Future.microtask(() {});
    await Future.delayed(Duration.zero);
    await Future.microtask(() {});
    debugPrint('🔵 [REWARD] After microtasks');
    
    if (!mounted) {
      debugPrint('🔴 [REWARD] Widget not mounted after microtasks, closing dialog');
      Navigator.of(context).pop(); // Close loading dialog
      return;
    }
    
    // Wait for next frame
    debugPrint('🔵 [REWARD] Waiting 200ms for UI to update');
    await Future.delayed(const Duration(milliseconds: 200));
    debugPrint('🔵 [REWARD] After 200ms delay');
    
    if (!mounted) {
      debugPrint('🔴 [REWARD] Widget not mounted after delay, closing dialog');
      Navigator.of(context).pop(); // Close loading dialog
      return;
    }

    try {
      debugPrint('🔵 [REWARD] Starting _runCalculationInChunks');
      // Run calculation in chunks with explicit yields
      final previewResult = await _runCalculationInChunks(
        validMinRating,
        validMinTasks,
        validRewardAmount,
      );
      debugPrint('✅ [REWARD] _runCalculationInChunks completed');
      debugPrint('🔵 [REWARD] Preview result: success=${previewResult['success']}, totalEligible=${previewResult['totalEligible']}');
      
      // Close loading dialog
      if (mounted) {
        debugPrint('🔵 [REWARD] Closing loading dialog');
        Navigator.of(context).pop();
      }

      if (!mounted) {
        debugPrint('🔴 [REWARD] Widget not mounted after preview, closing dialog');
        Navigator.of(context).pop(); // Close loading dialog if still open
        return;
      }

      // Wait for loading dialog to fully close before proceeding
      debugPrint('🔵 [REWARD] Waiting for loading dialog to close');
      await Future.delayed(const Duration(milliseconds: 100));
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 50));
      debugPrint('🔵 [REWARD] Loading dialog should be closed now');

      debugPrint('🔵 [REWARD] Setting _isCalculating = false');
      setState(() => _isCalculating = false);
      
      // Wait for setState to complete
      await Future.delayed(Duration.zero);
      await Future.microtask(() {});

      if (previewResult['success'] != true) {
        debugPrint('🔴 [REWARD] Preview failed: ${previewResult['error']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${previewResult['error'] ?? 'Failed to calculate preview'}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final eligibleUsers = previewResult['eligibleUsers'] as List<dynamic>? ?? [];
      final totalEligible = previewResult['totalEligible'] as int? ?? 0;
      final month = previewResult['month'] as String? ?? 'Unknown';
      final completedPostsCount = previewResult['completedPostsCount'] as int? ?? 0;
      debugPrint('🔵 [REWARD] Preview data: eligibleUsers=${eligibleUsers.length}, totalEligible=$totalEligible, month=$month, completedPosts=$completedPostsCount');

      // Show preview dialog with eligible users count
      debugPrint('🔵 [REWARD] Showing preview dialog');
      debugPrint('🔵 [REWARD] About to call showDialog');
      
      // Yield before showing dialog to ensure UI is ready
      await Future.delayed(Duration.zero);
      await Future.microtask(() {});
      await SchedulerBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint('🔵 [REWARD] UI should be ready, calling showDialog');
      
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          debugPrint('🔵 [DIALOG] Dialog builder called');
          // Yield in builder to prevent blocking
          WidgetsBinding.instance.addPostFrameCallback((_) {
            debugPrint('🔵 [DIALOG] Dialog frame rendered');
          });
          return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.preview, color: Colors.orange[700], size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Reward Preview',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Month: $month',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPreviewStat(
                              icon: Icons.work,
                              label: 'Completed Posts',
                              value: completedPostsCount.toString(),
                              color: Colors.blue,
                            ),
                          ),
                          Expanded(
                            child: _buildPreviewStat(
                              icon: Icons.people,
                              label: 'Eligible Users',
                              value: totalEligible.toString(),
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPreviewStat(
                              icon: Icons.account_balance_wallet,
                              label: 'Total Credits',
                              value: '${totalEligible * validRewardAmount}',
                              color: Colors.purple,
                            ),
                          ),
                          Expanded(
                            child: _buildPreviewStat(
                              icon: Icons.star,
                              label: 'Per User',
                              value: '$validRewardAmount',
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Criteria
                Text(
                  'Criteria:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                _buildCriteriaRow('Minimum Rating', validMinRating.toStringAsFixed(1)),
                _buildCriteriaRow('Minimum Posts', validMinTasks.toString()),
                _buildCriteriaRow('Reward Amount', '$validRewardAmount credits'),
                
                if (totalEligible > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Eligible Users:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: eligibleUsers.length > 10 ? 10 : eligibleUsers.length,
                      itemBuilder: (context, index) {
                        final user = eligibleUsers[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.green[100],
                                child: Text(
                                  (user['userName'] as String? ?? '?')[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user['userName'] as String? ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Rating: ${(user['averageRating'] as num?)?.toStringAsFixed(1) ?? '0.0'}, Posts: ${user['completedTasks'] ?? 0}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (eligibleUsers.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '... and ${eligibleUsers.length - 10} more users',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No users meet the criteria for this month.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          completedPostsCount == 0
                              ? '• No completed posts found in this month'
                              : '• Found $completedPostsCount completed post(s), but no users with applications meet the criteria\n• Check if users have applications for completed posts\n',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint('🔵 [DIALOG] Cancel button pressed');
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: totalEligible > 0
                  ? () {
                      debugPrint('🔵 [DIALOG] Distribute button pressed');
                      Navigator.pop(context, true);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Distribute Rewards'),
            ),
          ],
          );
        },
      );
      
      debugPrint('🔵 [REWARD] showDialog returned, confirmed=$confirmed');
      debugPrint('🔵 [REWARD] Preview dialog closed, confirmed=$confirmed');
      if (confirmed != true) {
        debugPrint('🔴 [REWARD] User cancelled, returning');
        return;
      }

      // Proceed with distribution
      debugPrint('🔵 [REWARD] User confirmed, starting distribution');
      debugPrint('🔵 [REWARD] Setting _isCalculating = true for distribution');
      setState(() => _isCalculating = true);

      debugPrint('🔵 [REWARD] Calling calculateMonthlyRewards service');
      final result = await widget.rewardService.calculateMonthlyRewards(
        minRating: validMinRating,
        minCompletedTasks: validMinTasks,
        rewardAmount: validRewardAmount,
      );
      debugPrint('✅ [REWARD] calculateMonthlyRewards completed');
      debugPrint('🔵 [REWARD] Distribution result: success=${result['success']}, successCount=${result['successCount']}, failCount=${result['failCount']}');

      if (mounted) {
        debugPrint('🔵 [REWARD] Closing main dialog and showing snackbar');
        Navigator.pop(context); // Close main dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['success'] == true
                  ? 'Successfully distributed rewards to ${result['successCount']} users!'
                  : 'Error: ${result['error']}',
            ),
            backgroundColor: result['success'] == true ? Colors.green : Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        debugPrint('✅ [REWARD] _calculateRewards: COMPLETED SUCCESSFULLY');
      }
    } catch (e, stackTrace) {
      debugPrint('🔴 [REWARD] ERROR in _calculateRewards: $e');
      debugPrint('🔴 [REWARD] Stack trace: $stackTrace');
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _isCalculating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      debugPrint('🔵 [REWARD] Finally block: cleaning up');
      // Ensure loading dialog is closed
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {
          // Dialog might already be closed
        }
        setState(() => _isCalculating = false);
      }
      debugPrint('🔵 [REWARD] _calculateRewards: END');
    }
  }

  Widget _buildPreviewStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCriteriaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }
}