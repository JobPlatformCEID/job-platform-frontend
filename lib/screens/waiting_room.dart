// lib/screens/waiting_room.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:livekit_client/livekit_client.dart';
import '../auth.dart';
import 'video_call_screen.dart';

class WaitingRoom extends StatefulWidget {
  final Auth auth;
  final String roomId;

  const WaitingRoom({
    super.key,
    required this.auth,
    required this.roomId,
  });

  @override
  State<WaitingRoom> createState() => _WaitingRoomState();
}

class _WaitingRoomState extends State<WaitingRoom> {
  Map<String, dynamic>? _roomData;
  bool _hostJoined = false;

  WebSocketChannel? _wsChannel;

  Future<void> _fetchRoomData() async {
    try {
      final response = await widget.auth.server.sendGet(
        '/api/calls/${widget.roomId}/',
        token: widget.auth.user!.token,
      );

      setState(() {
        _roomData = response;
      });

      debugPrint('[WaitingRoom] Fetched room data: $response');

      final meetingDate = DateTime.parse(response['meeting_date']);
      if (DateTime.now().isBefore(meetingDate)) {
        _leaveRoom();
      }
    } catch (e) {
      debugPrint('[WaitingRoom] Error fetching room data: $e');
    }
  }

  void _leaveRoom() {
    _wsChannel?.sink.close();
    Navigator.pop(context);
  }

  Future<void> _connectToWaitingList() async {
    try {
      final serverUrl = widget.auth.server.getServerUrl();
      final token = widget.auth.user!.token;

      final wsUrl = serverUrl!.replaceFirst('http', 'ws');
      final fullUrl = '$wsUrl/ws/calls/${widget.roomId}/?token=$token';

      debugPrint('[WaitingRoom] Connecting to: $fullUrl');

      _wsChannel = WebSocketChannel.connect(Uri.parse(fullUrl));

      _wsChannel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          debugPrint('[WaitingRoom] WS message: $data');

          final type = data['type'];

          if (type == 'room_state') {
            // Initial state on connect: tells us if host already started.
            final hostPresent = data['host_present'];
            setState(() {
              _hostJoined = (hostPresent == true || hostPresent == 1);
            });
          }

          if (type == 'call_started') {
            // Host has just started the call — unlock the Notify button.
            setState(() {
              _hostJoined = true;
            });
          }

          if (type == 'admitted') {
            // We were admitted by the host — join LiveKit immediately.
            // Do NOT call _startCall here for the host.
            // The host never receives 'admitted'; they get their token from
            // the REST endpoint and call _startCall themselves via the button.
            // Guests are the only ones who receive this message.
            _joinCallAsGuest(data['livekit_url'], data['livekit_token']);
          }
        },
        onError: (error) {
          debugPrint('[WaitingRoom] WS error: $error');
        },
        onDone: () {
          debugPrint('[WaitingRoom] WS closed — code: ${_wsChannel?.closeCode}, reason: ${_wsChannel?.closeReason}');
        },
      );

