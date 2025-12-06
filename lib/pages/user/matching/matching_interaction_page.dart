import 'package:flutter/material.dart';
import '../../../services/user/auth_service.dart';
import '../../../services/user/matching_service.dart';
import '../../../models/user/computed_match.dart';
import '../../../models/user/recruiter_match.dart';
import '../../../models/user/post.dart';
import '../../../models/user/application.dart';
import '../../../services/user/post_service.dart';
import '../../../services/user/application_service.dart';
import '../post/post_details_page.dart';
import '../profile/public_profile_page.dart';
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
        automaticallyImplyLeading: false,
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
  
//refresh by updating state
  Future<void> _refreshData() async {
    setState(() {
      
    });
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> _handleRecompute() async {
    if (_recomputing) return;
    setState(() => _recomputing = true);
    try {
      if (widget.isRecruiter) {
        // For recruiters, clear cache first then run the matching algorithm
        MatchingService.clearWeightsCache();
        await _matchingService.recomputeMatches(
          role: 'recruiter',
        );
        if (!mounted) return;
        DialogUtils.showSuccessMessage(
          context: context,
          message: 'Matching engine refreshed (cache cleared)',
        );
      } else {
        // For jobseekers, clear cache and trigger stream refresh
        MatchingService.clearWeightsCache();
        _matchingService.refreshComputedMatches();
        // Small delay to show refresh state
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        DialogUtils.showSuccessMessage(
          context: context,
          message: 'Matches refreshed (cache cleared)',
        );
      }
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


  /// Removed strategy selector - Recruiter now only uses ANN (embeddingsAnn)

  /// Build matches for jobseekers using real-time computation
  Widget _buildJobseekerMatches() {
    return StreamBuilder<List<ComputedMatch>>(
      stream: _matchingService.streamComputedMatches(),
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

        final matches = snapshot.data ?? [];

        return Column(
          children: [
            // Refresh button for jobseekers
            if (!widget.isRecruiter)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _recomputing ? null : _handleRecompute,
                    style: ButtonStyles.primaryFilled(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _recomputing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.refresh, size: 20),
                    label: Text(
                      _recomputing
                          ? 'Refreshing matches...'
                          : 'Refresh Matches',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            // Matches list or empty state
            Expanded(
              child: matches.isEmpty
                  ? EmptyState.noMatches(
                      isRecruiter: false,
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
                    )
                  : RefreshIndicator(
                      onRefresh: _refreshData,
                      color: const Color(0xFF00C8A0),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final match = matches[index];
                          return _ComputedMatchCard(
                            match: match,
                            formatTimeAgo: DateUtilsHelper.DateUtils.formatTimeAgoShort,
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Build matches for recruiters - shows job post list first
  Widget _buildRecruiterMatches() {
    final postService = PostService();
    return StreamBuilder<List<Post>>(
      stream: postService.streamMyPosts(),
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
                  'Unable to load job posts',
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

        final posts = snapshot.data ?? [];
        // Filter to only show active posts
        final activePosts = posts.where((post) => post.status == PostStatus.active).toList();

        if (activePosts.isEmpty) {
          return EmptyState.noMatches(
            isRecruiter: true,
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

        return RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF00C8A0),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: activePosts.length,
            itemBuilder: (context, index) {
              final post = activePosts[index];
              return _RecruiterPostCard(
                post: post,
                onTap: () => _showApplicantMatches(context, post),
              );
            },
          ),
        );
      },
    );
  }

  /// Show applicant matches for a specific post
  Future<void> _showApplicantMatches(BuildContext context, Post post) async {
    final recruiterId = AuthService().currentUserId;
    if (recruiterId.isEmpty) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00C8A0),
        ),
      ),
    );

    try {
      final matches = await _matchingService.computeMatchesForRecruiterPost(
        postId: post.id,
        recruiterId: recruiterId,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show matches in a bottom sheet or dialog
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _ApplicantMatchesSheet(
          post: post,
          matches: matches,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Unable to load applicant matches: ${e.toString()}',
      );
    }
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
                        'Optimal Matches for You',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Powered by advanced matching algorithms for best recommendations',
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
                          'Quick Recommendation: Multiple candidates per job',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900],
                            fontWeight: FontWeight.w500,
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
          child: widget.isRecruiter
              ? _buildRecruiterMatches()
              : _buildJobseekerMatches(),
        ),
      ],
    );
  }
}

// Removed _JobMatchCard - no longer used (replaced by _ComputedMatchCard and _ApplicantMatchCard)

/// Card widget for displaying computed matches (real-time, not stored)
class _ComputedMatchCard extends StatelessWidget {
  final ComputedMatch match;
  final String Function(DateTime) formatTimeAgo;

  const _ComputedMatchCard({
    required this.match,
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
                        match.post.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        match.recruiterFullName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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
                          _formatStrategy(match.matchingStrategy),
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
            if (match.matchedSkills.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: match.matchedSkills.take(3).map((skill) {
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
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    'Pending Review',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      formatTimeAgo(match.computedAt),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to post details page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailsPage(post: match.post),
                    ),
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
                  'View Details & Apply',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStrategy(String raw) {
    switch (raw) {
      case 'embedding_ann':
        return 'Quick Recommendation';
      case 'cbf_topk':
        return 'Optimal Matching';
      default:
        return raw.replaceAll('_', ' ').toUpperCase();
    }
  }
}

/// Removed _StrategyOption widget - Recruiter no longer needs strategy selection

/// Card widget for displaying recruiter's job posts
class _RecruiterPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const _RecruiterPostCard({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final matchingService = MatchingService();
    final recruiterId = AuthService().currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: CardDecorations.standard(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                          post.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          post.location.isNotEmpty ? post.location : 'Location not specified',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FutureBuilder<int>(
                    future: recruiterId.isNotEmpty
                        ? matchingService.getMatchedApplicantCount(
                            postId: post.id,
                            recruiterId: recruiterId,
                          )
                        : Future.value(0),
                    builder: (context, snapshot) {
                      final matchedCount = snapshot.data ?? 0;
                      final isLoading = snapshot.connectionState == ConnectionState.waiting;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C8A0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF00C8A0).withOpacity(0.3),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00C8A0),
                                ),
                              )
                            : Text(
                                '$matchedCount ${matchedCount == 1 ? 'matched applicant' : 'matched applicants'}',
                                style: const TextStyle(
                                  color: Color(0xFF00C8A0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    'View matched applicants',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
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
}

/// Bottom sheet showing applicant matches for a post
class _ApplicantMatchesSheet extends StatelessWidget {
  final Post post;
  final List<RecruiterMatch> matches;

  const _ApplicantMatchesSheet({
    required this.post,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${matches.length} ${matches.length == 1 ? 'matched applicant' : 'matched applicants'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Matches list
          Expanded(
            child: matches.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No applicants yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final match = matches[index];
                      return _ApplicantMatchCard(
                        match: match,
                        onStatusChanged: () {
                          // Status changed - could refresh if needed
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Card widget for displaying a matched applicant
class _ApplicantMatchCard extends StatefulWidget {
  final RecruiterMatch match;
  final VoidCallback? onStatusChanged;

  const _ApplicantMatchCard({
    required this.match,
    this.onStatusChanged,
  });

  @override
  State<_ApplicantMatchCard> createState() => _ApplicantMatchCardState();
}

class _ApplicantMatchCardState extends State<_ApplicantMatchCard> {
  late ApplicationStatus _currentStatus;
  bool _isProcessing = false;
  final _applicationService = ApplicationService();

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.match.application.status;
  }

  Future<void> _handleApprove() async {
    if (_isProcessing || _currentStatus == ApplicationStatus.approved) return;

    final confirmed = await DialogUtils.showConfirmationDialog(
      context: context,
      title: 'Approve Application',
      message: 'Are you sure you want to approve ${widget.match.jobseekerName}\'s application?',
      icon: Icons.check_circle,
      iconColor: Colors.white,
      iconBackgroundColor: const Color(0xFF00C8A0),
      confirmText: 'Approve',
      cancelText: 'Cancel',
      confirmButtonColor: const Color(0xFF00C8A0),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      await _applicationService.approveApplication(widget.match.application.id);
      
      if (!mounted) return;
      
      setState(() {
        _currentStatus = ApplicationStatus.approved;
        _isProcessing = false;
      });

      DialogUtils.showSuccessMessage(
        context: context,
        message: 'Application approved successfully!',
      );

      // Notify parent to refresh if needed
      widget.onStatusChanged?.call();
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isProcessing = false);
      
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Failed to approve application: ${e.toString()}',
      );
    }
  }

  Future<void> _handleReject() async {
    if (_isProcessing || _currentStatus == ApplicationStatus.rejected) return;

    final confirmed = await DialogUtils.showDestructiveConfirmation(
      context: context,
      title: 'Reject Application',
      message: 'Are you sure you want to reject ${widget.match.jobseekerName}\'s application?',
      icon: Icons.cancel,
      confirmText: 'Reject',
      cancelText: 'Cancel',
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      await _applicationService.rejectApplication(widget.match.application.id);
      
      if (!mounted) return;
      
      setState(() {
        _currentStatus = ApplicationStatus.rejected;
        _isProcessing = false;
      });

      DialogUtils.showSuccessMessage(
        context: context,
        message: 'Application rejected successfully!',
      );

      // Notify parent to refresh if needed
      widget.onStatusChanged?.call();
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isProcessing = false);
      
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Failed to reject application: ${e.toString()}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: CardDecorations.standard(),
      child: InkWell(
        onTap: () {
          // Navigate to applicant's public profile when card is tapped
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PublicProfilePage(userId: widget.match.jobseekerId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
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
                          widget.match.jobseekerName,
                          style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Application ID: ${widget.match.application.id.length > 8 ? widget.match.application.id.substring(0, 8) : widget.match.application.id}...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
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
                    '${widget.match.matchPercentage}%',
                    style: const TextStyle(
                      color: Color(0xFF00C8A0),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.match.matchedSkills.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.match.matchedSkills.take(5).map((skill) {
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
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_currentStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(_currentStatus).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _getStatusText(_currentStatus),
                    style: TextStyle(
                      color: _getStatusColor(_currentStatus),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Applied ${DateUtilsHelper.DateUtils.formatTimeAgoShort(widget.match.application.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                // View Profile button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PublicProfilePage(userId: widget.match.jobseekerId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person, size: 18),
                    label: const Text('View Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00C8A0),
                      side: const BorderSide(color: Color(0xFF00C8A0)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Approve/Reject buttons (only show if pending)
            if (_currentStatus == ApplicationStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  // Approve button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _handleApprove,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.check_circle, size: 18),
                      label: Text(_isProcessing ? 'Processing...' : 'Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C8A0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Reject button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _handleReject,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.cancel, size: 18),
                      label: Text(_isProcessing ? 'Processing...' : 'Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Color _getStatusColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.approved:
        return Colors.green;
      case ApplicationStatus.rejected:
        return Colors.red;
      case ApplicationStatus.deleted:
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.approved:
        return 'Approved';
      case ApplicationStatus.rejected:
        return 'Rejected';
      case ApplicationStatus.deleted:
        return 'Deleted';
      default:
        return 'Pending';
    }
  }
}
