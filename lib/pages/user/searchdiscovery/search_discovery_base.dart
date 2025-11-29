import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/user/post.dart';
import '../../../services/user/post_service.dart';
import '../../../services/user/category_service.dart';
import '../../../utils/user/dialog_utils.dart';
import '../../../utils/user/map_helper.dart';
import '../../../utils/user/post_utils.dart';
import '../../../widgets/user/search_discovery_widgets.dart';
import '../../../widgets/admin/dialogs/user_dialogs/search_filter_dialog.dart';
import 'dart:async';

/// Base class for shared search/discovery functionality
abstract class SearchDiscoveryBase extends StatefulWidget {
  const SearchDiscoveryBase({super.key, this.initialSelectedEvents});

  final List<String>? initialSelectedEvents;
}

abstract class SearchDiscoveryBaseState<T extends SearchDiscoveryBase>
    extends State<T> {
  final TextEditingController _searchController = TextEditingController();
  final PostService _postService = PostService();
  final CategoryService _categoryService = CategoryService();

  String? _searchQuery;
  String? _locationFilter;
  double? _minBudget;
  double? _maxBudget;
  List<String> _selectedEvents = [];
  bool _isMapView = false;

  GoogleMapController? _mapController;
  final Map<MarkerId, Marker> _markers = {};
  LatLng? _userLocation;
  double? _searchRadius;
  BitmapDescriptor? _userLocationIcon;
  final Set<Circle> _userCircles = <Circle>{};
  bool _showJobMarkers = false;
  bool _mapReady = false;
  String? _mapError;
  bool _mapChannelReady = false;
  Timer? _delayedMapUpdateTimer;
  Timer? _searchDebounceTimer;
  static const Duration _searchDebounceDelay = Duration(milliseconds: 300);

  final PageController _pageController = PageController();
  List<List<Post>> _pages = [];
  int _currentPage = 0;
  List<Post>? _lastPosts;
  static const int _itemsPerPage = 10;

  // Cache for posts stream to avoid multiple stream creation
  Stream<List<Post>>? _cachedPostsStream;

  Future<void> refreshData() async {
    setState(() {
      // Clear cached stream to force refresh
      _cachedPostsStream = null;
      _lastPosts = null;
      _pages = [];
      _currentPage = 0;
    });
    // Re-fetch location if needed
    _getCurrentLocation();
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  void initState() {
    super.initState();
    // Clear any cached data when widget is recreated (e.g., role switch)
    _cachedPostsStream = null;
    _lastPosts = null;
    _pages = [];
    _currentPage = 0;
    
    // Apply initial filters if provided
    if (widget.initialSelectedEvents != null &&
        widget.initialSelectedEvents!.isNotEmpty) {
      _selectedEvents = List<String>.from(widget.initialSelectedEvents!);
    }
    
    // Add listener for real-time search updates
    _searchController.addListener(_onSearchTextChanged);
    
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _delayedMapUpdateTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _mapController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Getters for subclasses
  String? get searchQuery => _searchQuery;
  String? get locationFilter => _locationFilter;
  double? get minBudget => _minBudget;
  double? get maxBudget => _maxBudget;
  List<String> get selectedEvents => _selectedEvents;
  bool get isMapView => _isMapView;
  LatLng? get userLocation => _userLocation;
  double? get searchRadius => _searchRadius;
  GoogleMapController? get mapController => _mapController;
  Map<MarkerId, Marker> get markers => _markers;
  Set<Circle> get userCircles => _userCircles;
  bool get showJobMarkers => _showJobMarkers;
  bool get mapReady => _mapReady;
  String? get mapError => _mapError;
  bool get mapChannelReady => _mapChannelReady;
  PageController get pageController => _pageController;
  List<List<Post>> get pages => _pages;
  int get currentPage => _currentPage;
  List<Post>? get lastPosts => _lastPosts;
  PostService get postService => _postService;
  CategoryService get categoryService => _categoryService;
  TextEditingController get searchController => _searchController;

  // Setters for subclasses
  void setMapView(bool value) {
    setState(() {
      _isMapView = value;
      if (value) {
        // Only reset map state if map controller doesn't exist yet
        // This prevents unnecessary map recreation when switching views
        if (_mapController == null) {
          _mapReady = false;
          _mapError = null;
          _showJobMarkers = false;
        }
      }
    });
  }

  void setMapReady(bool value) {
    setState(() => _mapReady = value);
  }

  void setMapError(String? value) {
    setState(() => _mapError = value);
  }

  void setShowJobMarkers(bool value) {
    setState(() => _showJobMarkers = value);
  }

  void setMapChannelReady(bool value) {
    _mapChannelReady = value;
  }

  void setMapController(GoogleMapController? controller) {
    _mapController = controller;
  }

  void setCurrentPage(int page) {
    setState(() => _currentPage = page);
  }

  void setUserLocation(LatLng? location) {
    setState(() => _userLocation = location);
  }

  void setUserLocationIcon(BitmapDescriptor? icon) {
    _userLocationIcon = icon;
  }

  BitmapDescriptor? get userLocationIcon => _userLocationIcon;

  /// Handle real-time search text changes with debouncing
  void _onSearchTextChanged() {
    // Cancel previous timer if it exists
    _searchDebounceTimer?.cancel();
    
    // Create a new timer that will trigger search after user stops typing
    _searchDebounceTimer = Timer(_searchDebounceDelay, () {
      if (mounted) {
        _performSearch();
      }
    });
  }

  void _performSearch() {
    if (!mounted) return;
    setState(() {
      _searchQuery = _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim();
      // Invalidate cache when search changes
      _cachedPostsStream = null;
    });
    if (_isMapView) {
      _updateMapMarkers();
    }
  }

  /// Get the posts stream with caching to prevent duplicate stream creation
  Stream<List<Post>> getPostsStream() {
    if (_cachedPostsStream != null) {
      return _cachedPostsStream!;
    }

    // Create the stream once and cache it
    // The stream will be recreated when filters change (cache is cleared)
    _cachedPostsStream = _postService.searchPosts(
      query: _searchQuery,
      location: _locationFilter,
      minBudget: _minBudget,
      maxBudget: _maxBudget,
      industries: _selectedEvents.isEmpty ? null : _selectedEvents,
    );

    return _cachedPostsStream!;
  }

  // Calculate distance between two coordinates in kilometers
  double calculateDistance(LatLng point1, LatLng point2) {
    return MapHelper.calculateDistance(point1, point2);
  }

  // Filter posts by distance from user location if search radius is set
  List<Post> filterPostsByDistance(List<Post> posts) {
    if (_userLocation == null || _searchRadius == null) {
      return posts;
    }

    return posts.where((post) {
      if (post.latitude != null && post.longitude != null) {
        final postLocation = LatLng(post.latitude!, post.longitude!);
        final distance = calculateDistance(_userLocation!, postLocation);
        return distance <= _searchRadius!;
      } else if (post.location.isNotEmpty) {
        // Include posts with location text but no coordinates
        // They will be filtered during marker creation if needed
        return true;
      } else {
        return false; // Skip posts without location
      }
    }).toList();
  }

  // Create a simple circular dot marker bitmap
  Future<BitmapDescriptor> createDotMarker(
    Color color, {
    int size = 96,
  }) async {
    return MapHelper.createDotMarker(color, size: size);
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          DialogUtils.showWarningMessage(
            context: context,
            message:
                'Location services are disabled. Please enable location services.',
          );
        }
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            DialogUtils.showWarningMessage(
              context: context,
              message: 'Location permissions are denied.',
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          DialogUtils.showWarningMessage(
            context: context,
            message:
                'Location permissions are permanently denied. Please enable in settings.',
          );
        }
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Prepare custom user icon once
      _userLocationIcon ??= await MapHelper.createDotMarker(const Color(0xFF00C8A0));

      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _userCircles
          ..clear()
          ..add(
            Circle(
              circleId: const CircleId('user_accuracy'),
              center: _userLocation!,
              radius: 2000,
              fillColor: const Color(0x3300C8A0),
              strokeColor: const Color(0xFF00C8A0),
              strokeWidth: 1,
            ),
          );
        // Clear cache when user location changes to recalculate distance filters
        _cachedPostsStream = null;
      });

      // Center map on user location if map view is active
      if (_isMapView && _mapController != null && mounted && _mapChannelReady) {
        final success = await MapHelper.safeCameraOperation(
          _mapController!,
          () => _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_userLocation!, 12),
          ),
        );
        if (!success) {
          // Try moveCamera as fallback
          await MapHelper.safeCameraOperation(
            _mapController!,
            () => _mapController!.moveCamera(
              CameraUpdate.newLatLngZoom(_userLocation!, 12),
            ),
          );
        }
        // After centering on user, enable job markers and load them
        // Only update if markers aren't already shown to prevent duplicate calls
        if (mounted && !_showJobMarkers) {
          setState(() => _showJobMarkers = true);
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted && _mapController != null) {
              await _updateMapMarkers();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        DialogUtils.showWarningMessage(
          context: context,
          message: 'Error getting location: $e',
        );
      }
    }
  }

  /// Safely call camera operations with retry logic
  Future<bool> safeCameraOperation(
    Future<void> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    if (_mapController == null) return false;
    final success = await MapHelper.safeCameraOperation(
      _mapController!,
      operation,
      maxRetries: maxRetries,
      initialDelay: initialDelay,
    );
    if (success && !_mapChannelReady) {
      _mapChannelReady = true;
    } else if (!success) {
      _mapChannelReady = false;
    }
    return success;
  }

  Future<void> _updateMapMarkers() async {
    if (!mounted) return;
    if (!_isMapView) return;
    if (!_showJobMarkers) return; // wait until user location has been shown

    var posts = await _postService
        .searchPosts(
          query: _searchQuery,
          location: _locationFilter,
          minBudget: _minBudget,
          maxBudget: _maxBudget,
          industries: _selectedEvents.isEmpty ? null : _selectedEvents,
        )
        .first;

    if (!mounted) return; // Check again after async operation

    // Filter posts - implemented by subclasses
    posts = filterPostsForUser(posts);

    _markers.clear();

    // Filter posts by distance from user location if available
    List<Post> nearbyPosts = posts;
    if (_userLocation != null && _searchRadius != null) {
      nearbyPosts = posts.where((post) {
        if (post.latitude != null && post.longitude != null) {
          final postLocation = LatLng(post.latitude!, post.longitude!);
          final distance = calculateDistance(_userLocation!, postLocation);
          return distance <= _searchRadius!;
        } else if (post.location.isNotEmpty) {
          // We'll need to geocode this, but for now include it
          // Will be filtered during marker creation
          return true;
        } else {
          return false; // Skip posts without location
        }
      }).toList();
    }

    for (final post in nearbyPosts) {
      // Use stored coordinates if available, otherwise try geocoding
      LatLng? position;

      if (post.latitude != null && post.longitude != null) {
        // Use stored coordinates
        position = LatLng(post.latitude!, post.longitude!);
      } else if (post.location.isNotEmpty) {
        // Fallback to geocoding if coordinates not available
        if (!mounted) return; // Check before async geocoding
        try {
          final locations = await locationFromAddress(post.location);
          if (!mounted) return; // Check after async geocoding
          if (locations.isNotEmpty) {
            position = LatLng(
              locations.first.latitude,
              locations.first.longitude,
            );

            // Check distance if we have user location
            if (_userLocation != null && _searchRadius != null) {
              final distance = calculateDistance(_userLocation!, position);
              if (distance > _searchRadius!) {
                continue; // Skip if too far
              }
            }
          }
        } catch (e) {
          debugPrint('Error geocoding location ${post.location}: $e');
          continue; // Skip this post if geocoding fails
        }
      } else {
        continue; // Skip posts without location
      }

      if (position != null) {
        // Calculate distance for info window
        String distanceText = '';
        if (_userLocation != null) {
          final distance = calculateDistance(_userLocation!, position);
          distanceText = ' (${distance.toStringAsFixed(1)} km away)';
        }

        final markerId = MarkerId(post.id);
        final marker = Marker(
          markerId: markerId,
          position: position,
          infoWindow: InfoWindow(
            title: post.title,
            snippet:
                '${post.location.isNotEmpty ? post.location : 'No address'}$distanceText',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => onPostTap(post),
                ),
              );
            },
          ),
        );
        _markers[markerId] = marker;
      }
    }

    if (mounted) {
      setState(() {});

      // Center map on user location if available, otherwise fit to markers
      if (_userLocation != null && _mapController != null && _mapChannelReady) {
        if (_markers.isEmpty) {
          // No nearby jobs, show user location with distance range circle if enabled
          double zoomLevel = 12;
          if (_searchRadius != null) {
            zoomLevel = 15 - (_searchRadius! / 10).clamp(0, 7);
          }
          await MapHelper.safeCameraOperation(
            _mapController!,
            () => _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_userLocation!, zoomLevel),
            ),
          );
        } else {
          // Fit map to show user location and all markers with padding
          final allPoints = [
            _userLocation!,
            ..._markers.values.map((m) => m.position),
          ];
          final bounds = calculateBounds(allPoints);
          // Add padding based on search radius to ensure all markers are visible
          await MapHelper.safeCameraOperation(
            _mapController!,
            () => _mapController!.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 100),
            ),
          );
        }
        // Update user circle to reflect search radius
        if (mounted) {
          setState(() {
            _userCircles.clear();
            if (_searchRadius != null) {
              _userCircles.add(
                Circle(
                  circleId: const CircleId('user_radius'),
                  center: _userLocation!,
                  radius: _searchRadius! * 1000, // Convert km to meters
                  fillColor: const Color(0x3300C8A0), // translucent teal
                  strokeColor: const Color(0xFF00C8A0),
                  strokeWidth: 2,
                ),
              );
            } else {
              _userCircles.add(
                Circle(
                  circleId: const CircleId('user_accuracy'),
                  center: _userLocation!,
                  radius: 2000, // default accuracy circle
                  fillColor: const Color(0x3300C8A0),
                  strokeColor: const Color(0xFF00C8A0),
                  strokeWidth: 1,
                ),
              );
            }
          });
        }
      } else if (_markers.isNotEmpty &&
          _mapController != null &&
          _mapChannelReady) {
        // No user location, just fit to markers
        final bounds = calculateBounds(
          _markers.values.map((m) => m.position).toList(),
        );
        await MapHelper.safeCameraOperation(
          _mapController!,
          () => _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50),
          ),
        );
      }
    }
  }

  LatLngBounds calculateBounds(List<LatLng> points) {
    return MapHelper.calculateBounds(points);
  }

  Future<void> showCombinedFilter() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SearchFilterDialog(
        location: _locationFilter,
        minBudget: _minBudget,
        maxBudget: _maxBudget,
        distanceRange: _searchRadius,
        selectedEvents: _selectedEvents,
        categoryService: _categoryService,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _locationFilter = result['location'] as String?;
        _minBudget = result['minBudget'] as double?;
        _maxBudget = result['maxBudget'] as double?;
        _searchRadius = result['distanceRange'] as double?;
        final events = result['events'] as List<String>? ?? const [];
        _selectedEvents = List<String>.from(events);
        // Invalidate cache when filters change
        _cachedPostsStream = null;
      });
      if (_isMapView) {
        _updateMapMarkers();
      }
    }
  }

  // Abstract methods for subclasses to implement
  List<Post> filterPostsForUser(List<Post> posts);
  Widget onPostTap(Post post);
  String getResultsHeaderText(int count);
  Widget buildPostCard(Post post, double? distance);

  // Helper methods
  void updatePages(List<Post> posts) {
    final postsChanged =
        _lastPosts == null ||
        _lastPosts!.length != posts.length ||
        !PostUtils.listsEqual(_lastPosts!, posts) ||
        PostUtils.postsContentChanged(_lastPosts, posts);

    if (postsChanged) {
      _lastPosts = posts;
      final newPages = PostUtils.computePages(posts, itemsPerPage: _itemsPerPage);
      // Always defer setState to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _pages = newPages;
            if (_currentPage >= _pages.length) {
              _currentPage = _pages.length > 0 ? _pages.length - 1 : 0;
            }
          });
        }
      });
    }
  }

  // Build methods
  Widget buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
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
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: getSearchHintText(),
            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
            suffixIcon: IconButton(
              icon: Icon(Icons.clear, color: Colors.grey[600]),
              onPressed: () {
                // Cancel any pending search timer
                _searchDebounceTimer?.cancel();
                _searchController.clear();
                // Immediately update search since user explicitly cleared
                if (mounted) {
                  setState(() {
                    _searchQuery = null;
                    // Invalidate cache when search is cleared
                    _cachedPostsStream = null;
                  });
                }
                if (_isMapView) {
                  _updateMapMarkers();
                }
              },
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onSubmitted: (_) {
            // Cancel debounce timer and perform search immediately on submit
            _searchDebounceTimer?.cancel();
            _performSearch();
          },
        ),
      ),
    );
  }

  Widget buildFilterButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          FilterButton(
            label: 'Filters',
            isActive:
                _minBudget != null ||
                _maxBudget != null ||
                _locationFilter != null ||
                _searchRadius != null ||
                _selectedEvents.isNotEmpty,
            onTap: showCombinedFilter,
          ),
        ],
      ),
    );
  }

  String getSearchHintText() => 'Search jobs...';

  // Build map view - to be implemented by subclasses or use default
  Widget buildMapView() {
    // Set initial camera position based on user location or default
    LatLng initialTarget =
        _userLocation ??
        const LatLng(2.7456, 101.7072); // Default to Malaysia center
    double initialZoom = _userLocation != null ? 12 : 5;

    // Combine user location marker and job markers
    // 只显示 job 标记，用户位置使用系统位置指示器（myLocationEnabled）
    Set<Marker> allMarkers = _showJobMarkers
        ? Set.from(_markers.values)
        : <Marker>{};
    // 移除自定义用户位置标记，使用系统位置指示器

    return Stack(
      children: [
        GoogleMap(
          key: const ValueKey('search_discovery_map'), // Stable key to prevent recreation
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: initialZoom,
          ),
          markers: allMarkers,
          circles: _userCircles,
          onMapCreated: (GoogleMapController controller) async {
            // Prevent multiple initializations if map is already created
            if (_mapController != null && _mapController != controller) {
              debugPrint('Map controller already exists, skipping initialization');
              return;
            }
            _mapController = controller;
            debugPrint('GoogleMap created successfully');

            // Wait longer for map to fully initialize before doing operations
            await Future.delayed(const Duration(milliseconds: 1500));

            if (!mounted) return;

            try {
              await Future.delayed(const Duration(milliseconds: 500));

              try {
                final testPosition =
                    _userLocation ?? const LatLng(2.7456, 101.7072);
                await controller.moveCamera(
                  CameraUpdate.newLatLngZoom(testPosition, 10),
                );
                _mapChannelReady = true;
                debugPrint('Map channel is ready');
              } catch (e) {
                debugPrint('Map channel not ready yet: $e');
                await Future.delayed(const Duration(milliseconds: 1000));
                try {
                  final testPosition =
                      _userLocation ?? const LatLng(2.7456, 101.7072);
                  await controller.moveCamera(
                    CameraUpdate.newLatLngZoom(testPosition, 10),
                  );
                  _mapChannelReady = true;
                  debugPrint('Map channel ready after retry');
                } catch (e2) {
                  debugPrint('Map channel still not ready: $e2');
                  _mapChannelReady = false;
                  if (mounted) {
                    setState(() {
                      _mapReady = true;
                      _mapError =
                          'Unable to initialize map. Please check API key and SHA-1 fingerprint in Google Cloud Console.';
                    });
                  }
                  return;
                }
              }

              if (!_mapChannelReady) {
                if (mounted) {
                  setState(() {
                    _mapReady = true;
                    _mapError =
                        'Unable to initialize map. Please check API key and SHA-1 fingerprint.';
                  });
                }
                return;
              }

              if (_userLocation != null) {
                final success = await MapHelper.safeCameraOperation(
                  controller,
                  () => controller.animateCamera(
                    CameraUpdate.newLatLngZoom(_userLocation!, 12),
                  ),
                );
                if (!success) {
                  await MapHelper.safeCameraOperation(
                    controller,
                    () => controller.moveCamera(
                      CameraUpdate.newLatLngZoom(_userLocation!, 12),
                    ),
                  );
                }
                if (mounted) {
                  setState(() {
                    _showJobMarkers = true;
                    _mapReady = true;
                    _mapError = null;
                  });
                  // Update markers after state is set, but don't delay unnecessarily
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (mounted && _mapController != null) {
                      await _updateMapMarkers();
                    }
                  });
                }
              } else {
                if (mounted) {
                  setState(() {
                    _mapReady = true;
                    _mapError = null;
                  });
                }
                _delayedMapUpdateTimer?.cancel();
                _delayedMapUpdateTimer = Timer(
                  const Duration(milliseconds: 1000),
                  () async {
                    if (!mounted || !_mapChannelReady || _mapController != controller) return;
                    if (_userLocation != null) {
                      await MapHelper.safeCameraOperation(
                        controller,
                        () => controller.animateCamera(
                          CameraUpdate.newLatLngZoom(_userLocation!, 12),
                        ),
                      );
                      if (mounted && !_showJobMarkers) {
                        setState(() => _showJobMarkers = true);
                        // Update markers after state is set
                        WidgetsBinding.instance.addPostFrameCallback((_) async {
                          if (mounted && _mapController != null) {
                            await _updateMapMarkers();
                          }
                        });
                      }
                    }
                  },
                );
              }
            } catch (e) {
              debugPrint('Error initializing map: $e');
              if (mounted) {
                setState(() {
                  _mapError = 'Map initialization error: $e';
                  _mapReady = true;
                });
              }
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapType: MapType.normal,
          compassEnabled: true,
          zoomControlsEnabled: true,
          liteModeEnabled: false,
          trafficEnabled: false,
          buildingsEnabled: true,
          mapToolbarEnabled: true,
          onTap: (LatLng position) {
            debugPrint('Map tapped at: $position');
          },
          onCameraIdle: () {
            // Only update markers if map is ready, markers are enabled, and we have no markers
            // Add a small debounce to prevent multiple rapid calls
            if (_mapReady && _showJobMarkers && _markers.isEmpty && _mapController != null) {
              // Use a timer to debounce rapid camera idle events
              _delayedMapUpdateTimer?.cancel();
              _delayedMapUpdateTimer = Timer(const Duration(milliseconds: 300), () {
                if (mounted && _mapReady && _showJobMarkers && _markers.isEmpty) {
                  _updateMapMarkers();
                }
              });
            }
          },
        ),
        if (!_mapReady)
          Container(
            color: Colors.white.withOpacity(0.8),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: const Color(0xFF00C8A0)),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading map...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_mapError != null)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.9),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Map Error',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _mapError!,
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (!mounted) return;
                          setState(() {
                            _mapError = null;
                            _mapReady = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C8A0),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_mapReady && _markers.isEmpty && _showJobMarkers)
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No locations found',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your search filters',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}