      debugPrint('[WaitingRoom] WebSocket connected, in waiting list');
    } catch (e) {
      debugPrint('[WaitingRoom] Failed to connect WebSocket: $e');
    }
  }

  void _notifyHost() {
    final user = widget.auth.user;
    if (user == null || _wsChannel == null) return;

    final message =
        '${user.username} (${user.fullName}) is waiting and would like to join';

    _wsChannel!.sink.add(jsonEncode({
      'type': 'notify_host',
      'message': message,
    }));

    debugPrint('[WaitingRoom] Notified host: $message');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Host has been notified')),
    );
  }

  /// Called by the HOST after pressing "Start Call".
  /// Order of operations:
  ///   1. Get LiveKit token from REST endpoint.
  ///   2. Connect to LiveKit room.
  ///   3. Enable camera + mic.
  ///   4. THEN send 'call_started' over WebSocket so the backend marks
  ///      the host as admitted and notifies guests. This ensures guests
  ///      only get the green light once the host is truly live.
  ///   5. Close the WebSocket and navigate to VideoCallScreen.

  Future<void> _startCallAsHost(String livekitUrl, String livekitToken) async {
    final room = Room();

    try {
      await room.connect(
        livekitUrl,
        livekitToken,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      await Future.wait([
        room.localParticipant?.setCameraEnabled(true) ?? Future.value(),
        room.localParticipant?.setMicrophoneEnabled(true) ?? Future.value(),
      ]);

      // Send call_started AFTER camera/mic are confirmed live —
      // not before connecting (old bug). Guests now only unlock their
      // Notify button once the host is genuinely in the call.
      if (_wsChannel != null) {
        _wsChannel!.sink.add(jsonEncode({'type': 'call_started'}));
        // Small delay so the message reaches the backend before we
        // close the socket below.
        await Future.delayed(const Duration(milliseconds: 200));
      }

      _wsChannel?.sink.close();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              room: room,
              roomName: _roomData?['room_name'] ?? 'Room',
              isHost: true,
              auth: widget.auth,
              roomId: widget.roomId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[WaitingRoom] Failed to start call: $e');
      // Dispose the room if something went wrong so we don't leak it.
      await room.disconnect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    }
  }

  /// Called when the GUEST receives an 'admitted' message.
  /// The LiveKit URL and token arrive over the WebSocket from the backend.
  Future<void> _joinCallAsGuest(String livekitUrl, String livekitToken) async {
    final room = Room();

    try {
      await room.connect(
        livekitUrl,
        livekitToken,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      await Future.wait([
        room.localParticipant?.setCameraEnabled(true) ?? Future.value(),
        room.localParticipant?.setMicrophoneEnabled(true) ?? Future.value(),
      ]);

      _wsChannel?.sink.close();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              room: room,
              roomName: _roomData?['room_name'] ?? 'Room',
              isHost: false,
              auth: widget.auth,
              roomId: widget.roomId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[WaitingRoom] Guest failed to join call: $e');
      await room.disconnect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join call: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchRoomData().then((_) {
      _connectToWaitingList();
    }).catchError((e) {
      debugPrint('[WaitingRoom] Init failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load room. Please try again.')),
        );
      }
    });
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHost = widget.auth.user?.userId == _roomData?['host_id'];
    final roomName = _roomData?['room_name'] ?? 'Room #${widget.roomId}';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: Text(
          roomName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _leaveRoom,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _hostJoined
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _hostJoined ? Icons.videocam : Icons.schedule,
                        size: 40,
                        color: _hostJoined ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_hostJoined) ...[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.orange),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Waiting for host to start call',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'Waiting for host to accept you',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      isHost
                          ? 'You are the host of this room'
                          : 'You are a guest in this room',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Action button
              if (isHost)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final response = await widget.auth.server.sendGet(
                          '/api/calls/${widget.roomId}/join/',
                          token: widget.auth.user!.token,
                        );
                        await _startCallAsHost(
                          response['livekit_url'],
                          response['livekit_token'],
                        );
                      } catch (e) {
                        debugPrint('[WaitingRoom] Failed to get LiveKit token: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to start call: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.videocam, size: 24),
                    label: const Text(
                      'Start Call',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    // Notify button is disabled until host has started the call.
                    onPressed: _hostJoined ? _notifyHost : null,
                    icon: Icon(
                      Icons.notifications_active,
                      size: 24,
                      color: _hostJoined ? Colors.white : Colors.grey[400],
                    ),
                    label: Text(
                      'Notify Host',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _hostJoined ? Colors.white : Colors.grey[400],
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _hostJoined ? Colors.blue : Colors.grey[300],
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[500],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: _hostJoined ? 2 : 0,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Leave button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _leaveRoom,
                  icon: const Icon(Icons.exit_to_app, size: 24),
                  label: const Text(
                    'Leave Room',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    side: BorderSide(color: Colors.red[200]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Room details
              if (_roomData != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Host: ${_roomData!['host']}',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Meeting: ${_roomData!['meeting_date']}',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                      if (_roomData!['description']?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.description,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _roomData!['description'],
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[700]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}