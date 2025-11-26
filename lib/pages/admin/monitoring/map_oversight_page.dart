import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fyp_project/models/admin/job_post_model.dart';
import 'package:fyp_project/services/admin/post_service.dart';
import 'package:fyp_project/pages/admin/post_moderation/post_detail_page.dart';
import 'package:intl/intl.dart';

class MapOversightPage extends StatefulWidget {
  const MapOversightPage({super.key});

  @override
  State<MapOversightPage> createState() => _MapOversightPageState();
}

class _MapOversightPageState extends State<MapOversightPage> {
  final PostService _postService = PostService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationSearchController = TextEditingController();
  GoogleMapController? _mapController;
  
  String _selectedStatus = 'all';
  String _selectedCategory = 'all';
  String _selectedState = 'all'; // Changed from _selectedLocation to _selectedState
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isListView = false;
  bool _showFilters = true;
  
  Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _isGeocoding = false;
  
  List<JobPostModel> _posts = [];
  List<JobPostModel> _filteredPosts = [];
  Map<String, LatLng> _locationCache = {};
  Map<String, JobPostModel> _markerPostMap = {}; // Map marker ID to post
  
  // Default center (Kuala Lumpur, Malaysia)
  LatLng _center = const LatLng(3.1390, 101.6869);
  double _zoom = 10.0;

  @override
  void initState() {
    super.initState();
    _setupStreamListener();
  }

