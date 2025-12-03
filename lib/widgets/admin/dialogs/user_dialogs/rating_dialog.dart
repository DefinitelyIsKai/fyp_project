import 'package:flutter/material.dart';
import '../../../../services/user/review_service.dart';
import '../../../../utils/user/dialog_utils.dart';
import '../../../../utils/user/button_styles.dart';

class RatingDialog extends StatefulWidget {
  final String postId;
  final String jobseekerId;
  final ReviewService reviewService;

  const RatingDialog({
    super.key,
    required this.postId,
    required this.jobseekerId,
    required this.reviewService,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  final TextEditingController _commentController = TextEditingController();
  int _selectedRating = 5;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF00C8A0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_outline,
                size: 30,
                color: Color(0xFF00C8A0),
              ),
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Rate Jobseeker',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Share your experience with this jobseeker',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRating = i + 1;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < _selectedRating ? Icons.star : Icons.star_border,
                      color: i < _selectedRating 
                          ? Colors.amber[600] 
                          : Colors.grey[400],
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            
            Text(
              _selectedRating == 1
                  ? 'Poor'
                  : _selectedRating == 2
                      ? 'Fair'
                      : _selectedRating == 3
                          ? 'Good'
                          : _selectedRating == 4
                              ? 'Very Good'
                              : 'Excellent',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: 'Feedback (optional)',
                labelStyle: TextStyle(color: Colors.grey[600]),
                hintText: 'Share your thoughts...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00C8A0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await widget.reviewService.addRecruiterReview(
                          postId: widget.postId,
                          jobseekerId: widget.jobseekerId,
                          rating: _selectedRating,
                          comment: _commentController.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          DialogUtils.showSuccessMessage(
                            context: context,
                            message: 'Review submitted',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          DialogUtils.showWarningMessage(
                            context: context,
                            message: 'Failed to submit review: $e',
                          );
                        }
                      }
                    },
                    style: ButtonStyles.primaryElevated(
                      elevation: 0,
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
