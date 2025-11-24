import 'package:flutter/material.dart';
import 'package:fyp_project/models/admin/message_model.dart';
import 'package:fyp_project/services/admin/message_service.dart';
import 'package:fyp_project/services/admin/user_service.dart';
import 'package:fyp_project/services/admin/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fyp_project/utils/admin/app_colors.dart';

class MessageDetailPage extends StatefulWidget {
  final MessageModel message;

  const MessageDetailPage({super.key, required this.message});

  @override
  State<MessageDetailPage> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends State<MessageDetailPage> {
  final MessageService _messageService = MessageService();
  final UserService _userService = UserService();
  final TextEditingController _notesController = TextEditingController();
  bool _isProcessing = false;
  String? _senderName;
  String? _receiverName;
  bool _loadingUserInfo = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    try {
      final senderDoc = await _userService.getAllUsers();
      final sender = senderDoc.firstWhere(
        (u) => u.id == widget.message.senderId,
        orElse: () => senderDoc.first,
      );
      final receiver = senderDoc.firstWhere(
        (u) => u.id == widget.message.receiverId,
        orElse: () => senderDoc.first,
      );
      if (mounted) {
        setState(() {
          _senderName = sender.fullName;
          _receiverName = receiver.fullName;
          _loadingUserInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingUserInfo = false);
      }
    }
  }

  Future<void> _takeAction(String action) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final reviewerId = authService.currentAdmin?.id ?? 'admin';

    if (action == 'warning' || action == 'suspend') {
      final confirmed = await _showActionConfirmation(action);
      if (!confirmed) return;
    }

    setState(() => _isProcessing = true);
    try {
      await _messageService.reviewMessage(
        messageId: widget.message.id,
        action: action,
        reviewedBy: reviewerId,
        reviewNotes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      // If warning or suspend, also take action on the user
      if (action == 'warning') {
        await _userService.issueWarning(
          userId: widget.message.senderId,
          violationReason: 'Inappropriate message content: ${widget.message.reportReason ?? "Violation of community guidelines"}',
        );
      } else if (action == 'suspend') {
        await _userService.suspendUser(
          widget.message.senderId,
          violationReason: 'Severe message violation: ${widget.message.reportReason ?? "Violation of community guidelines"}',
          durationDays: 7,
        );
      }

      if (mounted) {
        _showSnackBar('Message reviewed successfully. Action: ${action.toUpperCase()}', isError: false);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool> _showActionConfirmation(String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              action == 'warning' ? Icons.warning : Icons.pause_circle_outline,
              color: action == 'warning' ? Colors.orange : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(action == 'warning' ? 'Issue Warning' : 'Suspend User'),
          ],
        ),
        content: Text(
          action == 'warning'
              ? 'This will issue a warning to the sender. After 3 warnings, their account will be automatically suspended.'
              : 'This will suspend the sender\'s account for 7 days. They will not be able to access the platform during this time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'warning' ? Colors.orange : Colors.red,
            ),
            child: Text(action == 'warning' ? 'Issue Warning' : 'Suspend User'),
          ),
        ],
      ),
    );
    return result ?? false;
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
          'Message Review',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message Content Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        const Expanded(
                          child: Text(
                            'Flagged Message',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.message.content,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Message Details
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Message Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: 'From',
                      value: _loadingUserInfo
                          ? 'Loading...'
                          : (_senderName ?? widget.message.senderId),
                    ),
                    _DetailRow(
                      label: 'To',
                      value: _loadingUserInfo
                          ? 'Loading...'
                          : (_receiverName ?? widget.message.receiverId),
                    ),
                    _DetailRow(
                      label: 'Sent At',
                      value: DateFormat('MMM dd, yyyy • hh:mm a').format(widget.message.sentAt),
                    ),
                    if (widget.message.reportReason != null)
                      _DetailRow(
                        label: 'Report Reason',
                        value: widget.message.reportReason!,
                        valueColor: Colors.red[700],
                      ),
                    if (widget.message.reviewedBy != null) ...[
                      const Divider(),
                      _DetailRow(
                        label: 'Reviewed By',
                        value: widget.message.reviewedBy!,
                      ),
                      if (widget.message.reviewedAt != null)
                        _DetailRow(
                          label: 'Reviewed At',
                          value: DateFormat('MMM dd, yyyy • hh:mm a')
                              .format(widget.message.reviewedAt!),
                        ),
                      if (widget.message.reviewAction != null)
                        _DetailRow(
                          label: 'Action Taken',
                          value: widget.message.reviewAction!,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Review Notes
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Review Notes (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add notes about this review...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            const Text(
              'Review Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _takeAction('approved'),
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _takeAction('removed'),
                    icon: const Icon(Icons.delete, size: 20),
                    label: const Text('Remove'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _takeAction('warning'),
                icon: const Icon(Icons.warning, size: 20),
                label: const Text('Issue Warning to Sender'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _takeAction('suspend'),
                icon: const Icon(Icons.pause_circle_outline, size: 20),
                label: const Text('Suspend Sender Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
