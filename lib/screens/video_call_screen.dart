import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final String token;
  final String serverUrl;
  final String currentUsername;
  final bool isHost;

  const VideoCallScreen({
    super.key,
    required this.roomId,
    required this.token,
    required this.serverUrl,
    required this.currentUsername,
    this.isHost = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isMuted     = false;
  bool _isVideoOff  = false;
  bool _isSpeakerOn = false;

  bool _showWaitingPanel = false;
  // Keyed by username for O(1) add/remove — value is the display username
  final Map<String, String> _waitingGuests = {};

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    final wsUrl = widget.serverUrl
            .replaceFirst('http://', 'ws://')
            .replaceFirst('https://', 'wss://') +
        '/ws/calls/${widget.roomId}/?token=${widget.token}';

    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _subscription = _channel!.stream.listen(
      (data) => _handleWebSocketMessage(jsonDecode(data as String)),
      onError: (e) => debugPrint('WebSocket error: $e'),
      onDone:  () => debugPrint('WebSocket closed'),
    );
  }

  // The server sends users as List<{id: int, username: String}>.
  // Rebuild _waitingGuests from it, excluding the host (self).
  void _syncGuestsFromUsersList(dynamic users) {
    if (users is! List) return;
    final updated = <String, String>{};
    for (final u in users) {
      if (u is Map) {
        final username = u['username'] as String? ?? '';
        if (username.isNotEmpty && username != widget.currentUsername) {
          updated[username] = username;
        }
      }
    }
    setState(() {
      _waitingGuests
        ..clear()
        ..addAll(updated);
    });
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'];

    // Server confirmed our connection — broadcast call_started (host only)
    // and seed the guest list from whoever is already present
    if (type == 'room_status' && widget.isHost) {
      _channel!.sink.add(jsonEncode({'type': 'call_started'}));
      _syncGuestsFromUsersList(message['users']);
    }

    // Someone joined or left — always resync from the authoritative list
    if ((type == 'user_joined' || type == 'user_left') && widget.isHost) {
      _syncGuestsFromUsersList(message['users']);
    }

    // Incoming chat / notify_host message
    if (type == 'message') {
      final sender  = message['sender'] as String? ?? 'Unknown';
      final content = message['message'] as String? ?? '';
      _addMessage(sender, content);
    }
  }

  void _addMessage(String sender, String content) {
    setState(() => _messages.add({'sender': sender, 'message': content}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty || _channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type':    'message',
      'message': _messageController.text.trim(),
    }));
    _messageController.clear();
  }

  void _acceptGuest(String username) {
    debugPrint('Accept guest: $username (placeholder)');
    // TODO: implement
  }

  void _rejectGuest(String username) {
    debugPrint('Reject guest: $username (placeholder)');
    // TODO: implement kick
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final guestList = _waitingGuests.keys.toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Main column ────────────────────────────────────────────────
          Column(
            children: [
              // Video area
              Expanded(
                flex: 3,
                child: Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam_off, size: 80, color: Colors.white54),
                        SizedBox(height: 16),
                        Text(
                          'Video feed will appear here',
                          style: TextStyle(color: Colors.white54, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Messages area
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.grey[800],
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.message, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Call Messages',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _messages.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No messages yet...',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final msg    = _messages[index];
                                    final sender = msg['sender']!;
                                    final isMe   = sender == widget.currentUsername;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '$sender: ',
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.lightBlueAccent
                                                    : Colors.orangeAccent,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: msg['message'],
                                              style: const TextStyle(color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: const TextStyle(color: Colors.white54),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Colors.white54),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Colors.white54),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Colors.blue),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _sendMessage,
                            icon: const Icon(Icons.send, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Control bar
              Container(
                color: Colors.grey[900],
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _isMuted = !_isMuted),
                      icon: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: _isMuted ? Colors.red : Colors.white,
                        size: 32,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _isVideoOff = !_isVideoOff),
                      icon: Icon(
                        _isVideoOff ? Icons.videocam_off : Icons.videocam,
                        color: _isVideoOff ? Colors.red : Colors.white,
                        size: 32,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.call_end, color: Colors.red, size: 40),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                      icon: Icon(
                        _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                        color: _isSpeakerOn ? Colors.blue : Colors.white,
                        size: 32,
                      ),
                    ),
                    if (widget.isHost)
                      GestureDetector(
                        onTap: () => setState(() => _showWaitingPanel = !_showWaitingPanel),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _showWaitingPanel ? Colors.orange : Colors.blue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people, color: Colors.white, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                '${guestList.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // ── Waiting panel — floats above control bar, bottom-right ─────
          if (widget.isHost && _showWaitingPanel)
            Positioned(
              bottom: 80,
              right: 16,
              width: 220,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[600]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_top, color: Colors.orange, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Waiting (${guestList.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.grey, height: 1),
                      if (guestList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No one waiting',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(8),
                            itemCount: guestList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final username = guestList[index];
                              final initial  = username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : '?';
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[700],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.blueAccent,
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        username,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _acceptGuest(username),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () => _rejectGuest(username),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
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
}