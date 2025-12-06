import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/rating_model.dart';
import 'package:fyp_project/services/admin/rating_service.dart';
import 'package:fyp_project/pages/admin/message_oversight/rating_detail_page.dart';

class ManageRatingsPage extends StatefulWidget {
  const ManageRatingsPage({super.key});

  @override
  State<ManageRatingsPage> createState() => _ManageRatingsPageState();
}

class _ManageRatingsPageState extends State<ManageRatingsPage> {
  final RatingService _ratingService = RatingService();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  String _searchQuery = '';
  int? _selectedStarFilter; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Ratings'),
        backgroundColor: Colors.amber[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.amber[700],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rating Management',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 0),
                Text(
                  'View and manage user ratings and reviews',
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
                    hintText: 'Search ratings by comment...',
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
                Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            
                            FilterChip(
                              label: const Text('All'),
                              selected: _selectedStarFilter == null,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedStarFilter = null;
                                });
                              },
                              selectedColor: Colors.amber[100],
                              checkmarkColor: Colors.amber[900],
                            ),
                            const SizedBox(width: 8),
                            
                            ...List.generate(5, (index) {
                              final starCount = index + 1;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  avatar: Icon(
                                    Icons.star,
                                    size: 18,
                                    color: _selectedStarFilter == starCount 
                                        ? Colors.amber[900] 
                                        : Colors.amber[700],
                                  ),
                                  label: Text('$starCount Star${starCount > 1 ? 's' : ''}'),
                                  selected: _selectedStarFilter == starCount,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedStarFilter = selected ? starCount : null;
                                    });
                                  },
                                  selectedColor: Colors.amber[100],
                                  checkmarkColor: Colors.amber[900],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<RatingModel>>(
              stream: _getRatingsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading ratings: ${snapshot.error}',
                          style: TextStyle(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final allRatings = snapshot.data ?? [];
                final filteredRatings = _filterRatings(allRatings);

                if (filteredRatings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.star_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No ratings found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No ratings match your filters',
                          style: TextStyle(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
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
                            '${filteredRatings.length} rating(s) found',
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
                      child: RefreshIndicator(
                        key: _refreshIndicatorKey,
                        onRefresh: () async {
                          
                          setState(() {});
                          
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredRatings.length,
                          itemBuilder: (context, index) {
                            final rating = filteredRatings[index];
                            return _buildRatingCard(rating);
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<List<RatingModel>> _getRatingsStream() {
    return _ratingService.streamAllRatings();
  }

  List<RatingModel> _filterRatings(List<RatingModel> ratings) {
    return ratings.where((rating) {
      
      final matchesSearch = _searchQuery.isEmpty ||
          (rating.comment?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      final matchesStarFilter = _selectedStarFilter == null ||
          rating.rating.toInt() == _selectedStarFilter;

      return matchesSearch && matchesStarFilter;
    }).toList();
  }

  Widget _buildRatingCard(RatingModel rating) {
    final statusColor = _getStatusColor(rating.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: rating.status == RatingStatus.flagged
            ? BorderSide(color: Colors.red[300]!, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RatingDetailPage(rating: rating),
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
                  
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating.rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                  ),
                  const Spacer(),
                  
                  if (rating.status != RatingStatus.active)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        _getStatusLabel(rating.status),
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              if (rating.comment != null && rating.comment!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rating.comment!,
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
                    'Rated ${_formatTimeAgo(rating.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (rating.status == RatingStatus.flagged)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag, size: 12, color: Colors.red[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Needs Review',
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

  Color _getStatusColor(RatingStatus status) {
    switch (status) {
      case RatingStatus.active:
        return Colors.green;
      case RatingStatus.flagged:
        return Colors.red;
      case RatingStatus.removed:
        return Colors.grey;
      case RatingStatus.deleted:
        return Colors.grey[700]!;
      case RatingStatus.pendingReview:
        return Colors.orange;
    }
  }

  String _getStatusLabel(RatingStatus status) {
    switch (status) {
      case RatingStatus.active:
        return 'ACTIVE';
      case RatingStatus.flagged:
        return 'FLAGGED';
      case RatingStatus.removed:
        return 'REMOVED';
      case RatingStatus.deleted:
        return 'DELETED';
      case RatingStatus.pendingReview:
        return 'PENDING';
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
