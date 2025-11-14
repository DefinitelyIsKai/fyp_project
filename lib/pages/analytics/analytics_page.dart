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
      // Use end date for single date analytics, or implement range-based analytics
      final analytics = await _analyticsService.getAnalytics(_endDate);
      if (mounted) {
        setState(() => _analytics = analytics);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDateRange() async {
    if (!mounted) return;
    
    // Show date range picker dialog
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics & Reporting')),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Date Range',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectDateRange,
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
                                    'From',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(_startDate),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Icon(Icons.arrow_forward, color: Colors.grey),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'To',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(_endDate),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
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
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _loadAnalytics,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _analytics == null
                    ? const Center(child: Text('No analytics data available'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _AnalyticsCard(
                            title: 'Users',
                            icon: Icons.people,
                            color: Colors.blue,
                            metrics: {
                              'Total Users': _analytics!.totalUsers.toString(),
                              'Active Users': _analytics!.activeUsers.toString(),
                            },
                          ),
                          const SizedBox(height: 16),
                          _AnalyticsCard(
                            title: 'Job Posts',
                            icon: Icons.article,
                            color: Colors.green,
                            metrics: {
                              'Total Posts': _analytics!.totalJobPosts.toString(),
                              'Pending': _analytics!.pendingJobPosts.toString(),
                              'Approved': _analytics!.approvedJobPosts.toString(),
                            },
                          ),
                          const SizedBox(height: 16),
                          _AnalyticsCard(
                            title: 'Applications',
                            icon: Icons.work,
                            color: Colors.orange,
                            metrics: {
                              'Total Applications': _analytics!.totalApplications.toString(),
                            },
                          ),
                          const SizedBox(height: 16),
                          _AnalyticsCard(
                            title: 'Reports',
                            icon: Icons.flag,
                            color: Colors.red,
                            metrics: {
                              'Total Reports': _analytics!.totalReports.toString(),
                              'Pending': _analytics!.pendingReports.toString(),
                            },
                          ),
                          const SizedBox(height: 16),
                          _AnalyticsCard(
                            title: 'Messages',
                            icon: Icons.message,
                            color: Colors.purple,
                            metrics: {
                              'Total Messages': _analytics!.totalMessages.toString(),
                              'Reported': _analytics!.reportedMessages.toString(),
                            },
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AnalyticsDetailPage(analytics: _analytics!),
                              ),
                            ),
                            child: const Text('View Detailed Report'),
                          ),
                        ],
                      ),
          ),
        ],
      ),
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

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Map<String, String> metrics;

  const _AnalyticsCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.metrics,
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
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...metrics.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    Text(
                      entry.value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