  void _setupStreamListener() {
    // Real-time updates using Firestore stream
    _postService.streamAllPosts().listen((posts) {
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
        _applyFilters();
      }
    });
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedStatus != 'all') count++;
    if (_selectedCategory != 'all') count++;
    if (_selectedState != 'all') count++;
    if (_searchQuery.isNotEmpty) count++;
    if (_startDate != null || _endDate != null) count++;
    return count;
  }

  void _applyFilters() {
    List<JobPostModel> filtered = List.from(_posts);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((post) {
        return post.title.toLowerCase().contains(query) ||
            post.description.toLowerCase().contains(query) ||
            post.category.toLowerCase().contains(query) ||
            post.location.toLowerCase().contains(query);
      }).toList();
    }

    // Status filter
    if (_selectedStatus != 'all') {
      filtered = filtered.where((p) => p.status == _selectedStatus).toList();
    } else {
      // By default, hide rejected and completed posts (only show active and pending)
      filtered = filtered.where((p) => 
        p.status == 'active' || p.status == 'pending'
      ).toList();
    }

    // Category filter
    if (_selectedCategory != 'all') {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }

    // State filter
    if (_selectedState != 'all') {
      filtered = filtered.where((p) {
        final postState = _extractState(p.location);
        return postState.toLowerCase() == _selectedState.toLowerCase();
      }).toList();
    }

    // Date range filter
    if (_startDate != null) {
      filtered = filtered.where((p) => p.createdAt.isAfter(_startDate!) || 
          p.createdAt.isAtSameMomentAs(_startDate!)).toList();
    }
    if (_endDate != null) {
      final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      filtered = filtered.where((p) => p.createdAt.isBefore(endOfDay) || 
          p.createdAt.isAtSameMomentAs(endOfDay)).toList();
    }

    setState(() {
      _filteredPosts = filtered;
    });

    _updateMarkers();
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'all';
      _selectedCategory = 'all';
      _selectedState = 'all';
      _searchQuery = '';
      _searchController.clear();
      _startDate = null;
      _endDate = null;
    });
    _applyFilters();
  }

  // Extract Malaysian state from location string
  String _extractState(String location) {
    if (location.isEmpty) return '';
    
    final locationLower = location.toLowerCase();
    
    // List of Malaysian states and federal territories
    final states = [
      'johor',
      'kedah',
      'kelantan',
      'kuala lumpur',
      'labuan',
      'malacca',
      'melaka',
      'negeri sembilan',
      'pahang',
      'penang',
      'pulau pinang',
      'perak',
      'perlis',
      'putrajaya',
      'sabah',
      'sarawak',
      'selangor',
      'terengganu',
    ];
    
    // Check for state names in the location string
    for (final state in states) {
      if (locationLower.contains(state)) {
        // Normalize state names
        if (state == 'kuala lumpur') return 'Kuala Lumpur';
        if (state == 'pulau pinang' || state == 'penang') return 'Penang';
        if (state == 'melaka' || state == 'malacca') return 'Melaka';
        // Capitalize first letter of each word
        return state.split(' ').map((word) => 
          word[0].toUpperCase() + word.substring(1)
        ).join(' ');
      }
    }
    
    // If no state found, return the location as is (might be a city or area)
    return location;
  }

  Future<void> _updateMarkers() async {
    setState(() {
      _isGeocoding = true;
      _markers.clear();
      _markerPostMap.clear();
    });

    final newMarkers = <Marker>{};
    int markerId = 0;

    for (final post in _filteredPosts) {
      if (post.location.isEmpty) continue;
      
      final coordinates = await _getCoordinates(post.location);
      if (coordinates != null) {
        final markerIdStr = 'post_${markerId++}';
        final statusColor = _getStatusColor(post.status);
        newMarkers.add(
          Marker(
            markerId: MarkerId(markerIdStr),
            position: coordinates,
            icon: BitmapDescriptor.defaultMarkerWithHue(statusColor),
            infoWindow: InfoWindow(
              title: post.title,
              snippet: '${post.category} • ${post.status.toUpperCase()}',
              onTap: () => _showPostDetails(post),
            ),
            onTap: () => _showPostBottomSheet(post),
          ),
        );
        _markerPostMap[markerIdStr] = post;
      }
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
        _isGeocoding = false;
      });

      // Adjust camera to show all markers
      if (_markers.isNotEmpty && _mapController != null) {
        _fitBounds();
      }
    }
  }

  Future<LatLng?> _getCoordinates(String location) async {
    // Check cache first
    if (_locationCache.containsKey(location)) {
      return _locationCache[location];
    }

    try {
      List<Location> locations = await locationFromAddress(location);
      if (locations.isNotEmpty) {
        final coordinates = LatLng(locations.first.latitude, locations.first.longitude);
        _locationCache[location] = coordinates;
        return coordinates;
      }
    } catch (e) {
      // If geocoding fails, try with a more specific query
      try {
        List<Location> locations = await locationFromAddress('$location, Malaysia');
        if (locations.isNotEmpty) {
          final coordinates = LatLng(locations.first.latitude, locations.first.longitude);
          _locationCache[location] = coordinates;
          return coordinates;
        }
      } catch (e2) {
        // Silently fail - location cannot be geocoded
      }
    }
    return null;
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress('$query, Malaysia');
      if (locations.isNotEmpty && _mapController != null) {
        final coordinates = LatLng(locations.first.latitude, locations.first.longitude);
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: coordinates, zoom: 14),
          ),
        );
        _showSnackBar('Location found: $query', isError: false);
      } else {
        _showSnackBar('Location not found', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error searching location', isError: true);
    }
  }

  void _fitBounds() {
    if (_markers.isEmpty || _mapController == null) return;

    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;

    for (final marker in _markers) {
      minLat = minLat < marker.position.latitude ? minLat : marker.position.latitude;
      maxLat = maxLat > marker.position.latitude ? maxLat : marker.position.latitude;
      minLng = minLng < marker.position.longitude ? minLng : marker.position.longitude;
      maxLng = maxLng > marker.position.longitude ? maxLng : marker.position.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.1, minLng - 0.1),
          northeast: LatLng(maxLat + 0.1, maxLng + 0.1),
        ),
        100.0,
      ),
    );
  }

  double _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return BitmapDescriptor.hueGreen;
      case 'pending':
        return BitmapDescriptor.hueOrange;
      case 'completed':
        return BitmapDescriptor.hueBlue;
      case 'rejected':
        return BitmapDescriptor.hueRed;
      default:
        return BitmapDescriptor.hueViolet;
    }
  }

  void _showPostDetails(JobPostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailPage(post: post),
      ),
    );
  }

  void _showPostBottomSheet(JobPostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Post title
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColorForBadge(post.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    post.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Post details
                _DetailRow(icon: Icons.category, label: 'Category', value: post.category),
                _DetailRow(icon: Icons.location_on, label: 'Location', value: post.location),
                _DetailRow(icon: Icons.business, label: 'Industry', value: post.industry),
                _DetailRow(icon: Icons.work, label: 'Job Type', value: post.jobType),
                _DetailRow(
                  icon: Icons.calendar_today,
                  label: 'Created',
                  value: DateFormat('MMM dd, yyyy').format(post.createdAt),
                ),
                if (post.budgetMin != null && post.budgetMax != null)
                  _DetailRow(
                    icon: Icons.attach_money,
                    label: 'Budget',
                    value: 'RM ${post.budgetMin!.toStringAsFixed(0)} - RM ${post.budgetMax!.toStringAsFixed(0)}',
                  ),
                const SizedBox(height: 20),
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showPostDetails(post);
                        },
                        icon: const Icon(Icons.visibility),
                        label: const Text('View Details'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (post.status == 'pending')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await _postService.approvePost(post.id);
                              Navigator.pop(context);
                              _showSnackBar('Post approved successfully', isError: false);
                            } catch (e) {
                              _showSnackBar('Error approving post', isError: true);
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
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
    );
  }

  Color _getStatusColorForBadge(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
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

  @override
  void dispose() {
    _searchController.dispose();
    _locationSearchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Map Oversight',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isListView ? Icons.map : Icons.list),
            onPressed: () {
              setState(() => _isListView = !_isListView);
            },
            tooltip: _isListView ? 'Map View' : 'List View',
          ),
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () {
              setState(() => _showFilters = !_showFilters);
            },
            tooltip: 'Toggle Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          if (_showFilters)
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
                  // Search bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search posts by title, description, category...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _applyFilters();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _applyFilters();
                    },
                  ),
                  const SizedBox(height: 12),
                  // Location search
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _locationSearchController,
                          decoration: InputDecoration(
                            hintText: 'Search location on map...',
                            prefixIcon: const Icon(Icons.location_searching),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _searchLocation(_locationSearchController.text),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Filter chips row - using Row with Expanded for consistent layout
                  Row(
                    children: [
                      Expanded(
                        child: _FilterChip(
                          label: 'Status',
                          value: _selectedStatus == 'all' ? 'All' : _selectedStatus.toUpperCase(),
                          onTap: () => _showStatusFilter(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterChip(
                          label: 'Category',
                          value: _selectedCategory == 'all' ? 'All' : _selectedCategory,
                          onTap: () => _showCategoryFilter(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _FilterChip(
                          label: 'State',
                          value: _selectedState == 'all' ? 'All' : _selectedState,
                          onTap: () => _showStateFilter(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterChip(
                          label: 'Date Range',
                          value: _startDate != null && _endDate != null
                              ? '${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}'
                              : 'All',
                          onTap: _selectDateRange,
                        ),
                      ),
                    ],
                  ),
                  if (_activeFilterCount > 0) ...[
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
                            '$_activeFilterCount filter${_activeFilterCount > 1 ? 's' : ''} active',
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
                  if (_isGeocoding) ...[
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Updating map markers...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          // Map/List Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isListView
                    ? _buildListView()
                    : _buildMapView(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            if (_markers.isNotEmpty) {
              _fitBounds();
            }
          },
          initialCameraPosition: CameraPosition(
            target: _center,
            zoom: _zoom,
          ),
          markers: _markers,
          mapType: MapType.normal,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),
        // Legend
        Positioned(
          top: 16,
          right: 16,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Legend',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _LegendItem(
                    color: Colors.green,
                    label: 'Active Posts',
                  ),
                  const SizedBox(height: 4),
                  _LegendItem(
                    color: Colors.orange,
                    label: 'Pending Posts',
                  ),
                  const SizedBox(height: 4),
                  _LegendItem(
                    color: Colors.blue,
                    label: 'Completed Posts',
                  ),
                  const SizedBox(height: 4),
                  _LegendItem(
                    color: Colors.red,
                    label: 'Rejected Posts',
                  ),
                ],
              ),
            ),
          ),
        ),
        // Stats Card
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    icon: Icons.work,
                    label: 'Total Posts',
                    value: _posts.length.toString(),
                    tooltip: 'All posts in database',
                  ),
                  _StatItem(
                    icon: Icons.location_on,
                    label: 'On Map',
                    value: _markers.length.toString(),
                    tooltip: 'Posts with valid locations shown on map',
                  ),
                  _StatItem(
                    icon: Icons.location_off,
                    label: 'No Location',
                    value: (_filteredPosts.length - _markers.length).toString(),
                    tooltip: 'Filtered posts that could not be geocoded',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    if (_filteredPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No posts found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredPosts.length,
      itemBuilder: (context, index) {
        final post = _filteredPosts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColorForBadge(post.status),
              child: const Icon(Icons.work, color: Colors.white, size: 20),
            ),
            title: Text(
              post.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${post.category} • ${post.location}'),
                Text(
                  'Status: ${post.status.toUpperCase()}',
                  style: TextStyle(
                    color: _getStatusColorForBadge(post.status),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Created: ${DateFormat('MMM dd, yyyy').format(post.createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showPostDetails(post),
          ),
        );
      },
    );
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
            ...['all', 'active', 'pending', 'completed', 'rejected'].map((status) {
              return ListTile(
                title: Text(status == 'all' ? 'All Status' : status.toUpperCase()),
                trailing: _selectedStatus == status
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() => _selectedStatus = status);
                  Navigator.pop(context);
                  _applyFilters();
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
      builder: (context) => FutureBuilder<List<String>>(
        future: _getCategories(),
        builder: (context, snapshot) {
          final categories = snapshot.data ?? [];
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('All Categories'),
                  trailing: _selectedCategory == 'all'
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() => _selectedCategory = 'all');
                    Navigator.pop(context);
                    _applyFilters();
                  },
                ),
                ...categories.map((category) {
                  return ListTile(
                    title: Text(category),
                    trailing: _selectedCategory == category
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() => _selectedCategory = category);
                      Navigator.pop(context);
                      _applyFilters();
                    },
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showStateFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => FutureBuilder<List<String>>(
        future: _getStates(),
        builder: (context, snapshot) {
          final states = snapshot.data ?? [];
          return Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select State',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        title: const Text('All States'),
                        trailing: _selectedState == 'all'
                            ? const Icon(Icons.check, color: Colors.blue)
                            : null,
                        onTap: () {
                          setState(() => _selectedState = 'all');
                          Navigator.pop(context);
                          _applyFilters();
                        },
                      ),
                      ...states.map((state) {
                        return ListTile(
                          title: Text(state),
                          trailing: _selectedState == state
                              ? const Icon(Icons.check, color: Colors.blue)
                              : null,
                          onTap: () {
                            setState(() => _selectedState = state);
                            Navigator.pop(context);
                            _applyFilters();
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<String>> _getCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('posts').get();
      final categories = snapshot.docs
          .map((doc) => doc.data()['category'] as String? ?? '')
          .where((cat) => cat.isNotEmpty)
          .toSet()
          .toList();
      categories.sort();
      return categories;
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> _getStates() async {
    try {
      final postsSnapshot = await FirebaseFirestore.instance.collection('posts').get();
      
      final states = <String>{};
      for (var doc in postsSnapshot.docs) {
        final loc = doc.data()['location'] as String? ?? '';
        if (loc.isNotEmpty) {
          final state = _extractState(loc);
          if (state.isNotEmpty) {
            states.add(state);
          }
        }
      }
      
      final stateList = states.toList()..sort();
      return stateList;
    } catch (e) {
      return [];
    }
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? tooltip;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final widget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: widget,
      );
    }
    return widget;
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
