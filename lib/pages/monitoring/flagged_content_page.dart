import 'package:flutter/material.dart';
import 'package:fyp_project/models/report_model.dart';
import 'package:fyp_project/services/report_service.dart';
import 'package:fyp_project/pages/monitoring/report_detail_page.dart';

class FlaggedContentPage extends StatefulWidget {
  const FlaggedContentPage({super.key});

  @override
  State<FlaggedContentPage> createState() => _FlaggedContentPageState();
}

class _FlaggedContentPageState extends State<FlaggedContentPage> {
  final ReportService _reportService = ReportService();
  List<ReportModel> _reports = [];
  List<ReportModel> _filteredReports = [];
  bool _isLoading = true;
  String _selectedStatus = 'pending';
  String _selectedType = 'all';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final reports = await _reportService.getAllReports();
      setState(() {
        _reports = reports;
        _filteredReports = reports;
      });
      _filterReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterReports() {
    setState(() {
      _filteredReports = _reports.where((report) {
        final matchesStatus = _selectedStatus == 'all' ||
            report.status.toString().split('.').last == _selectedStatus;
        final matchesType = _selectedType == 'all' ||
            report.reportType.toString().split('.').last == _selectedType;
        return matchesStatus && matchesType;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flagged Content')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'underReview', child: Text('Under Review')),
                      DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedStatus = value ?? 'all');
                      _filterReports();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'jobPost', child: Text('Job Post')),
                      DropdownMenuItem(value: 'user', child: Text('User')),
                      DropdownMenuItem(value: 'message', child: Text('Message')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedType = value ?? 'all');
                      _filterReports();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                    ? const Center(child: Text('No flagged content found'))
                    : ListView.builder(
                        itemCount: _filteredReports.length,
                        itemBuilder: (context, index) {
                          final report = _filteredReports[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: Icon(
                                _getReportIcon(report.reportType),
                                color: _getStatusColor(report.status),
                              ),
                              title: Text(report.reason),
                              subtitle: Text(
                                '${report.reportType.toString().split('.').last} • ${report.reportedAt.toString().split(' ')[0]}',
                              ),
                              trailing: Chip(
                                label: Text(report.status.toString().split('.').last),
                                backgroundColor: _getStatusColor(report.status),
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReportDetailPage(report: report),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  IconData _getReportIcon(ReportType type) {
    switch (type) {
      case ReportType.jobPost:
        return Icons.article;
      case ReportType.user:
        return Icons.person;
      case ReportType.message:
        return Icons.message;
      default:
        return Icons.flag;
    }
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.underReview:
        return Colors.blue;
      case ReportStatus.resolved:
        return Colors.green;
      case ReportStatus.dismissed:
        return Colors.grey;
    }
  }
}

