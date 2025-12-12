import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/user/post.dart';
import '../../../models/user/application.dart';
import '../../../services/user/application_service.dart';
import '../../../services/user/auth_service.dart';
import '../../../utils/user/post_utils.dart';
import '../../../widgets/user/search_discovery_widgets.dart';
import '../../../widgets/user/pagination_dots_widget.dart';
import '../post/post_details_page.dart';
import '../../../widgets/admin/dialogs/user_dialogs/applicants_dialog.dart';
import 'search_discovery_base.dart';
import 'dart:async';

class SearchDiscoveryRecruiterPage extends SearchDiscoveryBase {
  const SearchDiscoveryRecruiterPage({super.key, super.initialSelectedEvents});

  @override
  State<SearchDiscoveryRecruiterPage> createState() =>
      _SearchDiscoveryRecruiterPageState();
}

class _SearchDiscoveryRecruiterPageState
    extends SearchDiscoveryBaseState<SearchDiscoveryRecruiterPage> {
  final ApplicationService _applicationService = ApplicationService();
  final AuthService _authService = AuthService();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final userDoc = await _authService.getUserDoc();
      if (!mounted) return;
      setState(() {
        _currentUserId = userDoc.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentUserId = null;
      });
    }
  }

  @override
  List<Post> filterPostsForUser(List<Post> posts) {
    //recruiter owned post
    if (_currentUserId != null) {
      return posts.where((post) => post.ownerId == _currentUserId).toList();
    }
    return [];
  }

  @override
  Widget onPostTap(Post post) {
    return PostDetailsPage(post: post);
  }

  @override
  String getResultsHeaderText(int count) {
    return '$count ${count == 1 ? 'job created' : 'jobs created'}';
  }

  @override
  String getSearchHintText() => 'Search your jobs...';

  @override
  Widget buildPostCard(Post post, double? distance) {
    return _RecruiterPostCard(
      post: post,
      distance: distance,
      applicationService: _applicationService,
      currentUserId: _currentUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Jobs',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          buildSearchBar(),
          buildFilterButton(),
          const SizedBox(height: 16),
          StreamBuilder<List<Post>>(
            key: ValueKey('${searchQuery}_${locationFilter}_${minBudget}_${maxBudget}_${selectedEvents.join(",")}_${searchRadius}_${userLocation?.latitude}_${userLocation?.longitude}'),
            stream: getPostsStream(),
            builder: (context, snapshot) {
              var posts = snapshot.data ?? [];
              posts = filterPostsForUser(posts);
              //distance filter
              posts = filterPostsByDistance(posts);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      getResultsHeaderText(posts.length),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ViewToggleButton(
                            label: 'List',
                            isActive: !isMapView,
                            onTap: () {
                              if (!mounted) return;
                              setMapView(false);
                            },
                          ),
                          ViewToggleButton(
                            label: 'Map',
                            isActive: isMapView,
                            onTap: () {
                              if (!mounted) return;
                              setMapView(true);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted && mapController != null) {
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(child: isMapView ? buildMapView() : _buildListView()),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: refreshData,
      color: const Color(0xFF00C8A0),
      child: StreamBuilder<List<Post>>(
      stream: getPostsStream(),
      initialData: lastPosts, 
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load posts',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try again later',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        
        var posts = snapshot.data ?? [];
        
        if (posts.isEmpty && 
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData &&
            lastPosts == null) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: CircularProgressIndicator(color: const Color(0xFF00C8A0)),
              ),
            ),
          );
        }
        
        posts = filterPostsForUser(posts);

        List<Post> nearbyPosts = List<Post>.from(posts);
        if (userLocation != null && searchRadius != null) {
          nearbyPosts = nearbyPosts.where((post) {
            if (post.latitude != null && post.longitude != null) {
              final postLocation = LatLng(post.latitude!, post.longitude!);
              final distance = calculateDistance(userLocation!, postLocation);
              return distance <= searchRadius!;
            }
            return post.location.isNotEmpty;
          }).toList();
        }

       
        if (userLocation != null && searchRadius != null) {
          nearbyPosts.sort((a, b) {
            if (a.latitude == null || a.longitude == null) {
              if (b.latitude == null || b.longitude == null) {
                return b.createdAt.compareTo(a.createdAt);
              }
              return 1;
            }
            if (b.latitude == null || b.longitude == null) {
              return -1;
            }
            final distA = calculateDistance(
              userLocation!,
              LatLng(a.latitude!, a.longitude!),
            );
            final distB = calculateDistance(
              userLocation!,
              LatLng(b.latitude!, b.longitude!),
            );
            final distanceComparison = distA.compareTo(distB);
            if (distanceComparison == 0 || (distA - distB).abs() < 0.001) {
              return b.createdAt.compareTo(a.createdAt);
            }
            return distanceComparison;
          });
        } else {
          nearbyPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        if (nearbyPosts.isEmpty) {
          updatePages(nearbyPosts);
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 20),
                    const Text(
                      'No jobs created',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (userLocation != null && searchRadius != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'within ${searchRadius!.toStringAsFixed(0)} km',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Try adjusting your search criteria',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final computedPages = PostUtils.computePages(nearbyPosts, itemsPerPage: 10);
        
        updatePages(nearbyPosts);

        if (computedPages.isEmpty) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: CircularProgressIndicator(color: const Color(0xFF00C8A0)),
              ),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: computedPages.length,
                onPageChanged: (index) {
                  setCurrentPage(index);
                },
                itemBuilder: (context, pageIndex) {
                  final pagePosts = computedPages[pageIndex];
                  return RefreshIndicator(
                    onRefresh: refreshData,
                    color: const Color(0xFF00C8A0),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: pagePosts.length,
                      itemBuilder: (context, index) {
                        final post = pagePosts[index];
                        double? distance;
                        if (userLocation != null &&
                            post.latitude != null &&
                            post.longitude != null) {
                          distance = calculateDistance(
                            userLocation!,
                            LatLng(post.latitude!, post.longitude!),
                          );
                        }
                        return buildPostCard(post, distance);
                      },
                    ),
                  );
                },
              ),
            ),
            if (computedPages.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: PaginationDotsWidget(
                  totalPages: computedPages.length,
                  currentPage: currentPage,
                ),
              ),
          ],
        );
      },
      ),
    );
  }


}

