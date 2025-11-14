import 'package:flutter/material.dart';
import 'package:fyp_project/models/message_model.dart';
import 'package:fyp_project/services/message_service.dart';

class MessageDetailPage extends StatefulWidget {
  final MessageModel message;

  const MessageDetailPage({super.key, required this.message});

  @override
  State<MessageDetailPage> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends State<MessageDetailPage> {
  final MessageService _messageService = MessageService();
  bool _isProcessing = false;

  Future<void> _takeAction(String action) async {
    setState(() => _isProcessing = true);
    try {
      await _messageService.reviewMessage(widget.message.id, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message $action')),
        );
        Navigator.pop(context, true);
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Message Content',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.message.content),
              ),
            ),
            const SizedBox(height: 16),
            _DetailRow(label: 'Sender ID', value: widget.message.senderId),
            _DetailRow(label: 'Receiver ID', value: widget.message.receiverId),
            _DetailRow(
              label: 'Sent At',
              value: widget.message.sentAt.toString(),
            ),
            if (widget.message.reportReason != null)
              _DetailRow(label: 'Report Reason', value: widget.message.reportReason!),
            if (widget.message.reviewAction != null)
              _DetailRow(label: 'Action Taken', value: widget.message.reviewAction!),
            const Divider(),
            const Text(
              'Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _takeAction('approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _takeAction('removed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Remove'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _takeAction('warning'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Send Warning'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

