import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import '../auth.dart';
import '../server.dart';
import '../conversation.dart';

class MessagesScreen extends StatefulWidget {
  final Conversation conversation;
  final Server server;
  final Auth auth;

  const MessagesScreen({
    super.key,
    required this.conversation,
    required this.server,
    required this.auth,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  String? _error;
  WebSocketChannel? _channel;
  int _otherUserLastRead = 0;

  String get _token => widget.auth.user!.token;
  int get _conversationId => widget.conversation.id;

  @override
  void initState() {
    super.initState();
    _otherUserLastRead = widget.conversation.readStatuses[widget.conversation.otherUserId] ?? 0;
    _loadMessages();
    _connectWebSocket();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await Message.fetchAllMessages(widget.server, _token, _conversationId);
      if (mounted) setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load messages.';
      });
    }
  }

  void _connectWebSocket() {
    final serverUrl = widget.server.getServerUrl() ?? '';
    // Replace http with ws
    final wsUrl = serverUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl/ws/conversations/$_conversationId/?token=$_token'),
      );

      _channel!.stream.listen(
        (data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          final type = json['type'] as String?;

          if (type == 'message') {
            final message = Message(
              id: json['message_id'] as int,
              sender: json['sender_id'] as int,
              senderUsername: json['sender_username'] as String?,
              conversation: _conversationId,
              content: json['content'] as String,
              createdAt: json['created_at'] as String,
            );
            if (mounted) setState(() => _messages.add(message));
            _scrollToBottom();
          } else if (type == 'read') { 
            final readerId = json['reader_id'] as int?;
            final lastReadMessageId = json['last_read_message_id'] as int? ?? 0;
            // If the other user read the messages, update last read message id
            if (readerId != null &&
                readerId == widget.conversation.otherUserId) {
              if (mounted) setState(() => _otherUserLastRead = lastReadMessageId);
            }
          }
        },
        onError: (e) {
          if (mounted) setState(() => _error = 'Connection lost.');
        },
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not connect to chat.');
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    _channel?.sink.add(jsonEncode({'content': content}));
    _messageController.clear();
    if (mounted) setState(() => _otherUserLastRead = 0);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleDeleteMessage(Message message) async {
    try {
      await message.deleteMessage(widget.server, _token);
      if (mounted) setState(() => _messages.removeWhere((m) => m.id == message.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete message.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.conversation.otherUsername ?? 'User #${widget.conversation.otherUserId}'),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet. Say hello!'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isOwn = message.sender == widget.auth.user!.userId;
                          final isLast = index == _messages.length - 1;
                          final isSeen = _otherUserLastRead >= message.id;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _MessageBubble(
                                message: message,
                                isOwn: isOwn,
                                onLongPress: () => _handleDeleteMessage(message),
                              ),
                              if (isLast && isOwn && isSeen)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                                  child: Text(
                                    'Seen',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
          ),
          // Input bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    // + button placeholder
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        // TODO: attachments (images etc) are not supported by the server yet
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: 'Type here',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwn;
  final VoidCallback onLongPress;

  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          decoration: BoxDecoration(
            color: isOwn
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isOwn ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isOwn ? const Radius.circular(4) : const Radius.circular(16),
            ),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: isOwn
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