class _RecruiterPostCard extends StatefulWidget {
  final Post post;
  final double? distance;
  final ApplicationService applicationService;
  final String? currentUserId;

  const _RecruiterPostCard({
    required this.post,
    this.distance,
    required this.applicationService,
    this.currentUserId,
  });

  @override
  State<_RecruiterPostCard> createState() => _RecruiterPostCardState();
}

class _RecruiterPostCardState extends State<_RecruiterPostCard> {
  List<Application>? _optimisticApplications;

  @override
  void initState() {
    super.initState();
    if (widget.currentUserId == widget.post.ownerId) {
      widget.applicationService
          .streamPostApplications(widget.post.id)
          .first
          .then((applications) {
        if (mounted) {
          setState(() {
            _optimisticApplications = applications;
          });
        }
      });
    }
  }

  Future<void> _showApplicants(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => ApplicantsDialog(
        post: widget.post,
        applicationService: widget.applicationService,
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailsPage(post: widget.post),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C8A0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.work_outline_rounded,
                      color: const Color(0xFF00C8A0),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.post.event,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.post.status == PostStatus.completed
                          ? Colors.grey.withOpacity(0.15)
                          : (widget.post.status == PostStatus.pending
                                ? Colors.orange.withOpacity(0.15)
                                : const Color(0xFF00C8A0).withOpacity(0.15)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.post.status == PostStatus.completed
                          ? 'Completed'
                          : (widget.post.status == PostStatus.pending
                                ? 'Pending'
                                : 'Active'),
                      style: TextStyle(
                        color: widget.post.status == PostStatus.completed
                            ? Colors.grey[700]
                            : (widget.post.status == PostStatus.pending
                                  ? Colors.orange
                                  : const Color(0xFF00C8A0)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.post.location.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.post.location,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                    if (widget.distance != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C8A0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${widget.distance!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Color(0xFF00C8A0),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              if (widget.post.location.isNotEmpty) const SizedBox(height: 12),
              if (widget.post.budgetMin != null ||
                  widget.post.budgetMax != null) ...[
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      widget.post.budgetMin != null &&
                              widget.post.budgetMax != null
                          ? 'RM ${widget.post.budgetMin!.toStringAsFixed(0)} - RM ${widget.post.budgetMax!.toStringAsFixed(0)}'
                          : widget.post.budgetMin != null
                          ? 'From RM ${widget.post.budgetMin!.toStringAsFixed(0)}'
                          : 'Up to RM ${widget.post.budgetMax!.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimeAgo(widget.post.createdAt),
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                  if (widget.currentUserId == widget.post.ownerId)
                    StreamBuilder<List<Application>>(
                      stream: widget.applicationService.streamPostApplications(
                        widget.post.id,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return ElevatedButton.icon(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.people, size: 18),
                            label: const Text('Applicants unavailable'),
                          );
                        }
                        final applications =
                            _optimisticApplications ?? (snapshot.data ?? []);
                        final pendingCount = applications
                            .where((a) => a.status == ApplicationStatus.pending)
                            .length;

                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            _optimisticApplications == null &&
                            !snapshot.hasData) {
                          return ElevatedButton.icon(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C8A0),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            label: const Text('Loading...'),
                          );
                        }
                        return ElevatedButton.icon(
                          onPressed: () => _showApplicants(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C8A0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.people, size: 18),
                          label: Text(
                            '${applications.length} Applicants${pendingCount > 0 ? ' ($pendingCount)' : ''}',
                          ),
                        );
                      },
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


