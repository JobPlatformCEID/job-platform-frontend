import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../auth.dart';

// Data models

class _WaitingUser {
  final int id;
  final String username;
  final DateTime joinedAt;

  _WaitingUser({
    required this.id,
    required this.username,
    DateTime? joinedAt,
  }) : joinedAt = joinedAt ?? DateTime.now();
}

// in the future we can add whispers, etc.
enum _msgKind { chat , notification }

class _ChatMessage{
  final String sender;
  final String content;
  final DateTime timestamp;
  final _msgKind kind;

  _ChatMessage({
    required this.sender,
    required this.content,
    required this.kind,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

}

// screen
class VideoCallScreen extends StatefulWidget {
  final Room room;
  final String roomName;

  //used to differentiate the uis
  final bool isHost;

  final String roomId;
  final Auth auth;

  const VideoCallScreen({
    super.key,
    required this.room,
    required this.roomName,
    required this.isHost,
    required this.auth,
    required this.roomId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  
  //chat history messages (plus other chat realted)
  final List<_ChatMessage> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  int _unreadMessages = 0;

  //list of the participants
  List<Participant> _participants = [];

  //this is only for the host to see the people who are waiting 
  final Map<String, _WaitingUser> _waitingUsers = {};
  
  // bool variables for controls
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _isChatOpen = false;

  // Websockets for waiting room events + host notifications
  WebSocketChannel? _wsChannel;

  Future<void> _connectWebSocket() async {
    try {
      final serverUrl = widget.auth.server.getServerUrl();
      final token = widget.auth.user!.token;

      final wsUrl = serverUrl!.replaceFirst('http', 'ws');
      final fullUrl = '$wsUrl/ws/calls/${widget.roomId}/?token=$token';

      debugPrint('[VideoCallScreen] Connecting to WebSocket: $fullUrl');

      _wsChannel = WebSocketChannel.connect(Uri.parse(fullUrl));

      _wsChannel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          debugPrint('[VideoCallScreen] WS message: $data');
          _handleWebSocketMessage(data);
        },
        onError: (error) {
          debugPrint('[VideoCallScreen] WS error: $error');
        },
        onDone: () {
          debugPrint('[VideoCallScreen] WS closed');
        },
      );
    } catch (e) {
      debugPrint('[VideoCallScreen] Failed to connect WebSocket: $e');
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'host_notification':
        final msg = data['message'] ?? '';
        final fromUser = data['from_user'] ?? 'Guest';
        _addMessage(_ChatMessage(
          sender: 'System',
          content: '$fromUser: $msg',
          kind: _msgKind.notification,
        ));
        
        break;

      case 'user_wants_to_join':
        final fromUser = data['from_user'] ?? 'Guest';
        _addMessage(_ChatMessage(
          sender: 'System',
          content: '$fromUser is waiting to join',
          kind: _msgKind.notification,
        ));
        break;

      case 'waiting_users_updated':
        // Host receives updated waiting list - update UI if needed
        final waitingUsers = data['waiting_users'] as List<dynamic>?;
        debugPrint('[VideoCallScreen] Waiting users updated: $waitingUsers');
        break;

      case 'kicked':
        _wsChannel?.sink.close();
        widget.room.disconnect();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have been removed from the call')),
          );
          Navigator.pop(context);
        }
        break;

      case 'chat_message':
        // Handle chat messages from backend (if using WebSocket instead of LiveKit)
        break;
    }
  }

  // setup plus dispose
  @override
  void initState() {
    super.initState();
    _setupListeners();
    _updateParticipants();
    _connectWebSocket();
  }

  void _setupListeners() {
    widget.room.addListener(_updateParticipants);
  }

  void _disposeListeners() {
    widget.room.removeListener(_updateParticipants);
  }

  void _updateParticipants() {
    setState(() {
      _participants = widget.room.remoteParticipants.values.toList();
    });
  }

  @override
  void dispose() {
    _disposeListeners();
    _wsChannel?.sink.close();
    widget.room.disconnect();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  // chat related functions

  void _addMessage(_ChatMessage msg){

    setState(() {
      _chatMessages.add(msg);
      if (!_isChatOpen) _unreadMessages++;
    });

    debugPrint('Added message sent by ${msg.sender}: ${msg.content} , ${msg.kind}');
    
    //TODO integrate with ui.
  }

  void _sendMessage(){
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    
    _chatController.clear();

    // Publish bia Livekit data channel to all participants
    widget.room.localParticipant?.publishData(
      utf8.encode(jsonEncode({
        'type': 'chat',
        'message': text,
      })),
      reliable: true,
    );

    // Show locally
    _addMessage(_ChatMessage(
      sender: widget.auth.user?.username ?? 'You',
      content: text,
      kind: _msgKind.chat,
    ));
  }

  // Call actions
  Future<void> _toggleMic() async {
    final newState = !_isMicEnabled;
    await widget.room.localParticipant?.setMicrophoneEnabled(newState);
    setState(() => _isMicEnabled = newState);
  }

  Future<void> _toggleCamera() async {
    final newState = !_isCameraEnabled;
    await widget.room.localParticipant?.setCameraEnabled(newState);
    setState(() => _isCameraEnabled = newState);
  }

  void _leaveCall(){

  }

  // Host only actions

  void _admitUser(String username){

  }

  void _kickUser(String username){

  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end),
            onPressed: () {
              widget.room.disconnect();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Local video (your camera - already connected)
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              child: widget.room.localParticipant != null
                  ? VideoTrackWidget(
                      participant: widget.room.localParticipant!,
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          ),
          // Remote participants
          Expanded(
            flex: 2,
            child: _participants.isEmpty
                ? const Center(
                    child: Text('Waiting for others to join...'),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      return VideoTrackWidget(
                        participant: _participants[index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class VideoTrackWidget extends StatelessWidget {
  final Participant participant;

  const VideoTrackWidget({
    super.key,
    required this.participant,
  });

  @override
  Widget build(BuildContext context) {
    final videoTrack = participant.videoTrackPublications.firstOrNull?.track as VideoTrack?;
    
    if (videoTrack == null) {
      return Container(
        color: Colors.grey[800],
        child: Center(
          child: Text(
            participant.identity,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return VideoTrackRenderer(
      videoTrack,
      fit: VideoViewFit.cover,
    );
  }
}
