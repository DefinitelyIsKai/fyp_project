import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fyp_project/pages/admin/post_moderation/post_moderation_page.dart';
import 'package:fyp_project/pages/admin/post_moderation/approve_reject_posts_page.dart';
import 'package:fyp_project/pages/admin/user_management/user_management_page.dart';
import 'package:fyp_project/pages/admin/user_management/view_users_page.dart';
import 'package:fyp_project/pages/admin/monitoring/monitoring_page.dart';
import 'package:fyp_project/pages/admin/system_config/system_config_page.dart';
import 'package:fyp_project/pages/admin/message_oversight/message_oversight_main_page.dart';
import 'package:fyp_project/pages/admin/message_oversight/flagged_content_page.dart';
import 'package:fyp_project/pages/admin/analytics/analytics_page.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:fyp_project/services/admin/dashboard_service.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:fyp_project/routes/app_routes.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DashboardService _dashboardService = DashboardService();
  final UserService _userService = UserService();
  StreamSubscription<int>? _reportsSubscription;
  StreamSubscription<int>? _pendingPostsSubscription;

  int _pendingPosts = 0;
  int _activeUsers = 0;
  int _unresolvedReports = 0;
  bool _isLoading = true;

  final Map<String, List<String>> roleAccess = {
    'manager': [
      'Post Moderation',
      'User Management',
      'Monitoring & Search',
      'System Configuration',
      'Message Oversight',
      'Analytics & Reporting',
    ],
    'hr': [
      'Post Moderation',
      'User Management',
      'Monitoring & Search',
      'Analytics & Reporting',
      'Message Oversight',
    ],
    'staff': [
      'Post Moderation',
      'User Management',
      'Analytics & Reporting',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupRealtimeUpdates();
  }

  // Setup realtime stream subscriptions for dashboard stats
  // Staff role doesn't see reports count, so skip that subscription
  void _setupRealtimeUpdates() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentRole = authService.currentAdmin?.role.toLowerCase() ?? '';
    final isStaff = currentRole == 'staff';
    
    // Only subscribe to reports if not staff
    if (!isStaff) {
      _reportsSubscription = _dashboardService.streamUnresolvedReportsCount().listen(
        (count) {
          if (mounted) {
            setState(() {
              _unresolvedReports = count;
            });
          }
        },
        onError: (error) {
          debugPrint('Error listening to reports stream: $error');
          if (mounted) {
            setState(() {
              _unresolvedReports = 0; // Reset to 0 on error
            });
          }
          _reportsSubscription?.cancel();
          _reportsSubscription = null;
        },
      );
    }

    // Always listen to pending posts count (all roles need this)
    _pendingPostsSubscription = _dashboardService.streamPendingPostsCount().listen(
      (count) {
        if (mounted) {
          setState(() {
            _pendingPosts = count;
          });
        }
      },
      onError: (error) {
        debugPrint('Error listening to pending posts stream: $error');
        if (mounted) {
          setState(() {
            _pendingPosts = 0; // Reset to 0 on error
          });
        }
        _pendingPostsSubscription?.cancel();
        _pendingPostsSubscription = null;
      },
    );
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    _pendingPostsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _userService.checkAndAutoUnsuspendExpiredUsers().catchError((e) {
        debugPrint('Error in auto unsuspend check: $e');
        return <String, dynamic>{
          'success': false,
          'error': e.toString(),
          'unsuspendedCount': 0,
          'unsuspendedUserNames': [],
        };
      });
      
      final users = await _dashboardService.getActiveUsersCount();
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentRole = authService.currentAdmin?.role.toLowerCase() ?? '';
      final isStaff = currentRole == 'staff';
      
      int unresolvedReports = 0;
      if (!isStaff) {
        unresolvedReports = await _dashboardService.getUnresolvedReportsCount();
      }

      if (mounted) {
        setState(() {
          _activeUsers = users;
          _unresolvedReports = unresolvedReports;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshDashboard() async {
    try {
      // Refresh active users count
      final users = await _dashboardService.getActiveUsersCount();
      // Refresh unresolved reports count
      final unresolvedReports = await _dashboardService.getUnresolvedReportsCount();

      if (mounted) {
        setState(() {
          _activeUsers = users;
          _unresolvedReports = unresolvedReports;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error refreshing dashboard: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final rawRole = authService.currentAdmin?.role ?? 'staff';
    final role = rawRole.toLowerCase().trim();
    final allowedPages = roleAccess[role] ?? roleAccess['staff'] ?? [];
    
    debugPrint('Dashboard - Raw role from authService: "$rawRole"');
    debugPrint('Dashboard - Normalized role: "$role"');
    debugPrint('Dashboard - Allowed pages for role "$role": $allowedPages');
    debugPrint('Dashboard - Available roles in roleAccess: ${roleAccess.keys.toList()}');

    return WillPopScope(
      onWillPop: () async {
        _showUserProfile(context, authService);
        return false; // Prevent default back navigation
      },
      child: Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('JobSeek Admin Dashboard',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A5F),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showUserProfile(context, authService),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                await _reportsSubscription?.cancel();
                await _pendingPostsSubscription?.cancel();
                _reportsSubscription = null;
                _pendingPostsSubscription = null;
                
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.login,
                    (route) => false, 
                  );
                }
                
                // Perform logout in background (non-blocking)
                authService.logout().catchError((e) {
                  debugPrint('Logout error (non-critical): $e');
                });
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.logout, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshDashboard,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeaderSection()),
                  SliverToBoxAdapter(child: _buildStatsSection()),
                  _buildDashboardGridSliver(allowedPages),
                ],
              ),
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
            const Color(0xFF1E3A5F),
            const Color(0xFF2C5282), 
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome back!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Here\'s what\'s happening today',
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.9))),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentRole = authService.currentAdmin?.role.toLowerCase() ?? '';
    final isStaff = currentRole == 'staff';
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<int>(
              stream: _dashboardService.streamPendingPostsCount(),
              builder: (context, snapshot) {
                final pendingCount = snapshot.data ?? 0;
                return _StatCard(
                  title: 'Pending',
                  value: pendingCount.toString(),
                  color: const Color(0xFFFF9800), 
                  icon: Icons.article,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ApproveRejectPostsPage(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              title: 'Active Users',
              value: _activeUsers.toString(),
              color: const Color(0xFF4CAF50), 
              icon: Icons.people,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ViewUsersPage(),
                  ),
                );
              },
            ),
          ),
          // Hide Unresolved Reports card for staff role
          if (!isStaff) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                title: 'Reports',
                value: _unresolvedReports.toString(),
                color: const Color(0xFFE53935), 
                icon: Icons.flag,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FlaggedContentPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showUserProfile(BuildContext context, AuthService authService) {
    final admin = authService.currentAdmin;
    if (admin == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1E3A5F),
                      const Color(0xFF2C5282),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'User Profile',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Logged in as',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileRow(Icons.person_outline, 'Name', admin.name),
                    const SizedBox(height: 20),
                    _buildProfileRow(Icons.email_outlined, 'Email', admin.email),
                    const SizedBox(height: 20),
                    _buildProfileRow(
                      Icons.badge_outlined,
                      'Role',
                      admin.role.toUpperCase(),
                    ),
                    const SizedBox(height: 20),
                    _buildProfileRow(
                      Icons.shield_outlined,
                      'Permissions',
                      '${admin.permissions.length} permission(s)',
                    ),
                    if (admin.lastLoginAt != null) ...[
                      const SizedBox(height: 20),
                      _buildProfileRow(
                        Icons.access_time,
                        'Last Login',
                        _formatDateTime(admin.lastLoginAt!),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        
                        await _reportsSubscription?.cancel();
                        await _pendingPostsSubscription?.cancel();
                        _reportsSubscription = null;
                        _pendingPostsSubscription = null;
                        
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.login,
                            (route) => false, // Remove all previous routes
                          );
                        }
                        
                        authService.logout().catchError((e) {
                          debugPrint('Logout error (non-critical): $e');
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A5F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Logout',
                        style: TextStyle(fontSize: 16),
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

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1E3A5F)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} minute(s) ago';
      }
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day(s) ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Widget _buildDashboardGridSliver(List<String> allowedPages) {
    final cards = [
      _DashboardCard(
        title: 'Post Moderation',
        icon: Icons.article,
        color: const Color(0xFF1976D2), 
        subtitle: '$_pendingPosts pending reviews',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostModerationPage()),
        ),
      ),
      _DashboardCard(
        title: 'User Management',
        icon: Icons.people_alt,
        color: const Color(0xFF388E3C),
        subtitle: '$_activeUsers active users',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserManagementPage()),
        ),
      ),
      _DashboardCard(
        title: 'Monitoring & Search',
        icon: Icons.search,
        color: const Color(0xFFF57C00),
        subtitle: 'Monitor activities',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MonitoringPage()),
        ),
      ),
      _DashboardCard(
        title: 'System Configuration',
        icon: Icons.settings,
        color: const Color(0xFF7B1FA2), 
        subtitle: 'System settings',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SystemConfigPage()),
        ),
      ),
      _DashboardCard(
        title: 'Message Oversight',
        icon: Icons.chat_bubble,
        color: const Color(0xFFC62828), 
        subtitle: '$_unresolvedReports unresolved reports',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MessageOversightMainPage()),
        ),
      ),
      _DashboardCard(
        title: 'Analytics & Reporting',
        icon: Icons.analytics,
        color: const Color(0xFF00796B), 
        subtitle: 'View reports',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnalyticsPage()),
        ),
      ),
    ];

    final filteredCards = cards.where((c) => allowedPages.contains(c.title)).toList();
    
    // Debug logging
    debugPrint('Dashboard - Allowed pages: $allowedPages');
    debugPrint('Dashboard - Filtered cards count: ${filteredCards.length}');
    debugPrint('Dashboard - Filtered card titles: ${filteredCards.map((c) => c.title).toList()}');

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return filteredCards[index];
          },
          childCount: filteredCards.length,
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: Colors.grey[400],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
