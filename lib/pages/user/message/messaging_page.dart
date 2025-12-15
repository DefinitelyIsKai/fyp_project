import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../services/user/messaging_service.dart';
import '../../../models/user/message.dart';
import '../../../services/user/auth_service.dart';
import '../../../utils/user/date_utils.dart' as DateUtilsHelper;
import '../../../utils/user/card_decorations.dart';

class MessagingPage extends StatefulWidget {
  const MessagingPage({super.key});

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  final MessagingService _messagingService = MessagingService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
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
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase().trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[600]),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Conversation>>(
              stream: _messagingService.streamConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFF00C8A0),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Unable to load conversations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please try again later',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allConversations = snapshot.data ?? [];
                
                final conversations = _searchQuery.isEmpty
                    ? allConversations
                    : allConversations.where((conversation) {
                        final currentUserId = _authService.currentUserId;
                        final otherName = conversation.getOtherParticipantName(currentUserId).toLowerCase();
                        return otherName.contains(_searchQuery);
                      }).toList();

                if (conversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Conversations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your conversations will appear here',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {
                    });
                    await Future.delayed(const Duration(milliseconds: 100));
                  },
                  color: const Color(0xFF00C8A0),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    final currentUserId = _authService.currentUserId;
                    final otherName = conversation.getOtherParticipantName(currentUserId);
                    final otherRole = conversation.getOtherParticipantRole(currentUserId);

                    return _ConversationCard(
                      conversation: conversation,
                      otherName: otherName,
                      otherRole: otherRole,
                      formatTimeAgo: DateUtilsHelper.DateUtils.formatTimeAgoShort,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatDetailPage(
                              conversation: conversation,
                              otherName: otherName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final Conversation conversation;
  final String otherName;
  final String otherRole;
  final String Function(DateTime) formatTimeAgo;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.conversation,
    required this.otherName,
    required this.otherRole,
    required this.formatTimeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CardDecorations.standard(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF00C8A0).withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF00C8A0).withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF00C8A0),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          otherName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                otherRole,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              conversation.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Text(
          formatTimeAgo(conversation.lastMessageTime),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class ChatDetailPage extends StatefulWidget {
  final Conversation conversation;
  final String otherName;

  const ChatDetailPage({
    super.key,
    required this.conversation,
    required this.otherName,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final MessagingService _messagingService = MessagingService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  bool _hasScrolledToBottom = false;
  int _lastMessageCount = 0;
  bool _isButtonPressed = false;
  bool _shouldStayAtBottom = false;

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    await _messagingService.markMessagesAsRead(widget.conversation.id);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && mounted) {
      try {
        final maxScroll = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(maxScroll);
      } catch (e) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && mounted) {
            try {
              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            } catch (_) {}
          }
        });
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && mounted) {
          try {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          } catch (_) {}
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isSending || _messageController.text.trim().isEmpty) return;

    final currentUserId = _authService.currentUserId;
    final receiverId = widget.conversation.getOtherParticipantId(currentUserId);
    final messageContent = _messageController.text.trim();

    _messageController.clear();
    
    setState(() {
      _isButtonPressed = true;
      _isSending = true;
      _shouldStayAtBottom = true; 
    });
    
    _scrollToBottom();
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isButtonPressed = false;
        });
      }
    });

    try {
      await _messagingService.sendMessage(
        receiverId: receiverId,
        content: messageContent,
        matchId: widget.conversation.matchId,
      );
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _scrollToBottom();
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _scrollToBottom();
            }
          });
        }
      });
    } catch (e) {
      _messageController.text = messageContent;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _isSending = false;
              _shouldStayAtBottom = false;
            });
          }
        });
      }
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.currentUserId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF00C8A0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Color(0xFF00C8A0),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    widget.conversation.getOtherParticipantRole(currentUserId),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messagingService.streamMessages(widget.conversation.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFF00C8A0),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Start a conversation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send the first message to get started',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final currentMessageCount = messages.length;
                final hasNewMessage = currentMessageCount > _lastMessageCount;

                if (_shouldStayAtBottom || _isSending) {
                  _lastMessageCount = currentMessageCount;
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      _hasScrolledToBottom = true;
                    }
                  });
                  Future.delayed(const Duration(milliseconds: 0), () {
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _scrollController.hasClients) {
                        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      }
                    });
                  });
                } 
                else if (hasNewMessage) {
                  _lastMessageCount = currentMessageCount;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      _hasScrolledToBottom = true;
                    }
                  });
                } 
                else if (!_hasScrolledToBottom) {
                  _lastMessageCount = currentMessageCount;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      _hasScrolledToBottom = true;
                    }
                  });
                } else {
                  _lastMessageCount = currentMessageCount;
                }

                final listView = ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00C8A0).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  widget.otherName.isNotEmpty ? widget.otherName[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: Color(0xFF00C8A0),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              decoration: BoxDecoration(
                                color: isMe 
                                    ? const Color(0xFF00C8A0)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.content,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black87,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatMessageTime(message.timestamp),
                                    style: TextStyle(
                                      color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey[600],
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isMe) const SizedBox(width: 8),
                        ],
                      ),
                    );
                  },
                );
                
                if (_shouldStayAtBottom) {
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _scrollController.hasClients) {
                      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                    }
                  });
                  Future.delayed(const Duration(milliseconds: 0), () {
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _scrollController.hasClients) {
                        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      }
                    });
                  });
                }
                
                return listView;
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isSending,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        hintStyle: TextStyle(color: Colors.grey[500]),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeInOut,
                  transform: Matrix4.identity()..scale(_isButtonPressed ? 0.9 : 1.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8A0),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C8A0).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}