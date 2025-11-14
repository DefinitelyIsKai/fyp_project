import 'package:flutter/material.dart';
import 'package:fyp_project/models/message_model.dart';
import 'package:fyp_project/services/message_service.dart';
import 'package:fyp_project/pages/message_oversight/message_detail_page.dart';

class MessageOversightPage extends StatefulWidget {
  const MessageOversightPage({super.key});

  @override
  State<MessageOversightPage> createState() => _MessageOversightPageState();
}

class _MessageOversightPageState extends State<MessageOversightPage> {
  final MessageService _messageService = MessageService();
  List<MessageModel> _reportedMessages = [];
  List<MessageModel> _filteredMessages = [];
  bool _isLoading = true;
  String _selectedStatus = 'reported';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _messageService.getReportedMessages();
      setState(() {
        _reportedMessages = messages;
        _filteredMessages = messages;
      });
      _filterMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterMessages() {
    setState(() {
      _filteredMessages = _reportedMessages.where((message) {
        return _selectedStatus == 'all' ||
            message.status.toString().split('.').last == _selectedStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message Oversight')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Filter by Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'reported', child: Text('Reported')),
                DropdownMenuItem(value: 'reviewed', child: Text('Reviewed')),
                DropdownMenuItem(value: 'removed', child: Text('Removed')),
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value ?? 'all');
                _filterMessages();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMessages.isEmpty
                    ? const Center(child: Text('No reported messages found'))
                    : ListView.builder(
                        itemCount: _filteredMessages.length,
                        itemBuilder: (context, index) {
                          final message = _filteredMessages[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: const Icon(Icons.message, color: Colors.red),
                              title: Text(
                                message.content.length > 50
                                    ? '${message.content.substring(0, 50)}...'
                                    : message.content,
                              ),
                              subtitle: Text(
                                'Sent: ${message.sentAt.toString().split(' ')[0]}',
                              ),
                              trailing: Chip(
                                label: Text(message.status.toString().split('.').last),
                                backgroundColor: _getStatusColor(message.status),
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MessageDetailPage(message: message),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.reported:
        return Colors.orange;
      case MessageStatus.reviewed:
        return Colors.blue;
      case MessageStatus.removed:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

