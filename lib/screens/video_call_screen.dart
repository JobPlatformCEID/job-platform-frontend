import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final String token;
  final String serverUrl;      // passed from CallWaitingRoom — no more hardcoded localhost
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
  final List<Map<String, String>> _messages = [];  // {sender, message}
  bool _isMuted     = false;
  bool _isVideoOff  = false;
  bool _isSpeakerOn = false;

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

    // If this is the host, broadcast call_started as soon as the WS handshake
    // completes. We wait for the first message from the server (room_status)
    // before sending so the connection is fully established.
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'];

    // Once our own connection is confirmed by the server, broadcast the fact
    // that the call has started. This is the single source of truth.
    if (type == 'room_status' && widget.isHost) {
      _channel!.sink.add(jsonEncode({'type': 'call_started'}));
    }

    if (type == 'message') {
      final sender  = message['sender'] as String? ?? 'Unknown';
      final content = message['message'] as String? ?? '';
      _addMessage(sender, content);
    }
  }

  void _addMessage(String sender, String content) {
    setState(() => _messages.add({'sender': sender, 'message': content}));
    // Scroll to bottom after the frame renders
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // ── Video area ───────────────────────────────────────────────────
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

          // ── Messages area ────────────────────────────────────────────────
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

          // ── Control buttons ───────────────────────────────────────────────
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}