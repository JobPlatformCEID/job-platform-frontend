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
        // Auto-show admit dialog for host
        if (widget.isHost && mounted) {
          _showAdmitPrompt(fromUser, msg);
        }
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
        final waitingUsernames = data['waiting_users'] as List<dynamic>?;
        debugPrint('[VideoCallScreen] Waiting users updated: $waitingUsernames');
        setState(() {
          _waitingUsers.clear();
          waitingUsernames?.forEach((username) {
            final name = username as String;
            _waitingUsers[name] = _WaitingUser(
              id: name.hashCode, // temporary ID
              username: name,
            );
          });
        });
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

  void _leaveCall() {
    _wsChannel?.sink.close();
    widget.room.disconnect();
    Navigator.pop(context);
  }

  // Host only actions

  void _admitUser(String username) {
    if (!widget.isHost) return;
    _wsChannel?.sink.add(jsonEncode({
      'type': 'admit_guest',
      'username': username,
    }));
    debugPrint('[VideoCallScreen] Admitting user: $username');
  }

  void _kickUser(String username) {
    if (!widget.isHost) return;
    _wsChannel?.sink.add(jsonEncode({
      'type': 'kick_user',
      'username': username,
    }));
    debugPrint('[VideoCallScreen] Kicking user: $username');
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          // Waiting users badge for host
          if (widget.isHost && _waitingUsers.isNotEmpty)
            Badge(
              label: Text('${_waitingUsers.length}'),
              child: IconButton(
                icon: const Icon(Icons.people_outline),
                onPressed: _showWaitingUsersDialog,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.red),
            onPressed: _leaveCall,
          ),
        ],
      ),
      body: Column(
        children: [
          // Video grid area
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.black,
              child: _buildVideoGrid(),
            ),
          ),
          // Control bar
          Container(
            height: 70,
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mic toggle
                IconButton(
                  icon: Icon(
                    _isMicEnabled ? Icons.mic : Icons.mic_off,
                    color: _isMicEnabled ? Colors.white : Colors.red,
                    size: 28,
                  ),
                  onPressed: _toggleMic,
                ),
                const SizedBox(width: 24),
                // Camera toggle
                IconButton(
                  icon: Icon(
                    _isCameraEnabled ? Icons.videocam : Icons.videocam_off,
                    color: _isCameraEnabled ? Colors.white : Colors.red,
                    size: 28,
                  ),
                  onPressed: _toggleCamera,
                ),
                const SizedBox(width: 24),
                // Leave call
                IconButton(
                  icon: const Icon(Icons.call_end, color: Colors.red),
                  iconSize: 32,
                  onPressed: _leaveCall,
                ),
                const SizedBox(width: 24),
                // Chat toggle
                IconButton(
                  icon: Icon(
                    Icons.chat_bubble,
                    color: _unreadMessages > 0 ? Colors.orange : Colors.white,
                  ),
                  onPressed: _toggleChatPanel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    final allParticipants = [
      if (widget.room.localParticipant != null) widget.room.localParticipant!,
      ..._participants,
    ];

    if (allParticipants.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for others to join...',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Single participant - fullscreen
    if (allParticipants.length == 1) {
      return _buildParticipantTile(allParticipants[0], isLarge: true);
    }

    // Multiple participants - grid
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: allParticipants.length <= 2 ? 1 : 2,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: allParticipants.length,
      itemBuilder: (context, index) {
        return _buildParticipantTile(allParticipants[index]);
      },
    );
  }

  Widget _buildParticipantTile(Participant participant, {bool isLarge = false}) {
    final isLocal = participant is LocalParticipant;
    final username = participant.identity;

    return Stack(
      children: [
        // Video
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: VideoTrackWidget(participant: participant),
          ),
        ),
        // Name badge
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isLocal ? 'You ($username)' : username,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        // Host kick button (only for remote participants)
        if (widget.isHost && !isLocal)
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
              onPressed: () => _showKickConfirmDialog(username),
              tooltip: 'Remove $username',
            ),
          ),
      ],
    );
  }

  void _showKickConfirmDialog(String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant'),
        content: Text('Remove $username from the call?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _kickUser(username);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAdmitPrompt(String username, String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // Must choose Yes or No
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person_add, color: Colors.blue),
            const SizedBox(width: 8),
            Text('$username wants to join'),
          ],
        ),
        content: Text(message),
        actions: [
          // No button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          // Yes button
          ElevatedButton(
            onPressed: () {
              _admitUser(username);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Admit'),
          ),
        ],
      ),
    );
  }

  void _showWaitingUsersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Waiting to Join'),
        content: SizedBox(
          width: 300,
          child: _waitingUsers.isEmpty
              ? const Text('No one is waiting.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _waitingUsers.length,
                  itemBuilder: (context, index) {
                    final entry = _waitingUsers.entries.elementAt(index);
                    final user = entry.value;
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(user.username),
                      trailing: ElevatedButton(
                        onPressed: () {
                          _admitUser(user.username);
                          Navigator.pop(context);
                        },
                        child: const Text('Admit'),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleChatPanel() {
    setState(() {
      _isChatOpen = !_isChatOpen;
      if (_isChatOpen) _unreadMessages = 0;
    });
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
