import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user/review_service.dart';
import '../../../services/user/auth_service.dart';
import '../../../models/user/review.dart';

class ReputationPage extends StatelessWidget {
  const ReputationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final reviewService = ReviewService();
    final auth = AuthService();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Reputation',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder(
        future: auth.getUserDoc(),
        builder: (context, userSnap) {
          final userId = userSnap.data?.id;
          final role = (userSnap.data?.data()?['role'] as String?)?.toLowerCase() ?? 'jobseeker';
          return RefreshIndicator(
            onRefresh: () async {
              await auth.getUserDoc();
              await Future.delayed(const Duration(milliseconds: 100));
            },
            color: const Color(0xFF00C8A0),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF00C8A0),
                        const Color(0xFF00C8A0).withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.stars_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        role == 'recruiter' ? 'Your Given Ratings' : 'Your Reputation Score',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (role != 'recruiter')
                        FutureBuilder<double>(
                          future: userId == null ? Future.value(0.0) : reviewService.getAverageRatingForUser(userId),
                          builder: (context, avgSnap) {
                            final avg = (avgSnap.data ?? 0.0);
                            return Column(
                              children: [
                                Text(
                                  avg == 0.0 ? '—' : '${avg.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'out of 5.0',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (index) {
                                    return Icon(
                                      index < avg.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                                      color: Colors.amber,
                                      size: 28,
                                    );
                                  }),
                                ),
                              ],
                            );
                          },
                        ),
                      if (role == 'recruiter')
                        StreamBuilder<List<Review>>(
                          stream: userId == null ? Stream.value([]) : reviewService.streamReviewsByRecruiter(userId),
                          builder: (context, reviewSnap) {
                            final reviews = reviewSnap.data ?? [];
                            final count = reviews.length;
                            return Column(
                              children: [
                                Text(
                                  count.toString(),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  count == 1 ? 'Rating Given' : 'Ratings Given',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //jobseeker
                      if (role != 'recruiter')
                        Container(
                          padding: const EdgeInsets.all(20),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00C8A0).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.analytics_outlined,
                                      size: 20,
                                      color: const Color(0xFF00C8A0),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Reputation Breakdown',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              StreamBuilder<List<Review>>(
                                stream: userId == null ? Stream.value([]) : reviewService.streamReviewsForUser(userId),
                                builder: (context, reviewSnap) {
                                  final reviews = reviewSnap.data ?? [];
                                  final ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
                                  
                                  for (final review in reviews) {
                                    ratingCounts[review.rating] = (ratingCounts[review.rating] ?? 0) + 1;
                                  }
                                  
                                  final totalReviews = reviews.length;
                                  
                                  return Column(
                                    children: List.generate(5, (index) {
                                      final rating = 5 - index;
                                      final count = ratingCounts[rating] ?? 0;
                                      final percentage = totalReviews > 0 ? (count / totalReviews) : 0.0;
                                      
                                      return _buildRatingBar(
                                        rating: rating,
                                        count: count,
                                        percentage: percentage,
                                      );
                                    }),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      if (role != 'recruiter') const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(20),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C8A0).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    role == 'recruiter' ? Icons.rate_review_outlined : Icons.reviews_outlined,
                                    size: 20,
                                    color: const Color(0xFF00C8A0),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  role == 'recruiter' ? 'Your Recent Ratings' : 'Recent Reviews',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (userId != null)
                              StreamBuilder<List<Review>>(
                                stream: role == 'recruiter'
                                    ? reviewService.streamReviewsByRecruiter(userId)
                                    : reviewService.streamReviewsForUser(userId),
                                builder: (context, reviewSnap) {
                                  if (reviewSnap.connectionState == ConnectionState.waiting) {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: const Color(0xFF00C8A0),
                                      ),
                                    );
                                  }
                                  
                                  final reviews = reviewSnap.data ?? const <Review>[];
                                  if (reviews.isEmpty) {
                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            role == 'recruiter' ? Icons.rate_review_outlined : Icons.reviews_outlined,
                                            size: 64,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            role == 'recruiter' ? 'No ratings given yet' : 'No reviews yet',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            role == 'recruiter' 
                                                ? 'Your ratings will appear here'
                                                : 'Your reviews will appear here',
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
                                    children: reviews
                                        .map((r) => _buildReviewCard(r, role == 'recruiter'))
                                        .toList(),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRatingBar({required int rating, required int count, required double percentage}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Text(
                  '$rating',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: 16,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF00C8A0)),
                borderRadius: BorderRadius.circular(4),
                minHeight: 8,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review, bool isRecruiterView) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //rating
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 20,
                  );
                }),
              ),
              const Spacer(),
              Text(
                _timeAgo(review.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          //eiter jobseek or recruiter
          const SizedBox(height: 8),
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(isRecruiterView ? review.jobseekerId : review.recruiterId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                );
              }
              
              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              final userName = userData?['fullName'] as String? ?? 'Unknown User';
              
              return Row(
                children: [
                  Icon(Icons.person, size: 16, color: const Color(0xFF00C8A0)),
                  const SizedBox(width: 6),
                  Text(
                    isRecruiterView 
                        ? 'Reviewed: $userName'
                        : 'Reviewed by: $userName',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          if (review.comment.isNotEmpty)
            Text(
              review.comment,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
                height: 1.4,
              ),
            )
          else
            Text(
              'No comment provided',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);
  if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
  return 'Just now';
}