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

  Stream<List<Post>>? _cachedPostsStream;

  Future<void> refreshData() async {
    setState(() {

      _cachedPostsStream = null;
      _lastPosts = null;
      _pages = [];
      _currentPage = 0;
    });
    _getCurrentLocation();
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  void initState() {
    super.initState();
    _cachedPostsStream = null;
    _lastPosts = null;
    _pages = [];
    _currentPage = 0;
    
    if (widget.initialSelectedEvents != null &&
        widget.initialSelectedEvents!.isNotEmpty) {
      _selectedEvents = List<String>.from(widget.initialSelectedEvents!);
    }
    
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

  void setMapView(bool value) {
    setState(() {
      _isMapView = value;
      if (value) {
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

  
  void _onSearchTextChanged() {
    
    _searchDebounceTimer?.cancel();
    
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
      _cachedPostsStream = null;
    });
    if (_isMapView) {
      _updateMapMarkers();
    }
  }

  
  Stream<List<Post>> getPostsStream() {
    if (_cachedPostsStream != null) {
      return _cachedPostsStream!;
    }

   
    _cachedPostsStream = _postService.searchPosts(
      query: _searchQuery,
      location: _locationFilter,
      minBudget: _minBudget,
      maxBudget: _maxBudget,
      events: _selectedEvents.isEmpty ? null : _selectedEvents,
    );

    return _cachedPostsStream!;
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    return MapHelper.calculateDistance(point1, point2);
  }

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
        return true;
      } else {
        return false;
      }
    }).toList();
  }

  Future<BitmapDescriptor> createDotMarker(
    Color color, {
    int size = 96,
  }) async {
    return MapHelper.createDotMarker(color, size: size);
  }

  Future<void> _getCurrentLocation() async {
    try {
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

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
        _cachedPostsStream = null;
      });

      if (_isMapView && _mapController != null && mounted && _mapChannelReady) {
        final success = await MapHelper.safeCameraOperation(
          _mapController!,
          () => _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_userLocation!, 12),
          ),
        );
        if (!success) {
          await MapHelper.safeCameraOperation(
            _mapController!,
            () => _mapController!.moveCamera(
              CameraUpdate.newLatLngZoom(_userLocation!, 12),
            ),
          );
        }
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
    if (!_showJobMarkers) return;

    var posts = await _postService
        .searchPosts(
          query: _searchQuery,
          location: _locationFilter,
          minBudget: _minBudget,
          maxBudget: _maxBudget,
          events: _selectedEvents.isEmpty ? null : _selectedEvents,
        )
        .first;

    if (!mounted) return; 

    posts = filterPostsForUser(posts);

    _markers.clear();

    List<Post> nearbyPosts = posts;
    if (_userLocation != null && _searchRadius != null) {
      nearbyPosts = posts.where((post) {
        if (post.latitude != null && post.longitude != null) {
          final postLocation = LatLng(post.latitude!, post.longitude!);
          final distance = calculateDistance(_userLocation!, postLocation);
          return distance <= _searchRadius!;
        } else if (post.location.isNotEmpty) {
          return true;
        } else {
          return false;
        }
      }).toList();
    }

    for (final post in nearbyPosts) {
      LatLng? position;

      if (post.latitude != null && post.longitude != null) {
        position = LatLng(post.latitude!, post.longitude!);
      } else if (post.location.isNotEmpty) {
        if (!mounted) return; 
        try {
          final locations = await locationFromAddress(post.location);
          if (!mounted) return; 
          if (locations.isNotEmpty) {
            position = LatLng(
              locations.first.latitude,
              locations.first.longitude,
            );

            if (_userLocation != null && _searchRadius != null) {
              final distance = calculateDistance(_userLocation!, position);
              if (distance > _searchRadius!) {
                continue; 
              }
            }
          }
        } catch (e) {
          debugPrint('Error geocoding location ${post.location}: $e');
          continue; 
        }
      } else {
        continue; 
      }

      if (position != null) {
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

      if (_userLocation != null && _mapController != null && _mapChannelReady) {
        if (_markers.isEmpty) {
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
          final allPoints = [
            _userLocation!,
            ..._markers.values.map((m) => m.position),
          ];
          final bounds = calculateBounds(allPoints);
          await MapHelper.safeCameraOperation(
            _mapController!,
            () => _mapController!.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 100),
            ),
          );
        }
        if (mounted) {
          setState(() {
            _userCircles.clear();
            if (_searchRadius != null) {
              _userCircles.add(
                Circle(
                  circleId: const CircleId('user_radius'),
                  center: _userLocation!,
                  radius: _searchRadius! * 1000,
                  fillColor: const Color(0x3300C8A0), 
                  strokeColor: const Color(0xFF00C8A0),
                  strokeWidth: 2,
                ),
              );
            } else {
              _userCircles.add(
                Circle(
                  circleId: const CircleId('user_accuracy'),
                  center: _userLocation!,
                  radius: 2000, 
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
        _cachedPostsStream = null;
      });
      if (_isMapView) {
        _updateMapMarkers();
      }
    }
  }

  
  List<Post> filterPostsForUser(List<Post> posts);
  Widget onPostTap(Post post);
  String getResultsHeaderText(int count);
  Widget buildPostCard(Post post, double? distance);

  
  void updatePages(List<Post> posts) {
    final postsChanged =
        _lastPosts == null ||
        _lastPosts!.length != posts.length ||
        !PostUtils.listsEqual(_lastPosts!, posts) ||
        PostUtils.postsContentChanged(_lastPosts, posts);

    if (postsChanged) {
      _lastPosts = posts;
      final newPages = PostUtils.computePages(posts, itemsPerPage: _itemsPerPage);
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
                _searchDebounceTimer?.cancel();
                _searchController.clear();
                if (mounted) {
                  setState(() {
                    _searchQuery = null;
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

  Widget buildMapView() {
    LatLng initialTarget =
        _userLocation ??
        const LatLng(2.7456, 101.7072);
    double initialZoom = _userLocation != null ? 12 : 5;

    Set<Marker> allMarkers = _showJobMarkers
        ? Set.from(_markers.values)
        : <Marker>{};


    return Stack(
      children: [
        GoogleMap(
          key: const ValueKey('search_discovery_map'), 
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: initialZoom,
          ),
          markers: allMarkers,
          circles: _userCircles,
          onMapCreated: (GoogleMapController controller) async {
            if (_mapController != null && _mapController != controller) {
              debugPrint('Map controller already exists, skipping initialization');
              return;
            }
            _mapController = controller;
            debugPrint('GoogleMap created successfully');

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
            if (_mapReady && _showJobMarkers && _markers.isEmpty && _mapController != null) {
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


