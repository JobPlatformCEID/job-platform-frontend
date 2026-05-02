import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import '../auth.dart';
import '../server.dart';
import '../conversation.dart';
import '../calls.dart';
import '../user.dart';
import '../theme/app_theme.dart';
import 'call_room_screen.dart';

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

            if (message.sender != widget.auth.user!.userId) {
              _channel?.sink.add(jsonEncode({
                'type': 'read',
                'message_id': message.id,
              }));
            }
          } else if (type == 'read') {
            final readerId = json['reader_id'] as int?;
            final lastReadMessageId = json['last_read_message_id'] as int? ?? 0;
            if (readerId != null && readerId == widget.conversation.otherUserId) {
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

  void _showPlusSheet() {
    final isEmployer = widget.auth.user is Employer;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if(isEmployer)
              ListTile(
                leading: Icon(
                  Icons.video_call_outlined,
                  color: isEmployer ? null : Theme.of(context).disabledColor,
                ),
                title: const Text('Schedule a meeting'),
                onTap: () {
                      Navigator.of(context).pop();
                      _showCreateCallSheet();
                    },
              ),

          ],
        ),
      ),
    );
  }

  void _showCreateCallSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateCallSheet(
        server: widget.server,
        token: _token,
        otherUserId: widget.conversation.otherUserId!,
        otherName: widget.conversation.otherFullName ?? widget.conversation.otherUsername ?? 'User',
        onCallCreated: (room) {
          _channel?.sink.add(jsonEncode({
            'content': jsonEncode({
              'type': 'call',
              'room_id': room.id,
              'room_name': room.roomName,
            }),
          }));
          if (mounted) setState(() => _otherUserLastRead = 0);
        },
      ),
    );
  }

  Future<void> _joinCall(int roomId) async {
    try {
      // Add ourselves as participant in case we're joining via link
      final rooms = await CallRoom.fetchAll(widget.server, _token);
      final room = rooms.firstWhere((r) => r.id == roomId);
      if (!room.isParticipant) {
        await room.addParticipant(widget.server, _token);
      }
      final callToken = await room.getToken(widget.server, _token);
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CallRoomScreen(
            token: callToken.token,
            url: callToken.url,
            roomName: callToken.roomName,
            isHost: callToken.isHost,
            displayName: room.roomName,
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not join call.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: Text(
          widget.conversation.otherFullName ??
              widget.conversation.otherUsername ??
              'User #${widget.conversation.otherUserId}',
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              color: AppTheme.error.withAlpha(38),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(38),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error.withAlpha(77)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet. Say hello!',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
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
                                serverUrl: widget.server.getServerUrl() ?? '',
                                onLongPress: () => _handleDeleteMessage(message),
                                onJoinCall: _joinCall,
                              ),
                              if (isLast && isOwn && isSeen)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                                  child: Text(
                                    'Seen',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppTheme.textSecondary),
                      onPressed: _showPlusSheet,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Type here',
                          hintStyle: const TextStyle(color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.surfaceAlt,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: AppTheme.primary),
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

Map<String, dynamic>? _parseCallPayload(String content) {
  try {
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    if (decoded['type'] == 'call') return decoded;
  } catch (_) {}
  return null;
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwn;
  final String serverUrl;
  final VoidCallback onLongPress;
  final void Function(int roomId) onJoinCall;

  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.serverUrl,
    required this.onLongPress,
    required this.onJoinCall,
  });

  @override
  Widget build(BuildContext context) {
    final callPayload = _parseCallPayload(message.content);

    if (callPayload != null) {
      final roomId = callPayload['room_id'] as int;
      return Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primary,
                    child: const Icon(Icons.video_call, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Video call',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FilledButton(
                          onPressed: () => onJoinCall(roomId),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                          ),
                          child: const Text('Join'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Regular text bubble
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          decoration: BoxDecoration(
            color: isOwn
                ? AppTheme.primary.withValues(alpha: 0.2)
                : AppTheme.surfaceAlt,
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
              color: isOwn ? AppTheme.primary : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateCallSheet extends StatefulWidget {
  final Server server;
  final String token;
  final int otherUserId;
  final String otherName;
  final void Function(CallRoom room) onCallCreated;

  const _CreateCallSheet({
    required this.server,
    required this.token,
    required this.otherUserId,
    required this.otherName,
    required this.onCallCreated,
  });

  @override
  State<_CreateCallSheet> createState() => _CreateCallSheetState();
}

class _CreateCallSheetState extends State<_CreateCallSheet> {
  late final TextEditingController _nameController;
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Call with ${widget.otherName}');
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _pickedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) setState(() => _pickedTime = time);
  }

  DateTime _resolvedDateTime() {
    final now = DateTime.now();
    final date = _pickedDate ?? now;
    final time = _pickedTime ?? TimeOfDay(hour: now.hour, minute: now.minute);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatResolved() {
    final dt = _resolvedDateTime();
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (_pickedDate == null && _pickedTime == null) return 'Now';
    return '${dt.day}/${dt.month}/${dt.year} $timeStr';
  }

Future<void> _handleCreate() async {
  if (_nameController.text.trim().isEmpty) {
    setState(() => _error = 'Room name is required.');
    return;
  }
  setState(() { _isLoading = true; _error = null; });
  try {
    // host will be added as participant during create
    final room = await CallRoom.create(
      widget.server,
      widget.token,
      roomName: _nameController.text.trim(),
      description: '',
      meetingDate: _resolvedDateTime(),
    );

    // we add the user were chatting with as a participant
    await room.addParticipant(widget.server, widget.token, userId: widget.otherUserId);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onCallCreated(room);
    }
  } catch (e) {
    if (mounted) setState(() => _error = 'Could not create call.');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Schedule a meeting', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Call name',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
              ),
              const SizedBox(height: 16),
              // Date and time as two separate buttons in a row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        _pickedDate != null
                            ? '${_pickedDate!.day}/${_pickedDate!.month}/${_pickedDate!.year}'
                            : 'Pick Date',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time_outlined, size: 16),
                      label: Text(
                        _pickedTime != null
                            ? '${_pickedTime!.hour.toString().padLeft(2, '0')}:${_pickedTime!.minute.toString().padLeft(2, '0')}'
                            : 'Pick Time',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Show resolved time so user knows what they're getting
              Text(
                'Scheduled for: ${_formatResolved()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _handleCreate,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Schedule meeting'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}