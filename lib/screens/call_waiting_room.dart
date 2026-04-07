import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../auth.dart';
import 'video_call_screen.dart';

class CallWaitingRoom extends StatefulWidget {
  final Auth auth;
  final String roomId; // FIX: Dynamic roomId parameter
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

  @override
  void initState() {
    super.initState();
    debugPrint('[CallWaitingRoom] initState: fetching room data...');
    _fetchRoomData();
  }

  Future<void> _fetchRoomData() async {
    try {
      // FIX: Use dynamic roomId
      final response = await widget.auth.user!.server.sendGet('/api/calls/${widget.roomId}/', token: widget.auth.user!.token);
      debugPrint('[CallWaitingRoom] Fetched room data successfully: $response');
      setState(() { roomData = response; isLoading = false; });
      _connectWebSocket();
    } catch (e) {
      debugPrint('[CallWaitingRoom] Failed to load room: $e');
      setState(() { error = 'Failed to load room: $e'; isLoading = false; });
    }
  }

  void _connectWebSocket() {
    final token = widget.auth.user!.token;
    final serverUrl = widget.auth.user!.server.getServerUrl()!;
    // FIX: Use dynamic roomId
    final wsUrl = serverUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://') + '/ws/calls/${widget.roomId}/?token=$token';
    debugPrint('[CallWaitingRoom] Connecting WebSocket to $wsUrl');
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
    if (!isHost) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have been removed from the waiting room.'), backgroundColor: Colors.red));
    }
  }

  void _handleWsMessage(Map<String, dynamic> message) {
    debugPrint('[CallWaitingRoom] Received WS message: $message');
    final type = message['type'];
    if (type == 'room_status') {
      setState(() { _callStarted = message['call_started'] as bool? ?? false; });
    }
    if (type == 'call_started') {
      setState(() => _callStarted = true);
    }
    if (type == 'admitted' && !_navigating) {
      debugPrint('[CallWaitingRoom] User admitted! Navigating to VideoCallScreen...');
      _navigating = true;
      final hostUsername = message['host_username'] as String?;
      final users = message['users'] as List<dynamic>?;
      final waiting = message['waiting_users'] as List<dynamic>?;
      _navigateToCall(hostUsername: hostUsername, initialUsers: users, initialWaiting: waiting);
    }
  }

  void _notifyHost() {
    if (_channel == null || !_callStarted) return;
    debugPrint('[CallWaitingRoom] Notifying host...');
    _channel!.sink.add(jsonEncode({'type': 'notify_host', 'message': '${widget.auth.user!.username} is waiting and would like to join the call.'}));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Host has been notified!')));
  }

  void _navigateToCall({String? hostUsername, List<dynamic>? initialUsers, List<dynamic>? initialWaiting}) {
    if (!mounted) return;
    debugPrint('[CallWaitingRoom] Transitioning to Call Screen.');
    
    // FIX: CRITICAL - Cancel subscription and CLOSE channel BEFORE navigation
    // VideoCallScreen will create its OWN fresh connection
    _subscription?.cancel();
    _channel?.sink.close();  // Close our connection
    _channel = null;         // Mark as disposed
    _subscription = null;
    
    final videoCallScreen = VideoCallScreen(
      roomId: widget.roomId, // FIX: Pass dynamic roomId
      token: widget.auth.user!.token,
      serverUrl: widget.auth.user!.server.getServerUrl()!,
      currentUsername: widget.auth.user!.username,
      isHost: isHost,
      hostUsername: hostUsername ?? roomData!['host'] as String?,
      // FIX: Do NOT pass existingChannel - let VideoCallScreen create fresh connection
      initialUsers: initialUsers,
      initialWaiting: initialWaiting,
    );
    
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => videoCallScreen));
  }

  Future<void> _startCall() async {
    debugPrint('[CallWaitingRoom] Host manually starting the call...');
    setState(() { isConnecting = true; _navigating = true; });
    _navigateToCall(hostUsername: roomData!['host'] as String?, initialUsers: [], initialWaiting: []);
  }

  bool get isHost => roomData != null && widget.auth.user?.username == roomData!['host'];

  @override
  void dispose() {
    debugPrint('[CallWaitingRoom] Disposing waiting room...');
    _subscription?.cancel();
    // FIX: Only close if we still own the channel (not already closed during navigation)
    if (_channel != null) {
      _channel!.sink.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Loading...')), body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Loading room information...')])));
    }
    if (error != null) {
      return Scaffold(appBar: AppBar(title: const Text('Error')), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error, size: 64, color: Colors.red), const SizedBox(height: 16), Text(error!), const SizedBox(height: 16), ElevatedButton(onPressed: _fetchRoomData, child: const Text('Retry'))])));
    }
    final String roomName = roomData!['room_name'] ?? 'Unknown Room';
    final String hostUsername = roomData!['host'] ?? 'Unknown Host';
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(roomName), backgroundColor: Colors.white, elevation: 1),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(32), margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle), child: Icon(Icons.video_call, size: 64, color: Colors.blue[700])),
              const SizedBox(height: 24), Text(roomName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8), Text('Host: $hostUsername', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              const SizedBox(height: 32),
              if (isHost) ...[
                if (isConnecting) ...[const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.green)), const SizedBox(height: 16), const Text('Connecting to call...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.green))]
                else ...[ElevatedButton.icon(onPressed: _startCall, icon: const Icon(Icons.play_arrow), label: const Text('Start Call'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))), const SizedBox(height: 16), Text('You are the host. Start the call when ready.', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center)],
              ] else ...[
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_callStarted ? Colors.green : Colors.grey)),
                const SizedBox(height: 16),
                if (!_callStarted) ...[const Text("Host hasn't started the call yet.", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey), textAlign: TextAlign.center), const SizedBox(height: 8), Text("You'll be notified the moment the host starts.", style: TextStyle(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center)]
                else ...[const Text('Host is in the call!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.green), textAlign: TextAlign.center), const SizedBox(height: 8), Text('Tap "Notify Host" to let them know you\'re ready.', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center)],
                const SizedBox(height: 24),
                ElevatedButton.icon(onPressed: _callStarted ? _notifyHost : null, icon: const Icon(Icons.notifications), label: const Text('Notify Host'), style: ElevatedButton.styleFrom(backgroundColor: _callStarted ? Colors.orange : Colors.grey[300], foregroundColor: _callStarted ? Colors.white : Colors.grey[500], padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}