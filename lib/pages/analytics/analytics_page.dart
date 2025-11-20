import 'package:flutter/material.dart';
import 'package:fyp_project/models/analytics_model.dart';
import 'package:fyp_project/services/analytics_service.dart';
import 'package:fyp_project/pages/analytics/analytics_detail_page.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final AnalyticsService _analyticsService = AnalyticsService();
  AnalyticsModel? _analytics;
  bool _isLoading = true;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final analytics = await _analyticsService.getComprehensiveAnalytics(_endDate);
      if (mounted) {
        setState(() => _analytics = analytics);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading analytics: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    if (!mounted) return;

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (dialogContext) => _DateRangePickerDialog(
        startDate: _startDate,
        endDate: _endDate,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _startDate = result['start']!;
        _endDate = result['end']!;
      });
      _loadAnalytics();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getDateRangeText() {
    final daysDiff = _endDate.difference(_startDate).inDays;
    if (daysDiff == 1) return 'Today';
    if (daysDiff == 7) return 'Last 7 days';
    if (daysDiff == 30) return 'Last 30 days';
    if (daysDiff == 90) return 'Last 3 months';
    return '${_formatDate(_startDate)} - ${_formatDate(_endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Analytics & Reporting',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Section
          Container(
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
                  'Platform Analytics',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track usage, engagement, and platform performance',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Date Range Selector
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
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date Range',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getDateRangeText(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadAnalytics,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Analytics Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _analytics == null
                ? _buildEmptyState()
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Quick Stats Row
                  _buildQuickStats(),
                  const SizedBox(height: 20),

                  // Main Analytics Cards
                  _buildAnalyticsCards(),
                  const SizedBox(height: 20),

                  // Detailed Report Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnalyticsDetailPage(analytics: _analytics!),
                        ),
                      ),
                      icon: const Icon(Icons.analytics),
                      label: const Text(
                        'View Detailed Analytics Report',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _QuickStatCard(
            title: 'Active Users',
            value: _analytics!.activeUsers.toString(),
            subtitle: 'Online now',
            color: Colors.green,
            icon: Icons.people_alt,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickStatCard(
            title: 'Job Posts',
            value: _analytics!.totalJobPosts.toString(),
            subtitle: 'This period',
            color: Colors.blue,
            icon: Icons.article,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickStatCard(
            title: 'Engagement',
            value: '${_analytics!.engagementRate.toStringAsFixed(1)}%',
            subtitle: 'Platform usage',
            color: Colors.orange,
            icon: Icons.trending_up, // Changed from non-existent icon
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCards() {
    return Column(
      children: [
        // Usage Statistics
        _AnalyticsSectionCard(
          title: 'Usage Statistics',
          icon: Icons.analytics, // Changed to existing icon
          color: Colors.blue,
          children: [
            _MetricRow(
              label: 'Total Users',
              value: _analytics!.totalUsers.toString(),
              trend: _analytics!.userGrowthRate,
            ),
            _MetricRow(
              label: 'Active Users',
              value: _analytics!.activeUsers.toString(),
              trend: _analytics!.activeUserGrowth,
            ),
            _MetricRow(
              label: 'New Registrations',
              value: _analytics!.newRegistrations.toString(),
              trend: _analytics!.registrationGrowth,
            ),
            _MetricRow(
              label: 'Session Duration',
              value: '${_analytics!.avgSessionDuration.toStringAsFixed(1)} min',
              trend: _analytics!.sessionGrowth,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Engagement Tracking
        _AnalyticsSectionCard(
          title: 'Engagement Tracking',
          icon: Icons.trending_up, // Correct icon for engagement
          color: Colors.green,
          children: [
            _MetricRow(
              label: 'Engagement Rate',
              value: '${_analytics!.engagementRate.toStringAsFixed(1)}%',
              trend: _analytics!.engagementGrowth,
            ),
            _MetricRow(
              label: 'Job Applications',
              value: _analytics!.totalApplications.toString(),
              trend: _analytics!.applicationGrowth,
            ),
            _MetricRow(
              label: 'Messages Sent',
              value: _analytics!.totalMessages.toString(),
              trend: _analytics!.messageGrowth,
            ),
            _MetricRow(
              label: 'Profile Views',
              value: _analytics!.profileViews.toString(),
              trend: _analytics!.profileViewGrowth,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Content & Moderation
        _AnalyticsSectionCard(
          title: 'Content & Moderation',
          icon: Icons.flag,
          color: Colors.orange,
          children: [
            _MetricRow(
              label: 'Job Posts',
              value: _analytics!.totalJobPosts.toString(),
              trend: _analytics!.jobPostGrowth,
              subMetrics: {
                'Pending': _analytics!.pendingJobPosts.toString(),
                'Approved': _analytics!.approvedJobPosts.toString(),
                'Rejected': _analytics!.rejectedJobPosts.toString(),
              },
            ),
            _MetricRow(
              label: 'Reports',
              value: _analytics!.totalReports.toString(),
              trend: _analytics!.reportGrowth,
              subMetrics: {
                'Pending': _analytics!.pendingReports.toString(),
                'Resolved': _analytics!.resolvedReports.toString(),
              },
            ),
            _MetricRow(
              label: 'Reported Messages',
              value: _analytics!.reportedMessages.toString(),
              trend: _analytics!.reportedMessageGrowth,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Credit & Billing Logs
        _AnalyticsSectionCard(
          title: 'Credit & Billing',
          icon: Icons.credit_card,
          color: Colors.purple,
          children: [
            _MetricRow(
              label: 'Total Credits Used',
              value: _analytics!.totalCreditsUsed.toString(),
              trend: _analytics!.creditUsageGrowth,
            ),
            _MetricRow(
              label: 'Active Subscriptions',
              value: _analytics!.activeSubscriptions.toString(),
              trend: _analytics!.subscriptionGrowth,
            ),
            _MetricRow(
              label: 'Revenue',
              value: '\$${_analytics!.revenue.toStringAsFixed(2)}',
              trend: _analytics!.revenueGrowth,
            ),
            _MetricRow(
              label: 'Credit Purchases',
              value: _analytics!.creditPurchases.toString(),
              trend: _analytics!.purchaseGrowth,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Analytics Data',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analytics data will appear here once available',
            style: TextStyle(
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _QuickStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _AnalyticsSectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final double trend;
  final Map<String, String>? subMetrics;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.trend,
    this.subMetrics,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                if (trend != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: trend > 0 ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: trend > 0 ? Colors.green[100]! : Colors.red[100]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          trend > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 12,
                          color: trend > 0 ? Colors.green[700] : Colors.red[700],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${trend.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: trend > 0 ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (subMetrics != null && subMetrics!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: subMetrics!.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DateRangePickerDialog extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const _DateRangePickerDialog({
    required this.startDate,
    required this.endDate,
  });

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  late DateTime _tempStartDate;
  late DateTime _tempEndDate;

  @override
  void initState() {
    super.initState();
    _tempStartDate = widget.startDate;
    _tempEndDate = widget.endDate;
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempStartDate,
      firstDate: DateTime(2020),
      lastDate: _tempEndDate,
    );
    if (picked != null) {
      setState(() => _tempStartDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempEndDate,
      firstDate: _tempStartDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _tempEndDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Date Range'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _selectStartDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Date',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(_tempStartDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _selectEndDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Date',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(_tempEndDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'start': _tempStartDate,
              'end': _tempEndDate,
            });
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}