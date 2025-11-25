import 'package:flutter/material.dart';
import '../../../services/user/auth_service.dart';
import '../../../services/user/matching_service.dart';
import '../../../services/user/hybrid_matching_engine.dart';
import '../../../models/user/job_match.dart';
import '../booking/jobseeker_booking_page.dart';
import '../booking/recruiter_booking_page.dart';
import '../message/messaging_page.dart';
import '../../../utils/user/dialog_utils.dart';
import '../../../utils/user/date_utils.dart' as DateUtilsHelper;
import '../../../utils/user/card_decorations.dart';
import '../../../utils/user/button_styles.dart';
import '../../../widgets/user/empty_state.dart';

class MatchingInteractionPage extends StatefulWidget {
  const MatchingInteractionPage({super.key});

  @override
  State<MatchingInteractionPage> createState() =>
      _MatchingInteractionPageState();
}

class _MatchingInteractionPageState extends State<MatchingInteractionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final userDoc = await _authService.getUserDoc();
      if (!mounted) return;
      // Defer setState to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _userRole = userDoc.data()?['role'] as String? ?? 'jobseeker';
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      // Defer setState to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _userRole = 'jobseeker';
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRecruiter = _userRole == 'recruiter';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Matching & Interaction',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00C8A0),
          labelColor: const Color(0xFF00C8A0),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Matches'),
            Tab(text: 'Bookings'),
            Tab(text: 'Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MatchesTab(isRecruiter: isRecruiter),
          isRecruiter
              ? const RecruiterBookingPage()
              : const JobseekerBookingPage(),
          MessagingPage(),
        ],
      ),
    );
  }
}

class _MatchesTab extends StatefulWidget {
  final bool isRecruiter;

  const _MatchesTab({required this.isRecruiter});

  @override
  State<_MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<_MatchesTab> {
  final MatchingService _matchingService = MatchingService();
  bool _recomputing = false;
  MatchingStrategy _selectedStrategy = MatchingStrategy.embeddingsAnn;

  Future<void> _handleRecompute() async {
    if (_recomputing) return;
    setState(() => _recomputing = true);
    try {
      await _matchingService.recomputeMatches(
        role: widget.isRecruiter ? 'recruiter' : 'jobseeker',
        strategy: widget.isRecruiter ? _selectedStrategy : MatchingStrategy.embeddingsAnn,
      );
      if (!mounted) return;
      DialogUtils.showSuccessMessage(
        context: context,
        message: _selectedStrategy == MatchingStrategy.stableOptimal
            ? 'Precise matching completed'
            : 'Matching engine refreshed',
      );
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Unable to refresh matches right now',
      );
    } finally {
      if (mounted) {
        setState(() => _recomputing = false);
      }
    }
  }

  /// Convert MatchingStrategy enum to Firestore string value
  String _strategyToFirestoreString(MatchingStrategy strategy) {
    switch (strategy) {
      case MatchingStrategy.embeddingsAnn:
        return 'embedding_ann';
      case MatchingStrategy.stableOptimal:
        return 'stable_optimal';
    }
  }

  /// Filter matches by selected strategy
  List<JobMatch> _filterMatchesByStrategy(List<JobMatch> matches, MatchingStrategy strategy) {
    final strategyString = _strategyToFirestoreString(strategy);
    return matches.where((match) {
      // If match has no strategy field, include it (backward compatibility)
      if (match.matchingStrategy == null) return true;
      // Filter by matching strategy
      return match.matchingStrategy == strategyString;
    }).toList();
  }

