import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile/profile_page.dart';
import '../../models/user/post.dart';
import '../../models/user/category.dart';
import '../../services/user/post_service.dart';
import '../../services/user/auth_service.dart';
import '../../services/user/category_service.dart';
import '../../services/user/notification_service.dart';
import '../../utils/user/dialog_utils.dart';
import '../../utils/user/date_utils.dart' as DateUtilsHelper;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'post/post_details_page.dart';
import 'post/post_management_page.dart';
import 'searchdiscovery/search_discovery_recruiter_page.dart';
import 'searchdiscovery/search_discovery_jobseeker_page.dart';
import 'matching/matching_interaction_page.dart';
import 'reputation/reputation_page.dart';
import 'wallet/credit_wallet_page.dart';
import 'location/location_viewer_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  List<String>? _initialSearchEvents;
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _userRoleStream {
    try {
      final userId = _authService.currentUserId;
      return _firestore.collection('users').doc(userId).snapshots();
    } catch (e) {
      // Return empty stream if user not authenticated
      return const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }
  }

  String _getUserRole(DocumentSnapshot<Map<String, dynamic>>? userDoc) {
    if (userDoc == null || !userDoc.exists) return 'jobseeker';
    final data = userDoc.data();
    return (data?['role'] as String? ?? 'jobseeker').toLowerCase();
  }

  String? _getUserStatus(DocumentSnapshot<Map<String, dynamic>>? userDoc) {
    if (userDoc == null || !userDoc.exists) return null;
    final data = userDoc.data();
    return data?['status'] as String?;
  }

  bool _isSuspended(String? status) {
    if (status == null) return false;
    return status.toLowerCase() == 'suspended' || status.toLowerCase() == 'suspend';
  }

  List<Widget> _buildPages(String userRole, bool isSuspended) => [
        _HomeTab(
          onNavigateToSearch: (events) {
            if (isSuspended) {
              DialogUtils.showWarningMessage(
                context: context,
                message: 'Your account has been suspended. You can only access your profile page.',
              );
              return;
            }
            setState(() {
              _initialSearchEvents = events;
              _selectedIndex = 1;
            });
          },
          isSuspended: isSuspended,
        ),
        userRole == 'recruiter'
            ? SearchDiscoveryRecruiterPage(
                key: ValueKey('recruiter-${_initialSearchEvents?.join(',') ?? 'no-filter'}'),
                initialSelectedEvents: _initialSearchEvents,
              )
            : SearchDiscoveryJobseekerPage(
                key: ValueKey('jobseeker-${_initialSearchEvents?.join(',') ?? 'no-filter'}'),
                initialSelectedEvents: _initialSearchEvents,
              ),
        const MatchingInteractionPage(),
        const PostManagementPage(),
        const ProfilePage(),
      ];

  void _onItemTapped(int index, String? userStatus) {
    // Block navigation to all tabs except Profile (index 4) if suspended
    if (_isSuspended(userStatus) && index != 4) {
      DialogUtils.showWarningMessage(
        context: context,
        message: 'Your account has been suspended. You can only access your profile page.',
      );
      // Force navigation to Profile page
      setState(() {
        _selectedIndex = 4;
      });
      return;
    }
    
    setState(() {
      _selectedIndex = index;
      // Clear initial search events when switching away from search tab
      // This allows filters to be reset when user navigates back
      if (index != 1) {
        _initialSearchEvents = null;
      }
    });
  }

  void _showLogoutDialog(BuildContext context) async {
    await DialogUtils.showLogoutConfirmation(
      context: context,
      authService: _authService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userRoleStream,
      builder: (context, snapshot) {
        final userRole = _getUserRole(snapshot.data);
        final userStatus = _getUserStatus(snapshot.data);
        final isSuspended = _isSuspended(userStatus);
        final pages = _buildPages(userRole, isSuspended);
        
        // Force Profile page if suspended and not already on it
        if (isSuspended && _selectedIndex != 4) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedIndex = 4;
              });
            }
          });
        }
        
        return PopScope(
          canPop: false, // Prevent default back navigation
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              // Show logout confirmation dialog when trying to go back or swipe
              _showLogoutDialog(context);
            }
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 1,
              automaticallyImplyLeading: false,
              title: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    // You can replace this with your actual logo
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C8A0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.work_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'JobSeek',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.account_balance_wallet, color: Colors.grey[700]),
                  onPressed: isSuspended
                      ? () {
                          DialogUtils.showWarningMessage(
                            context: context,
                            message: 'Your account has been suspended. You can only access your profile page.',
                          );
                        }
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreditWalletPage(),
                            ),
                          );
                        },
                  tooltip: 'Credit Wallet',
                ),
                IconButton(
                  icon: Icon(Icons.stars, color: Colors.grey[700]),
                  onPressed: isSuspended
                      ? () {
                          DialogUtils.showWarningMessage(
                            context: context,
                            message: 'Your account has been suspended. You can only access your profile page.',
                          );
                        }
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ReputationPage()),
                          );
                        },
                  tooltip: 'Reputation',
                ),
              ],
            ),
            body: pages[_selectedIndex],
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) => _onItemTapped(index, userStatus),
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: const Color(0xFF00C8A0),
                unselectedItemColor: Colors.grey[600],
                selectedIconTheme: const IconThemeData(size: 24),
                unselectedIconTheme: const IconThemeData(size: 22),
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
                items: [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.search),
                    label: 'Search',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.auto_awesome_outlined),
                    label: 'Matching',
                  ),
                  const BottomNavigationBarItem(icon: Icon(Icons.post_add_outlined), label: 'Posts'),
                  BottomNavigationBarItem(
                    icon: _ProfileIconWithBadge(isSelected: _selectedIndex == 4),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeTab extends StatefulWidget {
  final void Function(List<String>? events) onNavigateToSearch;
  final bool isSuspended;

  const _HomeTab({required this.onNavigateToSearch, required this.isSuspended});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final PostService _postService = PostService();
  final AuthService _authService = AuthService();
  final CategoryService _categoryService = CategoryService();

  String? _currentLocation;
  bool _locationLoading = true;
  String? _locationError;
  String _role = 'jobseeker';
  bool _profileLoading = true;
  String? _profileError;
  Stream<List<Post>>? _popularPostsStream;
  Stream<List<Category>>? _popularCategoriesStream;

  @override
  void initState() {
    super.initState();
    _popularCategoriesStream = _categoryService.streamPopularCategories(limit: 4);
    _loadProfile();
    // Always fetch device GPS location
    _resolveDeviceLocation();
  }

  Future<void> _loadProfile() async {
    try {
      final userDoc = await _authService.getUserDoc();
      final data = userDoc.data();
      final role = (data?['role'] as String? ?? 'jobseeker').toLowerCase();
      if (!mounted) return;
      setState(() {
        _role = role;
        _profileLoading = false;
        _profileError = null;
        // If user is recruiter, show their own posts; otherwise show popular posts
        _popularPostsStream = role == 'recruiter'
            ? _postService.streamMyPosts()
            : _postService.streamPopularPosts(
                metric: PopularPostMetric.views,
              );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileError = 'Unable to load your profile';
        _profileLoading = false;
      });
    }
  }


  Future<void> _resolveDeviceLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationError = 'Location services disabled';
          _locationLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationError = 'No permission';
          _locationLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String? locationLabel;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = <String>[];
          
          // Add street address if available (most precise)
          if ((place.street ?? '').isNotEmpty) {
            parts.add(place.street!);
          } else if ((place.subThoroughfare ?? '').isNotEmpty || 
                     (place.thoroughfare ?? '').isNotEmpty) {
            final streetParts = <String>[];
            if ((place.subThoroughfare ?? '').isNotEmpty) {
              streetParts.add(place.subThoroughfare!);
            }
            if ((place.thoroughfare ?? '').isNotEmpty) {
              streetParts.add(place.thoroughfare!);
            }
            if (streetParts.isNotEmpty) {
              parts.add(streetParts.join(' '));
            }
          }
          
          // Add sub-locality (neighborhood/district) if available
          if ((place.subLocality ?? '').isNotEmpty) {
            parts.add(place.subLocality!);
          }
          
          // Add locality (city)
          if ((place.locality ?? '').isNotEmpty) {
            parts.add(place.locality!);
          }
          
          // Add postal code if available
          if ((place.postalCode ?? '').isNotEmpty) {
            parts.add(place.postalCode!);
          }
          
          // Add administrative area (state/province)
          if ((place.administrativeArea ?? '').isNotEmpty) {
            parts.add(place.administrativeArea!);
          }
          
          // Add country
          if ((place.country ?? '').isNotEmpty) {
            parts.add(place.country!);
          }
          
          locationLabel = parts.where((p) => p.trim().isNotEmpty).join(', ');
          
          // If we still don't have a good address, use formatted address
          if (locationLabel.isEmpty && (place.name ?? '').isNotEmpty) {
            locationLabel = place.name!;
          }
        }
      } catch (_) {
        // Ignore geocoding errors; fallback to coordinates
      }

      locationLabel ??=
          '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

      if (!mounted) return;
      setState(() {
        _currentLocation = locationLabel;
        _locationError = null;
        _locationLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Unable to fetch location';
        _locationLoading = false;
      });
    }
  }


  String get _roleDisplay =>
      _role == 'recruiter' ? 'Recruiter' : 'Jobseeker';

  String get _locationDisplay {
    if (_locationLoading) return 'Detecting...';
    if (_locationError != null) return _locationError!;
    return _currentLocation ?? 'Location unavailable';
  }

  String get _featuredSubtitle =>
      _role == 'recruiter'
          ? 'Your posted jobs'
          : 'Most viewed opportunities right now';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF00C8A0),
                    const Color(0xFF00C8A0).withOpacity(0.8),
                ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C8A0).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.work_outline_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Find Your Dream Job',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Thousands of opportunities waiting for you',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: widget.isSuspended
                              ? () {
                                  DialogUtils.showWarningMessage(
                                    context: context,
                                    message: 'Your account has been suspended. You can only access your profile page.',
                                  );
                                }
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LocationViewerPage(),
                                    ),
                                  );
                                },
                          borderRadius: BorderRadius.circular(10),
                          child: _InfoTile(
                            label: 'Current Location',
                            value: _locationDisplay,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoTile(
                          label: 'Your Role',
                          value:
                              _profileLoading ? 'Loading...' : _roleDisplay,
                        ),
                      ),
                    ],
                  ),
                  if (_profileError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _profileError!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF00C8A0),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () => widget.onNavigateToSearch(null),
                      child: const Text(
                        'Explore Jobs',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Featured Jobs Section
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8A0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Featured Jobs',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _featuredSubtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            // Featured job cards from Firestore
            StreamBuilder<List<Post>>(
              stream: _popularPostsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(
                        color: const Color(0xFF00C8A0),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Unable to load featured jobs',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                // Filter out drafts and limit to maximum 3 posts
                final List<Post> posts = (snapshot.data ?? <Post>[])
                    .where((p) => !p.isDraft)
                    .take(3)
                    .toList();
                if (posts.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.work_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No featured jobs available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check back later for new opportunities',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final post in posts)
                      Container(
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
                          onTap: widget.isSuspended
                              ? () {
                                  DialogUtils.showWarningMessage(
                                    context: context,
                                    message: 'Your account has been suspended. You can only access your profile page.',
                                  );
                                }
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PostDetailsPage(post: post),
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
                                            post.title,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            post.event,
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: post.status == PostStatus.completed
                                            ? Colors.grey.withOpacity(0.15)
                                            : (post.status == PostStatus.pending
                                                ? Colors.orange.withOpacity(0.15)
                                                : const Color(0xFF00C8A0).withOpacity(0.15)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        post.status == PostStatus.completed 
                                            ? 'Completed' 
                                            : (post.status == PostStatus.pending ? 'Pending' : 'Active'),
                                        style: TextStyle(
                                          color: post.status == PostStatus.completed
                                              ? Colors.grey[700]
                                              : (post.status == PostStatus.pending 
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
                                if (post.location.isNotEmpty) ...[
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
                                          post.location,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                if (post.budgetMin != null || post.budgetMax != null) ...[
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.attach_money,
                                        size: 16,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        post.budgetMin != null && post.budgetMax != null
                                            ? '\$${post.budgetMin!.toStringAsFixed(0)} - \$${post.budgetMax!.toStringAsFixed(0)}'
                                            : post.budgetMin != null
                                                ? 'From \$${post.budgetMin!.toStringAsFixed(0)}'
                                                : 'Up to \$${post.budgetMax!.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
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
                                          DateUtilsHelper.DateUtils.formatTimeAgoShort(post.createdAt),
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00C8A0),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: widget.isSuspended
                                          ? () {
                                              DialogUtils.showWarningMessage(
                                                context: context,
                                                message: 'Your account has been suspended. You can only access your profile page.',
                                              );
                                            }
                                          : () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => PostDetailsPage(post: post),
                                                ),
                                              );
                                            },
                                      child: const Text(
                                        'View Details',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Popular Categories Section
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8A0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Popular Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Category>>(
              stream: _popularCategoriesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(
                        color: const Color(0xFF00C8A0),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 32,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Unable to load categories',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final categories = snapshot.data ?? <Category>[];
                if (categories.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 32,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No categories available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5,
                  ),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return InkWell(
                      onTap: () {
                        // Navigate to search tab with this category selected
                        widget.onNavigateToSearch([category.name]);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event,
                                size: 20,
                                color: const Color(0xFF00C8A0),
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                child: Text(
                                  category.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ProfileIconWithBadge extends StatelessWidget {
  final bool isSelected;

  const _ProfileIconWithBadge({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final NotificationService notificationService = NotificationService();

    return StreamBuilder<int>(
      stream: notificationService.streamUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;
        final hasUnread = unreadCount > 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.person_outline,
              size: isSelected ? 24 : 22,
              color: isSelected
                  ? const Color(0xFF00C8A0)
                  : Colors.grey[600],
            ),
            if (hasUnread)
              Positioned(
                right: -4,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}