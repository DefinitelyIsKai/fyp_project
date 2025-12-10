import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';
import 'package:fyp_project/widgets/admin/dialogs/date_range_picker_dialog.dart' as custom;

class AdminLogsPage extends StatefulWidget {
  const AdminLogsPage({super.key});

  @override
  State<AdminLogsPage> createState() => _AdminLogsPageState();
}

class _AdminLogsPageState extends State<AdminLogsPage> {
  String _selectedFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isFiltersExpanded = true;
  
  final List<String> _availableActionTypes = [
    'add_credit',
    'deduct_credit',
    'reward_distribution',
    'post_approved',
    'post_rejected',
    'user_deleted',
    'user_reactivated',
    'user_suspended',
    'user_unsuspended',
    'warning_issued',
    'admin_login_success',
    'admin_login_failed',
    'admin_face_verification_failed',
    'report_resolved',
    'user_info_updated',
    'user_verification_approved',
    'user_verification_rejected',
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Logs',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.cardOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _isFiltersExpanded = !_isFiltersExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 20,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const Spacer(),
                        if (_hasActiveFilters())
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[700],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_getActiveFilterCount()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Icon(
                          _isFiltersExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isFiltersExpanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _FilterChip(
                                        label: 'Type',
                                        value: _selectedFilter == 'all' 
                                            ? 'All Actions' 
                                            : _getActionDisplayName(_selectedFilter),
                                        onTap: () => _showTypeFilter(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _FilterChip(
                                        label: 'Date Range',
                                        value: _getDateRangeText(),
                                        onTap: () => _showDateRangeFilter(),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_hasActiveFilters()) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${_getActiveFilterCount()} filter${_getActiveFilterCount() > 1 ? 's' : ''} active',
                                          style: TextStyle(
                                            color: Colors.blue[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: _resetFilters,
                                        icon: const Icon(Icons.clear_all, size: 16),
                                        label: const Text('Clear All'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildLogsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading logs: ${snapshot.error}',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description_outlined, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No logs found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Logs will appear here once available',
                          style: TextStyle(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final logs = snapshot.data!.docs;
                
                final filteredLogs = _filterLogs(logs);

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  color: AppColors.cardOrange,
                  child: filteredLogs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.filter_alt_off, size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No logs found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your filters',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredLogs.length,
                          itemBuilder: (context, index) {
                            final log = filteredLogs[index];
                            final data = log.data() as Map<String, dynamic>;
                            return _buildLogCard(data);
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> data) {
    final actionType = data['actionType'] as String? ?? 'unknown';
    final userId = data['userId'] as String? ?? data['ownerId'] as String? ?? '';
    final userName = data['userName'] as String? ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final reason = data['description'] as String? ?? data['reason'] as String? ?? data['rejectionReason'] as String? ?? data['violationReason'] as String? ?? '';
    final createdBy = data['createdBy'] as String? ?? '';
    final postTitle = data['postTitle'] as String? ?? '';
    final userEmail = data['userEmail'] as String? ?? '';
    final previousStatus = data['previousStatus'] as String? ?? '';
    final newStatus = data['newStatus'] as String? ?? '';
    final previousStrikeCount = data['previousStrikeCount'] as int?;
    final newStrikeCount = data['newStrikeCount'] as int?;
    final strikeCount = data['strikeCount'] as int?;
    final wasSuspended = data['wasSuspended'] as bool? ?? false;
    final deductedMarks = data['deductedMarks'] as double?;
    final durationDays = data['durationDays'] as int?;

    String dateStr = 'Unknown date';
    if (createdAt != null) {
      try {
        dateStr = DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt.toDate());
      } catch (e) {
        dateStr = 'Invalid date';
      }
    }

    final actionInfo = _getActionInfo(actionType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: actionInfo['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      actionInfo['icon'] as IconData,
                      size: 20,
                      color: actionInfo['color'],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionInfo['name'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: actionInfo['color'].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: actionInfo['color'].withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      actionType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: actionInfo['color'],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (postTitle.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.work_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Post: $postTitle',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              if (userId.isNotEmpty) ...[
                FutureBuilder<String>(
                  future: userName.isNotEmpty 
                      ? Future.value(userName)
                      : _getUserName(userId),
                  builder: (context, snapshot) {
                    final displayName = snapshot.data ?? 'Loading...';
                    if (displayName == 'Loading...' && !snapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'User: $displayName',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (userEmail.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.email_outlined, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Email: $userEmail',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                      ],
                    );
                  },
                ),
              ],
              if (previousStatus.isNotEmpty && newStatus.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Status: $previousStatus to $newStatus',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              
              if (previousStrikeCount != null && newStrikeCount != null) ...[
                Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Strike Count: $previousStrikeCount to $newStrikeCount',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              if (strikeCount != null && previousStrikeCount == null) ...[
                Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, size: 16, color: Colors.orange[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Strike Count: $strikeCount/3',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              
              if (wasSuspended) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 16, color: Colors.red[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'User was automatically suspended',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              
              if (deductedMarks != null && deductedMarks > 0) ...[
                Row(
                  children: [
                    Icon(Icons.remove_circle_outline, size: 16, color: Colors.red[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Deducted: ${deductedMarks.toStringAsFixed(2)} credits',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              
              if (durationDays != null) ...[
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.orange[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Duration: $durationDays day${durationDays == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ] else if (actionType == 'user_suspended' && durationDays == null) ...[
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.orange[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Duration: Indefinite',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              if (data.containsKey('amount')) ...[
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Amount: ${data['amount']} credits',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              if (data.containsKey('previousBalance') && data.containsKey('newBalance')) ...[
                Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Balance: ${data['previousBalance']} to ${data['newBalance']} credits',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              if (reason.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (createdBy.isNotEmpty) ...[
                FutureBuilder<String>(
                  future: _getAdminName(createdBy),
                  builder: (context, snapshot) {
                    final adminName = snapshot.data ?? 'Loading...';
                    if (adminName == 'Loading...' && !snapshot.hasData) {
                      return const SizedBox.shrink();
                    }
                    return Row(
                      children: [
                        Icon(Icons.admin_panel_settings, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Performed by: $adminName',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getActionInfo(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'add_credit':
        return {
          'name': 'Add Credit',
          'icon': Icons.add_circle_outline,
          'color': Colors.green,
        };
      case 'deduct_credit':
        return {
          'name': 'Deduct Credit',
          'icon': Icons.remove_circle_outline,
          'color': Colors.red,
        };
      case 'reward_distribution':
        return {
          'name': 'Monthly Reward',
          'icon': Icons.card_giftcard,
          'color': Colors.purple,
        };
      case 'user_management':
        return {
          'name': 'User Management',
          'icon': Icons.people,
          'color': Colors.blue,
        };
      case 'post_management':
        return {
          'name': 'Post Management',
          'icon': Icons.work,
          'color': Colors.orange,
        };
      case 'post_approved':
        return {
          'name': 'Post Approval',
          'icon': Icons.check_circle_outline,
          'color': Colors.green,
        };
      case 'post_rejected':
        return {
          'name': 'Post Reject',
          'icon': Icons.cancel_outlined,
          'color': Colors.red,
        };
      case 'post_completed':
        return {
          'name': 'Post Completed',
          'icon': Icons.done_all,
          'color': Colors.blue,
        };
      case 'post_reopened':
        return {
          'name': 'Post Reopened',
          'icon': Icons.replay,
          'color': Colors.orange,
        };
      case 'post_deleted':
        return {
          'name': 'Post Deleted',
          'icon': Icons.delete_outline,
          'color': Colors.red,
        };
      case 'user_unsuspended':
        return {
          'name': 'User Unsuspended',
          'icon': Icons.person_remove_outlined,
          'color': Colors.green,
        };
      case 'user_suspended':
        return {
          'name': 'User Suspended',
          'icon': Icons.person_off_outlined,
          'color': Colors.red,
        };
      case 'user_deleted':
        return {
          'name': 'User Deleted',
          'icon': Icons.delete_outline,
          'color': Colors.red,
        };
      case 'user_reactivated':
        return {
          'name': 'User Reactivated',
          'icon': Icons.person_add_outlined,
          'color': Colors.green,
        };
      case 'warning_issued':
        return {
          'name': 'Issue Warning',
          'icon': Icons.warning_amber_rounded,
          'color': Colors.orange,
        };
      case 'admin_login_success':
        return {
          'name': 'Admin Login Success',
          'icon': Icons.login,
          'color': Colors.green,
        };
      case 'admin_login_failed':
        return {
          'name': 'Admin Login Failed',
          'icon': Icons.login,
          'color': Colors.red,
        };
      case 'admin_face_verification_failed':
        return {
          'name': 'Face Verification Failed',
          'icon': Icons.face_retouching_off,
          'color': Colors.red,
        };
      case 'report_resolved':
        return {
          'name': 'Report Resolved',
          'icon': Icons.check_circle,
          'color': Colors.green,
        };
      case 'user_info_updated':
        return {
          'name': 'User Info Updated',
          'icon': Icons.edit,
          'color': Colors.blue,
        };
      case 'user_verification_approved':
        return {
          'name': 'User Verification Approved',
          'icon': Icons.verified,
          'color': Colors.green,
        };
      case 'user_verification_rejected':
        return {
          'name': 'User Verification Rejected',
          'icon': Icons.cancel,
          'color': Colors.red,
        };
      default:
        return {
          'name': 'Unknown Action',
          'icon': Icons.help_outline,
          'color': Colors.grey,
        };
    }
  }

  Future<String> _getUserName(String userId) async {
    if (userId.isEmpty) return 'Unknown User';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        return userDoc.data()?['fullName'] ?? 'Unknown User';
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
    }
    return 'Unknown User';
  }

  Future<String> _getAdminName(String adminId) async {
    if (adminId.isEmpty) return 'Unknown Admin';
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(adminId)
          .get();
      if (adminDoc.exists) {
        return adminDoc.data()?['fullName'] ?? 'Unknown Admin';
      }
    } catch (e) {
      debugPrint('Error fetching admin name: $e');
    }
    return 'Unknown Admin';
  }

  Stream<QuerySnapshot> _buildLogsStream() {

    return FirebaseFirestore.instance
        .collection('logs')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterLogs(List<QueryDocumentSnapshot> logs) {
    List<QueryDocumentSnapshot> filtered = logs;
    
    if (_selectedFilter != 'all') {
      filtered = filtered.where((log) {
        final data = log.data() as Map<String, dynamic>;
        final actionType = data['actionType'] as String?;
        return actionType == _selectedFilter;
      }).toList();
    }
    
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((log) {
        final data = log.data() as Map<String, dynamic>;
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) return false;
        
        final logDate = createdAt.toDate();
        final logDateOnly = DateTime(logDate.year, logDate.month, logDate.day);
        
        if (_startDate != null && _endDate != null) {
          final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
          return logDateOnly.isAfter(start.subtract(const Duration(days: 1))) &&
                 logDateOnly.isBefore(end.add(const Duration(days: 1)));
        } else if (_startDate != null) {
          final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          return logDateOnly.isAfter(start.subtract(const Duration(days: 1)));
        } else if (_endDate != null) {
          final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
          return logDateOnly.isBefore(end.add(const Duration(days: 1)));
        }
        
        return true;
      }).toList();
    }
    
    return filtered;
  }

  void _showTypeFilter() async {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Action Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text('All Actions'),
                    trailing: _selectedFilter == 'all'
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() => _selectedFilter = 'all');
                      Navigator.pop(context);
                    },
                  ),
                  ..._availableActionTypes.map((actionType) {
                    return _buildTypeFilterItem(
                      actionType,
                      _getActionDisplayName(actionType),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFilterItem(String value, String label) {
    return ListTile(
      title: Text(label),
      trailing: _selectedFilter == value
          ? const Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: () {
        setState(() => _selectedFilter = value);
        Navigator.pop(context);
      },
    );
  }

  void _showDateRangeFilter() async {
    final now = DateTime.now();
    final defaultStart = _startDate ?? now.subtract(const Duration(days: 30));
    final defaultEnd = _endDate ?? now;
    
    final result = await custom.DateRangePickerDialog.show(
      context,
      startDate: defaultStart,
      endDate: defaultEnd,
    );
    
    if (result != null) {
      setState(() {
        _startDate = result['start'];
        _endDate = result['end'];
      });
    }
  }

  String _getDateRangeText() {
    if (_startDate == null && _endDate == null) {
      return 'All Dates';
    }
    if (_startDate != null && _endDate != null) {
      final startStr = DateFormat('dd/MM/yyyy').format(_startDate!);
      final endStr = DateFormat('dd/MM/yyyy').format(_endDate!);
      return '$startStr - $endStr';
    }
    if (_startDate != null) {
      return 'From ${DateFormat('dd/MM/yyyy').format(_startDate!)}';
    }
    if (_endDate != null) {
      return 'Until ${DateFormat('dd/MM/yyyy').format(_endDate!)}';
    }
    return 'All Dates';
  }

  String _getActionDisplayName(String actionType) {
    switch (actionType) {
      case 'add_credit':
        return 'Add Credit';
      case 'deduct_credit':
        return 'Deduct Credit';
      case 'reward_distribution':
        return 'Monthly Reward';
      case 'post_approved':
        return 'Post Approval';
      case 'post_rejected':
        return 'Post Reject';
      case 'user_deleted':
        return 'Delete User';
      case 'user_reactivated':
        return 'Reactivate User';
      case 'user_suspended':
        return 'User Suspended';
      case 'user_unsuspended':
        return 'User Unsuspended';
      case 'warning_issued':
        return 'Issue Warning';
      case 'admin_login_success':
        return 'Admin Login Success';
      case 'admin_login_failed':
        return 'Admin Login Failed';
      case 'admin_face_verification_failed':
        return 'Face Verification Failed';
      case 'report_resolved':
        return 'Report Resolved';
      case 'user_info_updated':
        return 'User Info Updated';
      case 'user_verification_approved':
        return 'User Verification Approved';
      case 'user_verification_rejected':
        return 'User Verification Rejected';
      default:
        return actionType;
    }
  }

  bool _hasActiveFilters() {
    return _selectedFilter != 'all' || _startDate != null || _endDate != null;
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedFilter != 'all') count++;
    if (_startDate != null) count++;
    if (_endDate != null) count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _selectedFilter = 'all';
      _startDate = null;
      _endDate = null;
    });
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = value != 'All Actions' && value != 'All Dates';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.blue[300]! : Colors.grey[300]!,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.blue[700] : Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isActive ? Colors.blue[700] : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}
