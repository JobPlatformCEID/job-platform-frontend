import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../auth.dart';
import 'video_call_screen.dart';

class CallWaitingRoom extends StatefulWidget {
  final Auth auth;
  final String roomId;
  const CallWaitingRoom({super.key, required this.auth, required this.roomId});

  @override
  State<CallWaitingRoom> createState() => _CallWaitingRoomState();
}

class _CallWaitingRoomState extends State<CallWaitingRoom> {
  Map<String, dynamic>? roomData;
  bool isLoading = true;
  bool isConnecting = false;
  String? error;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _callStarted = false;
  bool _navigating = false;
  List<String> _waitingUsers = [];
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  @override
  void initState() {
    super.initState();
    debugPrint('[CallWaitingRoom] initState: fetching room data...');
    _fetchRoomData();
  }

  Future<void> _fetchRoomData() async {
    try {
      final response = await widget.auth.user!.server.sendGet(
        '/api/calls/${widget.roomId}/',
        token: widget.auth.user!.token,
      );
      debugPrint('[CallWaitingRoom] Fetched room data successfully: $response');
      setState(() {
        roomData = response;
        isLoading = false;
      });

      final meetingDate = DateTime.parse(response['meeting_date']);
      if (DateTime.now().isBefore(meetingDate)) {
        return;
      }

      _connectWebSocket();
    } catch (e) {
      debugPrint('[CallWaitingRoom] Failed to load room: $e');
      setState(() {
        error = 'Failed to load room: $e';
        isLoading = false;
      });
    }
  }

  void _connectWebSocket() {
    if (_channel != null) {
      _channel!.sink.close();
      _subscription?.cancel();
    }
    _reconnectAttempts = 0;
    final serverUrl = widget.auth.user!.server.getServerUrl()!;
    final wsUrl =
        serverUrl
            .replaceFirst('http://', 'ws://')
            .replaceFirst('https://', 'wss://') +
        '/ws/calls/${widget.roomId}/?token=${widget.auth.user!.token}';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _subscription = _channel!.stream.listen(
      (data) => _handleWsMessage(jsonDecode(data as String)),
      onError: (e) => debugPrint('[CallWaitingRoom] WS error: $e'),
      onDone: _handleWsClosed,
    );
  }

  void _handleWsClosed() {
    debugPrint('[CallWaitingRoom] WS Closed (navigating: $_navigating)');
    if (!mounted || _navigating) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      setState(() {
        error = 'Failed to connect to waiting room. Please try again.';
      });
      return;
    }

