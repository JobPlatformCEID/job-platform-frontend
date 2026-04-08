// lib/screens/waiting_room.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:livekit_client/livekit_client.dart';
import '../auth.dart';
import 'video_call_screen.dart';

// Minimal skeleton - matches CallsScreen._joinRoom() call
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
  
  // Stores the room details from backend:
  // id, room_name, host, host_id, meeting_date, description, is_active, created_at
  Map<String, dynamic>? _roomData;
  bool _hostJoined = false;
  
  // WebSocket channel for real-time communication with backend
  WebSocketChannel? _wsChannel;

  Future<void> _fetchRoomData() async {
    try {
        // Fetch room data (now includes host_id from backend)
        final response = await widget.auth.server.sendGet(
            '/api/calls/${widget.roomId}/', 
            token: widget.auth.user!.token
        );

        setState(() {
          _roomData = response;
        });

        debugPrint('[CallWaitingRoom] Fetched room data successfully: $response');

        final meetingDate = DateTime.parse(response['meeting_date']);
        if (DateTime.now().isBefore(meetingDate)) {
          _leave_room();
        }

    } 
    catch (e) {
      debugPrint('[CallWaitingRoom] Error fetching room data: $e');
    }
  }

  void _leave_room(){
    //close the wsChanel automatically calls disconnect so the user exits the waiting room
    _wsChannel?.sink.close();
    Navigator.pop(context);
  }

  Future<void> _put_user_in_waiting_list() async {
    try {
      final serverUrl = widget.auth.server.getServerUrl();
      final token = widget.auth.user!.token;
      
      // Convert http:// to ws:// or https:// to wss://
      final wsUrl = serverUrl!.replaceFirst('http', 'ws');
      final fullUrl = '$wsUrl/ws/calls/${widget.roomId}/?token=$token';
      
      debugPrint('[WaitingRoom] Connecting to: $fullUrl');
      debugPrint('[WaitingRoom] Token length: ${token.length}');
      
      _wsChannel = WebSocketChannel.connect(Uri.parse(fullUrl));
      
      _wsChannel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          debugPrint('[WaitingRoom] WS message: $data');
          
          final type = data['type'];
          
          // Initial room state - check if host already present
          if (type == 'room_state') {
            debugPrint('[WaitingRoom] room_state received: ${data}'); 
            setState(() {
             final host_present = data['host_present'];
              _hostJoined = (host_present == true || host_present == 1);
            });
          }
          
          // Host joined the call
          if (type == 'call_started') {
            setState(() {
              _hostJoined = true;
            });
          }
          
          // When this user gets admitted, check if they are the host
          if (type == 'admitted') {
            final currentUserId = widget.auth.user?.userId;
            final hostId = _roomData?['host_id'];
            if (currentUserId != null && currentUserId == hostId) {
              setState(() {
                _hostJoined = true;
              });
            }
            _start_call(data['livekit_url'], data['livekit_token']);
          }
        },
        onError: (error) {
          debugPrint('[WaitingRoom] WS error: $error');
        },
        onDone: () {
          debugPrint('[WaitingRoom] WS closed with code: ${_wsChannel?.closeCode}');
          debugPrint('[WaitingRoom] WS close reason: ${_wsChannel?.closeReason}');
        },
      );
      
      debugPrint('[WaitingRoom] Connected to WebSocket, user in waiting list');
    } catch (e) {
      debugPrint('[WaitingRoom] Failed to connect: $e');
    }
  }

  void _notify_host(){
    final user = widget.auth.user;
    if (user == null || _wsChannel == null) return;
    
    final message = '${user.username} (${user.fullName}) is waiting and would like to join';
    
    _wsChannel!.sink.add(jsonEncode({
      'type': 'notify_host',
      'message': message,
    }));
    
    debugPrint('[WaitingRoom] Notified host: $message');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Host has been notified')),
    );
  }

  void _start_call(String livekitUrl, String livekitToken) async {
    try {
      // Notify guests that host is starting the call BEFORE connecting to LiveKit
      if (_wsChannel != null) {
        _wsChannel!.sink.add(jsonEncode({
          'type': 'call_started',
        }));
        // Give time for message to propagate
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      final room = Room();
      
      await room.connect(
        livekitUrl,
        livekitToken,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      // Initialize camera and mic in parallel to speed up startup
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
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[WaitingRoom] Failed to connect to LiveKit: $e');
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
      _put_user_in_waiting_list();
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
          onPressed: _leave_room,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Room Info Card
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
                    // Status Icon
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
                    
                    // Status Text
                    if (!_hostJoined) ...[
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
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
                        'Waiting for host to accept you in call',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      isHost
                          ? 'You are the host of this room'
                          : 'You are a guest in this room',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Action Buttons
              if (isHost)
                // Host View - Start Call Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Host calls API to get LiveKit token, then joins
                      try {
                        final response = await widget.auth.server.sendGet(
                          '/api/calls/${widget.roomId}/join/',
                          token: widget.auth.user!.token,
                        );
                        _start_call(
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
                // Guest View - Notify Button (disabled until host joins)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _hostJoined ? _notify_host : null,
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
                      backgroundColor: _hostJoined
                          ? Colors.blue
                          : Colors.grey[300],
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
              
              // Leave Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _leave_room,
                  icon: const Icon(Icons.exit_to_app, size: 24),
                  label: const Text(
                    'Leave Room',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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
              
              // Room Details
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
                          Icon(Icons.person, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Host: ${_roomData!['host']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Meeting: ${_roomData!['meeting_date']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      if (_roomData!['description']?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.description, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _roomData!['description'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
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