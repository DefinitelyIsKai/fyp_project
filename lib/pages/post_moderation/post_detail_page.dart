import 'package:flutter/material.dart';
import 'package:fyp_project/models/job_post_model.dart';
import 'package:fyp_project/services/post_service.dart';

class PostDetailPage extends StatefulWidget {
  final JobPostModel post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final PostService _postService = PostService();
  bool _isProcessing = false;
  final TextEditingController _rejectionReasonController = TextEditingController();

  Future<void> _approvePost() async {
    setState(() => _isProcessing = true);
    try {
      await _postService.approvePost(widget.post.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post approved successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectPost() async {
    if (_rejectionReasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a rejection reason')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await _postService.rejectPost(
        widget.post.id,
        _rejectionReasonController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post rejected')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.post.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Category: ${widget.post.category}'),
            Text('Location: ${widget.post.location}'),
            Text('Salary: ${widget.post.salary ?? 'Not specified'} ${widget.post.salaryType}'),
            const Divider(),
            const Text(
              'Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(widget.post.description),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: widget.post.tags
                  .map((tag) => Chip(label: Text(tag)))
                  .toList(),
            ),
            const Divider(),
            TextField(
              controller: _rejectionReasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (if rejecting)',
                border: OutlineInputBorder(),
                hintText: 'Enter reason for rejection...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _approvePost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator()
                        : const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _rejectPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

