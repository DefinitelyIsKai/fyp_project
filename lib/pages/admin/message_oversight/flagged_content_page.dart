import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/report_model.dart';
import 'package:fyp_project/models/admin/report_category_model.dart';
import 'package:fyp_project/services/admin/report_service.dart';
import 'package:fyp_project/services/admin/system_config_service.dart';
import 'package:fyp_project/pages/admin/message_oversight/report_detail_page.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class FlaggedContentPage extends StatefulWidget {
  const FlaggedContentPage({super.key});

  @override
  State<FlaggedContentPage> createState() => _FlaggedContentPageState();
}

class _FlaggedContentPageState extends State<FlaggedContentPage> {
  final ReportService _reportService = ReportService();
  final SystemConfigService _configService = SystemConfigService();
  String _selectedStatus = 'all';
  String _selectedType = 'all';
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isFiltersExpanded = true;
  
  List<ReportCategoryModel> _reportCategories = [];
  bool _categoriesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadReportCategories();
  }
  
  Future<void> _loadReportCategories() async {
    try {
      final categories = await _configService.getReportCategories();
      if (mounted) {
        setState(() {
          _reportCategories = categories;
          _categoriesLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading report categories: $e');
      if (mounted) {
        setState(() {
          _categoriesLoaded = true;
        });
      }
    }
  }
  
  ReportCategoryModel? _getMatchedCategory(String reportReason) {
    if (!_categoriesLoaded || _reportCategories.isEmpty) return null;
    
    try {
      
      return _reportCategories.firstWhere(
        (cat) => cat.name.toLowerCase() == reportReason.toLowerCase() && cat.isEnabled,
        orElse: () => _reportCategories.firstWhere(
          (cat) => (cat.name.toLowerCase().contains(reportReason.toLowerCase()) ||
                   reportReason.toLowerCase().contains(cat.name.toLowerCase())) && cat.isEnabled,
          orElse: () => ReportCategoryModel(
            id: '',
            name: '',
            description: '',
            isEnabled: false,
            creditDeduction: 0,
            updatedAt: DateTime.now(),
          ),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Flagged Content & Reports',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.cardRed,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        color: Colors.blue[700],
        backgroundColor: Colors.white,
        child: Column(
        children: [
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red[700],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitor and review flagged content and user reports',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

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
                
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search reports by reason or description...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 12),

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
                                        label: 'Status',
                                        value: _selectedStatus == 'all' ? 'All' : _getStatusDisplayName(_selectedStatus),
                                        onTap: () => _showStatusFilter(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _FilterChip(
                                        label: 'Type',
                                        value: _selectedType == 'all' ? 'All' : _getTypeDisplayName(_selectedType),
                                        onTap: () => _showTypeFilter(),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _FilterChip(
                                  label: 'Category',
                                  value: _selectedCategory == 'all' 
                                      ? 'All Categories' 
                                      : _reportCategories.firstWhere(
                                          (c) => c.id == _selectedCategory,
                                          orElse: () => ReportCategoryModel(
                                            id: '',
                                            name: 'Unknown',
                                            description: '',
                                            isEnabled: false,
                                            creditDeduction: 0,
                                            updatedAt: DateTime.now(),
                                          ),
                                        ).name,
                                  onTap: () => _showCategoryFilter(),
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
                                        onPressed: _clearFilters,
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
            child: StreamBuilder<List<ReportModel>>(
              stream: _getReportsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading reports...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading reports: ${snapshot.error}',
                                style: TextStyle(color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final allReports = snapshot.data ?? [];
                final filteredReports = _filterReports(allReports);

                if (filteredReports.isEmpty) {
                  return CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.flag_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No flagged content found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'All reports have been reviewed',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.grey[50],
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            '${filteredReports.length} report(s) found',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredReports.length,
                        itemBuilder: (context, index) {
                          final report = filteredReports[index];
                          return _buildReportCard(report);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedStatus != 'all' || _selectedType != 'all' || _selectedCategory != 'all';
  }

  int _getActiveFilterCount() {
    int count = 0;
    if (_selectedStatus != 'all') count++;
    if (_selectedType != 'all') count++;
    if (_selectedCategory != 'all') count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'all';
      _selectedType = 'all';
      _selectedCategory = 'all';
      _searchQuery = '';
    });
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'underReview':
        return 'Under Review';
      case 'resolved':
        return 'Resolved';
      case 'dismissed':
        return 'Dismissed';
      default:
        return 'All';
    }
  }

  String _getTypeDisplayName(String type) {
    switch (type) {
      case 'post':
        return 'Post Report';
      case 'jobseeker':
        return 'Jobseeker Report';
      case 'message':
        return 'Message';
      case 'other':
        return 'Other';
      default:
        return 'All';
    }
  }

  void _showStatusFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...['all', 'pending', 'resolved', 'dismissed'].map((status) {
              return ListTile(
                title: Text(status == 'all' ? 'All Status' : _getStatusDisplayName(status)),
                trailing: _selectedStatus == status
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _selectedStatus = status);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showTypeFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...['all', 'post', 'jobseeker'].map((type) {
              return ListTile(
                title: Text(type == 'all' ? 'All Types' : _getTypeDisplayName(type)),
                trailing: _selectedType == type
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _selectedType = type);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
  
  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Text(
                    'Select Report Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('All Categories'),
                      trailing: _selectedCategory == 'all'
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      onTap: () {
                        setState(() => _selectedCategory = 'all');
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(),
                    if (_categoriesLoaded && _reportCategories.isNotEmpty)
                      ..._reportCategories.where((c) => c.isEnabled).map((category) {
                        return ListTile(
                          title: Text(category.name),
                          subtitle: Text('${category.creditDeduction} credits deduction'),
                          trailing: _selectedCategory == category.id
                              ? const Icon(Icons.check, color: Colors.blue)
                              : null,
                          onTap: () {
                            setState(() => _selectedCategory = category.id);
                            Navigator.pop(context);
                          },
                        );
                      })
                    else if (!_categoriesLoaded)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No categories available'),
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

  Stream<List<ReportModel>> _getReportsStream() {
    if (_selectedStatus == 'all') {
      return _reportService.streamAllReports();
    } else {
      return _reportService.streamReportsByStatus(_selectedStatus);
    }
  }

  List<ReportModel> _filterReports(List<ReportModel> reports) {
    return reports.where((report) {
      
      bool matchesType = true;
      if (_selectedType != 'all') {
        if (_selectedType == 'post') {
          matchesType = report.reportType == ReportType.jobPost;
        } else if (_selectedType == 'jobseeker' || _selectedType == 'employee') {
          matchesType = report.reportType == ReportType.user;
        } else {
          matchesType = report.reportType.toString().split('.').last == _selectedType;
        }
      }

      bool matchesCategory = true;
      if (_selectedCategory != 'all') {
        final matchedCategory = _getMatchedCategory(report.reason);
        matchesCategory = matchedCategory != null && matchedCategory.id == _selectedCategory;
      }

      final matchesSearch = _searchQuery.isEmpty ||
          report.reason.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (report.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      return matchesType && matchesCategory && matchesSearch;
    }).toList();
  }

  Widget _buildReportCard(ReportModel report) {
    final statusColor = _getStatusColor(report.status);
    final typeIcon = _getReportIcon(report.reportType);
    final matchedCategory = _getMatchedCategory(report.reason);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: report.status == ReportStatus.pending
            ? BorderSide(color: Colors.red[300]!, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailPage(report: report),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
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
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(typeIcon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.reason,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getReportTypeLabel(report.reportType),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        
                        if (matchedCategory != null && matchedCategory.id.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance_wallet, size: 12, color: Colors.orange[700]),
                                const SizedBox(width: 4),
                                Text(
                                  '${matchedCategory.creditDeduction} credits deduction',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      _getStatusLabel(report.status),
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (report.description != null && report.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.description!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Reported ${_formatTimeAgo(report.reportedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (report.status == ReportStatus.pending)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.priority_high, size: 12, color: Colors.red[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Action Required',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
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

  String _getReportTypeLabel(ReportType type) {
    switch (type) {
      case ReportType.jobPost:
        return 'Post Report';
      case ReportType.user:
        return 'Jobseeker Report';
      case ReportType.message:
        return 'Message Report';
      default:
        return 'Other Report';
    }
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.red;
      case ReportStatus.underReview:
        return Colors.orange;
      case ReportStatus.resolved:
        return Colors.green;
      case ReportStatus.dismissed:
        return Colors.grey;
    }
  }

  String _getStatusLabel(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return 'PENDING';
      case ReportStatus.underReview:
        return 'UNDER REVIEW';
      case ReportStatus.resolved:
        return 'RESOLVED';
      case ReportStatus.dismissed:
        return 'DISMISSED';
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s) ago';
    } else {
      return 'Just now';
    }
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
    final isActive = value != 'All';
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