  void _showStrategySelector() {
    MatchingStrategy tempStrategy = _selectedStrategy;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Matching Strategy',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to find candidates for your jobs',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              _StrategyOption(
                title: 'Quick Recommendation',
                description: 'Fast matching with multiple candidates per job',
                strategy: MatchingStrategy.embeddingsAnn,
                selected: tempStrategy == MatchingStrategy.embeddingsAnn,
                icon: Icons.auto_awesome,
                onTap: () {
                  setModalState(() {
                    tempStrategy = MatchingStrategy.embeddingsAnn;
                  });
                },
              ),
              const SizedBox(height: 12),
              _StrategyOption(
                title: 'Precise Matching',
                description: 'Optimal one-to-one assignment (Gale-Shapley + Hungarian)',
                strategy: MatchingStrategy.stableOptimal,
                selected: tempStrategy == MatchingStrategy.stableOptimal,
                icon: Icons.precision_manufacturing,
                onTap: () {
                  setModalState(() {
                    tempStrategy = MatchingStrategy.stableOptimal;
                  });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _recomputing
                      ? null
                      : () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedStrategy = tempStrategy;
                          });
                          _handleRecompute();
                        },
                  style: ButtonStyles.primaryFilled(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    _recomputing
                        ? 'Running...'
                        : 'Run Matching with Selected Strategy',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (tempStrategy != _selectedStrategy)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedStrategy = tempStrategy;
                      });
                    },
                    style: ButtonStyles.primaryOutlined(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Switch View (Show Existing Results)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (tempStrategy != _selectedStrategy) const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!widget.isRecruiter)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF00C8A0).withOpacity(0.05),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8A0).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                    color: const Color(0xFF00C8A0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recommended for You',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Based on your skills and preferences',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              if (widget.isRecruiter)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedStrategy == MatchingStrategy.stableOptimal
                              ? 'Precise Matching: One candidate per job'
                              : 'Quick Recommendation: Multiple candidates per job',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _recomputing ? null : _showStrategySelector,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.isRecruiter)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _recomputing ? null : _handleRecompute,
                      style: ButtonStyles.primaryFilled(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_recomputing)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          else
                            const Icon(Icons.refresh, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _recomputing
                                ? 'Running Matching...'
                                : 'Run Matching',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<JobMatch>>(
            stream: _matchingService.streamJobMatches(
              role: widget.isRecruiter ? 'recruiter' : 'jobseeker',
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: const Color(0xFF00C8A0),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load matches',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please try again later',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              final allMatches = snapshot.data ?? [];
              
              // Filter matches by selected strategy (for recruiters only)
              final matches = widget.isRecruiter
                  ? _filterMatchesByStrategy(allMatches, _selectedStrategy)
                  : allMatches;

              if (matches.isEmpty) {
                return EmptyState.noMatches(
                  isRecruiter: widget.isRecruiter,
                  action: FilledButton(
                    onPressed: _recomputing ? null : _handleRecompute,
                    style: ButtonStyles.primaryFilled(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                    ),
                    child: Text(
                      _recomputing
                          ? 'Recomputing…'
                          : 'Generate smart matches',
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final match = matches[index];
                  return _JobMatchCard(
                    match: match,
                    isRecruiter: widget.isRecruiter,
                    formatTimeAgo: DateUtilsHelper.DateUtils.formatTimeAgoShort,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _JobMatchCard extends StatelessWidget {
  final JobMatch match;
  final bool isRecruiter;
  final String Function(DateTime) formatTimeAgo;

  const _JobMatchCard({
    required this.match,
    required this.isRecruiter,
    required this.formatTimeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: CardDecorations.standard(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRecruiter
                            ? 'Application for ${match.jobTitle}'
                            : match.jobTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        match.companyName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isRecruiter &&
                          (match.candidateName != null &&
                              match.candidateName!.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Candidate: ${match.candidateName}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isRecruiter && match.matchPercentage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C8A0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF00C8A0).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '${match.matchPercentage}%',
                          style: const TextStyle(
                            color: Color(0xFF00C8A0),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    if (match.matchingStrategy != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _formatStrategy(match.matchingStrategy!),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3E4A59),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (match.matchedSkills != null && match.matchedSkills!.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: match.matchedSkills!.take(3).map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C8A0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      skill,
                      style: const TextStyle(
                        color: Color(0xFF00C8A0),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(match.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(match.status).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getStatusText(match.status),
                    style: TextStyle(
                      color: _getStatusColor(match.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (match.createdAt != null)
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        formatTimeAgo(match.createdAt!),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!isRecruiter && match.status == 'pending')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    MatchingService().applyToJobMatch(match.id);
                    DialogUtils.showSuccessMessage(
                      context: context,
                      message: 'Application submitted successfully!',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C8A0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor: const Color(0xFF00C8A0).withOpacity(0.3),
                  ),
                  child: const Text(
                    'Apply Now',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'applied':
        return const Color(0xFF00C8A0);
      case 'interview_scheduled':
        return Colors.purple;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'applied':
        return 'Applied';
      case 'interview_scheduled':
        return 'Interview Scheduled';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Not Selected';
      default:
        return status;
    }
  }

  String _formatStrategy(String raw) {
    switch (raw) {
      case 'embedding_ann':
        return 'Quick Recommendation';
      case 'stable_optimal':
        return 'Precise Matching';
      case 'embedding_ann+stable_hungarian':
        return 'Stable + Hungarian';
      default:
        return raw.replaceAll('_', ' ').toUpperCase();
    }
  }
}

class _StrategyOption extends StatelessWidget {
  final String title;
  final String description;
  final MatchingStrategy strategy;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _StrategyOption({
    required this.title,
    required this.description,
    required this.strategy,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00C8A0).withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF00C8A0) : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF00C8A0).withOpacity(0.2)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: selected ? const Color(0xFF00C8A0) : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: selected ? const Color(0xFF00C8A0) : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF00C8A0),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
