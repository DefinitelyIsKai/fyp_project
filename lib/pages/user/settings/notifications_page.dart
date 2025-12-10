import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/user/app_notification.dart';
import '../../../services/user/notification_service.dart';
import '../../../utils/user/dialog_utils.dart';
import '../../../widgets/admin/dialogs/user_dialogs/notification_detail_dialog.dart';
import '../../../widgets/user/pagination_dots_widget.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  final PageController _pageController = PageController();

  final List<List<AppNotification>> _pages = [];
  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isInitialLoad = true;
  bool _isLoading = false;
  StreamSubscription<List<AppNotification>>? _newNotificationsSubscription;

  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadInitialNotifications();
    _listenForNewNotifications();
  }

  Future<void> _loadInitialNotifications() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _isInitialLoad = true;
    });

    try {
      final initialNotifications = await _notificationService.loadInitialNotifications(limit: _itemsPerPage);

      if (!mounted) return;

      final limitedNotifications = initialNotifications.length > _itemsPerPage
          ? initialNotifications.sublist(0, _itemsPerPage)
          : initialNotifications;

      setState(() {
        _pages.clear();
        if (limitedNotifications.isNotEmpty) {
          _pages.add(limitedNotifications);
        }
        _hasMore = initialNotifications.length >= _itemsPerPage;
        _isInitialLoad = false;
        _isLoading = false;
        _currentPage = 0;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
          _isLoading = false;
        });
        DialogUtils.showWarningMessage(context: context, message: 'Failed to load notifications: $e');
      }
    }
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _pages.clear();
      _currentPage = 0;
      _hasMore = true;
      _isLoading = false;
      _isLoadingMore = false;
    });

    if (_pageController.hasClients) {
      await _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }

    await _loadInitialNotifications();
  }

  void _listenForNewNotifications() {
    _newNotificationsSubscription = _notificationService.streamNewNotifications(limit: 1).listen((newNotifications) {
      if (!mounted || newNotifications.isEmpty || _isInitialLoad || _pages.isEmpty) return;

      final newNotification = newNotifications.first;
      final exists = _pages.expand((page) => page).any((n) => n.id == newNotification.id);

      if (!exists) {
        setState(() {
          _pages[0].insert(0, newNotification);
          if (_pages[0].length > _itemsPerPage) {
            final overflowItem = _pages[0].removeLast();
            if (_pages.length > 1) {
              _pages[1].insert(0, overflowItem);
            } else {
              _pages.add([overflowItem]);
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _newNotificationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final allNotifications = _pages.expand((page) => page).toList();
      if (allNotifications.isEmpty) {
        setState(() {
          _isLoadingMore = false;
        });
        return;
      }

      final lastNotification = allNotifications.last;
      final lastNotificationTime = lastNotification.createdAt;
      final lastNotificationId = lastNotification.id;

      final moreNotifications = await _notificationService.loadMoreNotifications(
        lastNotificationTime: lastNotificationTime,
        lastNotificationId: lastNotificationId,
        limit: _itemsPerPage,
      );

      if (!mounted) return;

      setState(() {
        if (moreNotifications.isEmpty) {
          _hasMore = false;
        } else {
          _pages.add(moreNotifications);
          if (moreNotifications.length < _itemsPerPage) {
            _hasMore = false;
          }
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        DialogUtils.showWarningMessage(context: context, message: 'Failed to load next page: $e');
      }
    }
  }

  void _handleNotificationTap(AppNotification notification) {
    if (!notification.isRead) {
      _handleMarkAsRead(notification);
    }

    showDialog(
      context: context,
      builder: (context) => NotificationDetailDialog(notification: notification),
    );
  }

  void _handleMarkAsRead(AppNotification notification) {
    if (notification.isRead) return;

    setState(() {
      for (final page in _pages) {
        final index = page.indexWhere((n) => n.id == notification.id);
        if (index != -1) {
          page[index] = AppNotification(
            id: notification.id,
            userId: notification.userId,
            category: notification.category,
            title: notification.title,
            body: notification.body,
            isRead: true,
            createdAt: notification.createdAt,
            metadata: notification.metadata,
          );
          break;
        }
      }
    });

    _notificationService.markAsRead(notification.id).catchError((_) {});
  }

  void _handleMarkAllAsRead() {
    final hasUnread = _pages.expand((page) => page).any((n) => !n.isRead);

    if (!hasUnread) return;

    setState(() {
      _pages.replaceRange(
        0,
        _pages.length,
        _pages.map((page) {
          return page.map((notification) {
            return AppNotification(
              id: notification.id,
              userId: notification.userId,
              category: notification.category,
              title: notification.title,
              body: notification.body,
              isRead: true,
              createdAt: notification.createdAt,
              metadata: notification.metadata,
            );
          }).toList();
        }).toList(),
      );
    });

    DialogUtils.showSuccessMessage(
      context: context,
      message: 'All notifications marked as read',
      duration: const Duration(seconds: 2),
    );

    _notificationService.markAllAsRead().catchError((_) {
      if (mounted) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Failed to update some notifications',
          duration: const Duration(seconds: 2),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Color(0xFF00C8A0)),
            tooltip: 'Mark all as read',
            onPressed: _handleMarkAllAsRead,
          ),
        ],
      ),
      body: _isInitialLoad
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C8A0)))
          : _pages.isEmpty || _pages[0].isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No notifications', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : Column(
              children: [
                _buildUnreadHeader(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length + (_isLoadingMore || _hasMore ? 1 : 0),
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });

                      if (index >= _pages.length - 1 && _hasMore && !_isLoadingMore) {
                        _loadNextPage();
                      }
                    },
                    itemBuilder: (context, pageIndex) {
                      if (pageIndex >= _pages.length) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF00C8A0)));
                      }

                      final pageNotifications = _pages[pageIndex];
                      return RefreshIndicator(
                        onRefresh: _refreshNotifications,
                        color: const Color(0xFF00C8A0),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: pageNotifications.length,
                          separatorBuilder: (_, index) {
                            if (index < pageNotifications.length - 1) {
                              return const Divider(height: 1, indent: 72);
                            }
                            return const SizedBox.shrink();
                          },
                          itemBuilder: (context, index) {
                            return _buildNotificationCard(pageNotifications[index]);
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (_pages.length > 1 || _hasMore)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: PaginationDotsWidget(
                      totalPages: _pages.length + (_hasMore ? 1 : 0),
                      currentPage: _currentPage,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildUnreadHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Text(
            'Recent Notifications',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
          ),
          const Spacer(),
          StreamBuilder<int>(
            stream: _notificationService.streamUnreadCount(),
            builder: (context, countSnap) {
              final unreadCount = countSnap.data ?? 0;
              if (unreadCount == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF00C8A0), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '$unreadCount unread',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.white : const Color(0xFF00C8A0).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead ? Colors.grey[100]! : const Color(0xFF00C8A0).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          if (!notification.isRead)
            BoxShadow(color: const Color(0xFF00C8A0).withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getIconBackgroundColor(notification.category, metadata: notification.metadata),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_iconFor(notification.category, metadata: notification.metadata), color: _getIconColor(notification.category, metadata: notification.metadata), size: 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
            color: Colors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(notification.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
                if (!notification.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF00C8A0), borderRadius: BorderRadius.circular(6)),
                    child: const Text(
                      'NEW',
                      style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: notification.isRead ? null : const Icon(Icons.circle, size: 8, color: Color(0xFF00C8A0)),
        onTap: () => _handleNotificationTap(notification),
      ),
    );
  }

  IconData _iconFor(NotificationCategory category, {Map<String, dynamic>? metadata}) {
    // Check for verification approved notification
    if (category == NotificationCategory.system && 
        metadata != null && 
        metadata['type'] == 'verification_approved') {
      return Icons.verified_user;
    }
    
    switch (category) {
      case NotificationCategory.message:
        return Icons.chat_bubble_outline_rounded;
      case NotificationCategory.wallet:
        return Icons.account_balance_wallet_outlined;
      case NotificationCategory.post:
        return Icons.campaign_outlined;
      case NotificationCategory.post_approval:
        return Icons.campaign_outlined;
      case NotificationCategory.application:
        return Icons.work_outline_rounded;
      case NotificationCategory.booking:
        return Icons.calendar_today_outlined;
      case NotificationCategory.system:
        return Icons.info_outline_rounded;
      case NotificationCategory.account_warning:
        return Icons.warning_amber_rounded;
      case NotificationCategory.account_suspension:
        return Icons.warning_amber_rounded;
      case NotificationCategory.post_rejection:
        return Icons.warning_amber_rounded;
      case NotificationCategory.account_unsuspension:
        return Icons.check_circle_outline_rounded;
      case NotificationCategory.report_resolved:
        return Icons.warning_amber_rounded;
    }
  }

  Color _getIconBackgroundColor(NotificationCategory category, {Map<String, dynamic>? metadata}) {
    // Check for verification approved notification
    if (category == NotificationCategory.system && 
        metadata != null && 
        metadata['type'] == 'verification_approved') {
      return Colors.blue.withOpacity(0.1);
    }
    
    switch (category) {
      case NotificationCategory.message:
        return const Color(0xFF00C8A0).withOpacity(0.1);
      case NotificationCategory.wallet:
        return Colors.orange.withOpacity(0.1);
      case NotificationCategory.post:
        return Colors.green.withOpacity(0.1);
      case NotificationCategory.post_approval:
        return Colors.green.withOpacity(0.1);
      case NotificationCategory.application:
        return Colors.purple.withOpacity(0.1);
      case NotificationCategory.booking:
        return Colors.blue.withOpacity(0.1);
      case NotificationCategory.system:
        return Colors.grey.withOpacity(0.1);
      case NotificationCategory.account_warning:
        return Colors.red.withOpacity(0.1);
      case NotificationCategory.account_suspension:
        return Colors.red.withOpacity(0.15);
      case NotificationCategory.post_rejection:
        return Colors.red.withOpacity(0.15);
      case NotificationCategory.account_unsuspension:
        return Colors.green.withOpacity(0.1);
      case NotificationCategory.report_resolved:
        return Colors.red.withOpacity(0.1);
    }
  }

  Color _getIconColor(NotificationCategory category, {Map<String, dynamic>? metadata}) {
    // Check for verification approved notification
    if (category == NotificationCategory.system && 
        metadata != null && 
        metadata['type'] == 'verification_approved') {
      return Colors.blue[700]!;
    }
    
    switch (category) {
      case NotificationCategory.message:
        return const Color(0xFF00C8A0);
      case NotificationCategory.wallet:
        return Colors.orange;
      case NotificationCategory.post:
        return Colors.green;
      case NotificationCategory.post_approval:
        return Colors.green;
      case NotificationCategory.application:
        return Colors.purple;
      case NotificationCategory.booking:
        return Colors.blue;
      case NotificationCategory.system:
        return Colors.grey;
      case NotificationCategory.account_warning:
        return Colors.red;
      case NotificationCategory.account_suspension:
        return Colors.red[800]!;
      case NotificationCategory.post_rejection:
        return Colors.red[800]!;
      case NotificationCategory.account_unsuspension:
        return Colors.green;
      case NotificationCategory.report_resolved:
        return Colors.red;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, h:mm a').format(timestamp);
  }
}
