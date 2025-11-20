import 'package:flutter/material.dart';
import 'package:fyp_project/models/message_model.dart';
import 'package:fyp_project/models/rating_model.dart';
import 'package:fyp_project/services/message_service.dart';
import 'package:fyp_project/services/rating_service.dart';
import 'package:fyp_project/pages/message_oversight/message_detail_page.dart';
import 'package:fyp_project/pages/message_oversight/rating_detail_page.dart';
import 'package:intl/intl.dart';

class MessageOversightPage extends StatefulWidget {
  const MessageOversightPage({super.key});

  @override
  State<MessageOversightPage> createState() => _MessageOversightPageState();
}

class _MessageOversightPageState extends State<MessageOversightPage>
    with SingleTickerProviderStateMixin {
  final MessageService _messageService = MessageService();
  final RatingService _ratingService = RatingService();
  late TabController _tabController;

  List<MessageModel> _reportedMessages = [];
  List<RatingModel> _flaggedRatings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _messageService.getReportedMessages();
      final ratings = await _ratingService.getFlaggedRatings();
      if (mounted) {
        setState(() {
          _reportedMessages = messages;
          _flaggedRatings = ratings;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading data: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Review & Message Oversight',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: [
            _buildTab(
              'Flagged Messages',
              Icons.flag,
              _reportedMessages.length,
              Colors.red,
            ),
            _buildTab(
              'Ratings',
              Icons.star,
              _flaggedRatings.length,
              Colors.orange,
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.blue[700],
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFlaggedMessagesTab(),
                  _buildRatingsTab(),
                ],
              ),
            ),
    );
  }

  Widget _buildTab(String title, IconData icon, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(title),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlaggedMessagesTab() {
    if (_reportedMessages.isEmpty) {
      return _buildEmptyState(
        icon: Icons.message_outlined,
        title: 'No Flagged Messages',
        subtitle: 'All messages are clean. No reports at this time.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reportedMessages.length,
      itemBuilder: (context, index) {
        final message = _reportedMessages[index];
        return _buildMessageCard(message);
      },
    );
  }

  Widget _buildRatingsTab() {
    if (_flaggedRatings.isEmpty) {
      return _buildEmptyState(
        icon: Icons.star_outline,
        title: 'No Flagged Ratings',
        subtitle: 'All ratings are clean. No flagged reviews at this time.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _flaggedRatings.length,
      itemBuilder: (context, index) {
        final rating = _flaggedRatings[index];
        return _buildRatingCard(rating);
      },
    );
  }

  Widget _buildMessageCard(MessageModel message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MessageDetailPage(message: message),
              ),
            );
            if (result == true) {
              _loadData();
            }
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
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.message, size: 20, color: Colors.red[700]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Flagged Message',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy • hh:mm a').format(message.sentAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Text(
                        'Reported',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    message.content.length > 150
                        ? '${message.content.substring(0, 150)}...'
                        : message.content,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (message.reportReason != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.flag, size: 14, color: Colors.red[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Reason: ${message.reportReason}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCard(RatingModel rating) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RatingDetailPage(rating: rating),
              ),
            );
            if (result == true) {
              _loadData();
            }
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
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.star, size: 20, color: Colors.orange[700]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                return Icon(
                                  index < rating.rating.floor()
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 16,
                                  color: Colors.amber,
                                );
                              }),
                              const SizedBox(width: 8),
                              Text(
                                rating.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(rating.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Text(
                        'Flagged',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[800],
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
                      rating.comment!.length > 150
                          ? '${rating.comment!.substring(0, 150)}...'
                          : rating.comment!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
                if (rating.flaggedReason != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.flag, size: 14, color: Colors.red[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Reason: ${rating.flaggedReason}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
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
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
