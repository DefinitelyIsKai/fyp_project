import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:fyp_project/services/admin/reward_service.dart';
import 'package:fyp_project/services/user/notification_service.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:fyp_project/widgets/admin/dialogs/user_dialogs/wallet_credit_dialogs.dart';
import 'package:fyp_project/widgets/admin/dialogs/user_dialogs/reward_system_dialog.dart';
import 'package:fyp_project/models/admin/user_model.dart';
import 'package:fyp_project/pages/admin/user_management/user_detail_page.dart';
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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Force refresh by triggering a rebuild
          setState(() {});
        },
        color: Colors.blue[700],
        backgroundColor: Colors.white,
        child: Column(
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
        // Error checking user role - continue with next wallet
      }
    }
    
    return nonAdminWallets;
  }

  // Filter out admin wallets and sort by user name
  // Only show wallets for regular users (jobseekers and recruiters)
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
          
          // Skip admin roles - only show regular user wallets
          if (role != 'manager' && role != 'hr' && role != 'staff') {
            final userName = userData?['fullName'] as String? ?? 'Unknown User';
            walletUserPairs.add({
              'wallet': wallet,
              'userName': userName,
            });
          }
        }
      } catch (e) {
        // Skip this wallet if we can't check the role
      }
    }
    
    // Sort alphabetically by name for easier browsing
    walletUserPairs.sort((a, b) => 
      (a['userName'] as String).toLowerCase().compareTo((b['userName'] as String).toLowerCase())
    );
    
    // Extract just the wallet docs in sorted order
    return walletUserPairs.map((pair) => pair['wallet'] as QueryDocumentSnapshot).toList();
  }

  Widget _buildWalletCard(QueryDocumentSnapshot walletDoc) {
    final walletData = walletDoc.data() as Map<String, dynamic>;
    final userId = walletData['userId'] as String? ?? walletDoc.id;
    final balance = (walletData['balance'] as num?)?.toDouble() ?? 0.0;
    final heldCredits = (walletData['heldCredits'] as num?)?.toDouble() ?? 0.0;
    final availableBalance = balance - heldCredits;
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
        final isPositive = availableBalance >= 0;

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
                onTap: () {
                  if (userSnapshot.data?.exists == true && userData != null) {
                    try {
                      final user = UserModel.fromJson(userData, userId);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserDetailPage(user: user),
                        ),
                      ).then((refreshed) {
                        if (refreshed == true) {
                          setState(() {});
                        }
                      });
                    } catch (e) {
                      debugPrint('Error navigating to user detail: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error loading user details: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
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
                                      '${availableBalance.toStringAsFixed(0)}',
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
                              if (heldCredits > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Total: ${balance.toStringAsFixed(0)} (Held: ${heldCredits.toStringAsFixed(0)})',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildActionButton(
                                icon: Icons.add_circle_outline,
                                color: Colors.green,
                                onTap: () => AddCreditDialog.show(
                                  context: context,
                                  userId: userId,
                                  userName: userName,
                                  currentBalance: balance,
                                  onAddCredit: _addCredit,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                icon: Icons.remove_circle_outline,
                                color: Colors.red,
                                onTap: () => DeductCreditDialog.show(
                                  context: context,
                                  userId: userId,
                                  userName: userName,
                                  currentBalance: balance,
                                  heldCredits: heldCredits,
                                  availableBalance: availableBalance,
                                  onDeductCredit: _deductCredit,
                                ),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading wallets...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
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
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
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
          ),
        ),
      ],
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

  // Add credit to user wallet using firestore transaction
  // Also creates transaction record and sends notification
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
      
      // Create wallet if it doesn't exist yet
      final walletDoc = await walletRef.get();
      if (!walletDoc.exists) {
        await walletRef.set({
          'userId': userId,
          'balance': 0,
          'heldCredits': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Use transaction to ensure balance update and transaction record are atomic
      // Prevents race conditions if multiple credits added at same time
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
        
        // Create transaction record in subcollection for history
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
        // Error creating log entry - continue
      }

      // Send notification to user
      try {
        await _notificationService.notifyWalletCredit(
          userId: userId,
          amount: amount.toInt(),
          reason: reason.isEmpty ? 'Credit added by admin' : reason,
        );
      } catch (notifError) {
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
    RewardSystemDialog.show(
      context: context,
      rewardService: _rewardService,
      notificationService: _notificationService,
    );
  }
}