    _reconnectAttempts++;
    _reconnectWebSocket();
  }

  void _reconnectWebSocket() {
    debugPrint(
      '[CallWaitingRoom] Attempting to reconnect... ($_reconnectAttempts/$_maxReconnectAttempts)',
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _reconnectAttempts <= _maxReconnectAttempts) {
        _connectWebSocket();
      }
    });
  }

  void _handleWsMessage(Map<String, dynamic> message) {
    debugPrint('[CallWaitingRoom] Received WS message: $message');
    final type = message['type'];
    if (type == 'room_status') {
      setState(() {
        _callStarted = message['call_started'] as bool? ?? false;
        if (message['waiting_users'] is List) {
          _waitingUsers = (message['waiting_users'] as List)
              .map((e) => e.toString())
              .toList();
        }
      });
    }
    if (type == 'call_started') {
      setState(() => _callStarted = true);
    }
    if (type == 'kicked' && !isHost) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You have been removed from the waiting room by the host.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
    if (type == 'admitted' && !_navigating) {
      _navigating = true;
      final livekitUrl = message['livekit_url'] as String;
      final livekitToken = message['livekit_token'] as String;
      final hostUsername = message['host_username'] as String?;
      _navigateToCall(
        livekitUrl: livekitUrl,
        livekitToken: livekitToken,
        hostUsername: hostUsername,
      );
    }
  }

  void _notifyHost() {
    if (_channel == null || !_callStarted) return;
    debugPrint('[CallWaitingRoom] Notifying host...');
    _channel!.sink.add(
      jsonEncode({
        'type': 'notify_host',
        'message':
            '${widget.auth.user!.username} is waiting and would like to join the call.',
      }),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Host has been notified!')));
  }

  void _admitUser(String username) {
    if (_channel == null) return;
    _channel!.sink.add(
      jsonEncode({'type': 'admit_guest', 'username': username}),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Admitted $username')));
  }

  void _kickUser(String username) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'kick_user', 'username': username}));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Kicked $username')));
  }

  void _navigateToCall({
    required String livekitUrl,
    required String livekitToken,
    String? hostUsername,
  }) {
    if (!mounted) return;
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          roomId: widget.roomId,
          livekitUrl: livekitUrl,
          livekitToken: livekitToken,
          currentUsername: widget.auth.user!.username,
          isHost: isHost,
          hostUsername: hostUsername ?? roomData!['host'] as String?,
        ),
      ),
    );
  }

  Future<void> _startCall() async {
    setState(() {
      isConnecting = true;
      _navigating = true;
    });
    try {
      final resp = await widget.auth.user!.server.sendGet(
        '/api/calls/${widget.roomId}/join/',
        token: widget.auth.user!.token,
      );
      _navigateToCall(
        livekitUrl: resp['livekit_url'] as String,
        livekitToken: resp['livekit_token'] as String,
        hostUsername: widget.auth.user!.username,
      );
    } catch (e) {
      debugPrint('[CallWaitingRoom] Failed to start call: $e');
      setState(() {
        isConnecting = false;
        _navigating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  bool get isHost =>
      roomData != null && widget.auth.user?.username == roomData!['host'];

  @override
  void dispose() {
    debugPrint('[CallWaitingRoom] Disposing waiting room...');
    _subscription?.cancel();
    if (_channel != null) {
      _channel!.sink.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading room information...'),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchRoomData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final String roomName = roomData!['room_name'] ?? 'Unknown Room';
    final String hostUsername = roomData!['host'] ?? 'Unknown Host';
    final String meetingDate = roomData!['meeting_date'] ?? '';
    final DateTime meetingDateTime = DateTime.parse(meetingDate);
    final bool isMeetingStarted = DateTime.now().isAfter(meetingDateTime);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(roomName),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header circle icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.video_call,
                    size: 64,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 24),

                // Room info
                Text(
                  roomName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Host: $hostUsername',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scheduled: ${meetingDateTime.toLocal()}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),

                // Conditional content based on meeting status
                if (!isMeetingStarted) ...[
                  const Icon(Icons.schedule, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Meeting has not started yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait until: ${meetingDateTime.toLocal()}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _fetchRoomData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else ...[
                  // Meeting has started - show host/guest UI
                  if (isHost) ...[
                    // Host view: show waiting users list
                    if (_waitingUsers.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Waiting Users:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._waitingUsers.map(
                        (username) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(username)),
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                onPressed: () => _admitUser(username),
                                tooltip: 'Admit',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () => _kickUser(username),
                                tooltip: 'Kick',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Host connect button
                    if (isConnecting) ...[
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Connecting to call...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _startCall,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You are the host. Start the call when ready.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ] else ...[
                    // Guest view
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _callStarted ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_callStarted) ...[
                      const Text(
                        "Host hasn't started the call yet.",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "You'll be notified the moment the host starts.",
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      const Text(
                        'Host is in the call!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tap \"Notify Host\" to let them know you're ready.",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _callStarted ? _notifyHost : null,
                      icon: const Icon(Icons.notifications),
                      label: const Text('Notify Host'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _callStarted
                            ? Colors.orange
                            : Colors.grey[300],
                        foregroundColor: _callStarted
                            ? Colors.white
                            : Colors.grey[500],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
