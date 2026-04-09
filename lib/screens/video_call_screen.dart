// Video call screen using LiveKit
// Handles camera, mic, participant grid, and chat

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart' hide connectionState;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';

class VideoCallScreen extends StatefulWidget {
  final String livekitUrl;
  final String livekitToken;
  final String roomName;
  final bool isHost;

  const VideoCallScreen({
    super.key,
    required this.livekitUrl,
    required this.livekitToken,
    required this.roomName,
    required this.isHost,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  Room? _room;
  bool _connecting = true;
  String? _error;

  List<Participant> _participants = [];

  bool _micOn    = true;
  bool _cameraOn = true;
  bool _chatOpen = false;
  bool _userLeaving = false;

  final List<_Msg> _messages = [];
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  int _unread = 0;

  // cancel callbacks returned by room.events.on<T>()
  final List<Future<void> Function()> _unsubs = [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    for (final cancel in _unsubs) { cancel(); }
    _unsubs.clear();
    _room?.disconnect();  // safe to call regardless of state
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Join the call
  Future<void> _connect() async {
    try {
      final room = Room();

      // Listen to participant changes
      room.addListener(_onRoomChanged);

      // Listen to incoming data (chat)
      _unsubs.add(room.events.on<DataReceivedEvent>((e) => _onData(e)));

      // Listen for being disconnected / kicked
      _unsubs.add(room.events.on<RoomDisconnectedEvent>((e) {
        if (mounted && !_userLeaving) Navigator.of(context).pop();
      }));

      await room.connect(
        widget.livekitUrl,
        widget.livekitToken,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      // Enable camera and mic right away
      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);

      if (mounted) {
        setState(() {
          _room       = room;
          _connecting = false;
          _participants = room.remoteParticipants.values.toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error      = 'Could not connect: $e';
        });
      }
    }
  }

  void _onRoomChanged() {
    if (_room == null || !mounted) return;
    setState(() {
      _participants = _room!.remoteParticipants.values.toList();
    });
  }

  // Handle incoming chat messages
  void _onData(DataReceivedEvent e) {
    try {
      final map  = jsonDecode(utf8.decode(e.data)) as Map<String, dynamic>;
      final type = map['type'] as String?;
      if (type == 'chat') {
        _addMsg(_Msg(
          sender:  e.participant?.identity ?? 'Guest',
          content: map['message'] as String? ?? '',
        ));
      }
    } catch (_) {}
  }

  void _addMsg(_Msg msg) {
    setState(() {
      _messages.add(msg);
      if (!_chatOpen) _unread++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  void _sendMsg() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _chatCtrl.clear();

    _room?.localParticipant?.publishData(
      utf8.encode(jsonEncode({'type': 'chat', 'message': text})),
      reliable: true,
    );

    _addMsg(_Msg(
      sender:  _room?.localParticipant?.identity ?? 'You',
      content: text,
      isMe:    true,
    ));
  }

  // Mute/unmute toggle
  Future<void> _toggleMic() async {
    final next = !_micOn;
    await _room?.localParticipant?.setMicrophoneEnabled(next);
    setState(() => _micOn = next);
  }

  Future<void> _toggleCamera() async {
    final next = !_cameraOn;
    await _room?.localParticipant?.setCameraEnabled(next);
    setState(() => _cameraOn = next);
  }

  Future<void> _leave() async {
    setState(() => _userLeaving = true);
    await _room?.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Connecting…', style: TextStyle(color: Colors.white70)),
          ]),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go back')),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(widget.roomName),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.red),
            onPressed: _leave,
          ),
        ],
      ),
      body: Column(children: [
        // Video grid
        Expanded(child: _buildGrid()),

        // Chat panel
        if (_chatOpen) _buildChat(),

        // Control bar
        _buildControls(),
      ]),
    );
  }

  // Build the video grid layout
  Widget _buildGrid() {
    final local = _room?.localParticipant;
    final all   = <Participant>[
      if (local != null) local,
      ..._participants,
    ];

    if (all.isEmpty) {
      return const Center(
        child: Text('No one else here yet',
            style: TextStyle(color: Colors.white54)),
      );
    }

    if (all.length == 1) {
      return _tile(all.first, fill: true);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: all.length <= 2 ? 1 : 2,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: all.length,
      itemBuilder: (_, i) => _tile(all[i]),
    );
  }

  Widget _tile(Participant p, {bool fill = false}) {
    final isLocal = p is LocalParticipant;

    // Find the first enabled video track
    VideoTrack? video;
    for (final pub in p.videoTrackPublications) {
      if (!pub.muted && pub.track != null) {
        video = pub.track as VideoTrack?;
        break;
      }
    }

    return Stack(fit: fill ? StackFit.expand : StackFit.passthrough, children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: video != null
              ? VideoTrackRenderer(video, fit: VideoViewFit.cover)
              : Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[700],
                      child: Text(
                        (p.identity.isNotEmpty ? p.identity[0] : '?').toUpperCase(),
                        style: const TextStyle(fontSize: 24, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(p.identity,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
                ),
        ),
      ),
      // Name badge
      Positioned(
        left: 8, bottom: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isLocal ? '${p.identity} (You)' : p.identity,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
    ]);
  }

  // Build the chat panel UI
  Widget _buildChat() {
    final myId = _room?.localParticipant?.identity ?? '';
    return Container(
      height: 220,
      color: Colors.grey[900],
      child: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(8),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final m   = _messages[i];
              final me  = m.isMe || m.sender == myId;
              return Align(
                alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: me ? Colors.blue[700] : Colors.grey[700],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!me)
                      Text(m.sender,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(m.content, style: const TextStyle(color: Colors.white)),
                  ]),
                ),
              );
            },
          ),
        ),
        Container(
          color: Colors.grey[850],
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _chatCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMsg(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              onPressed: _sendMsg,
            ),
          ]),
        ),
      ]),
    );
  }

  // Build bottom controls (mic, camera, hang up, chat)
  Widget _buildControls() {
    return Container(
      height: 72,
      color: Colors.black87,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        // Mic
        _controlBtn(
          icon: _micOn ? Icons.mic : Icons.mic_off,
          color: _micOn ? Colors.white : Colors.red,
          onTap: _toggleMic,
          label: _micOn ? 'Mute' : 'Unmute',
        ),
        // Camera
        _controlBtn(
          icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
          color: _cameraOn ? Colors.white : Colors.red,
          onTap: _toggleCamera,
          label: _cameraOn ? 'Stop video' : 'Start video',
        ),
        // End call
        _controlBtn(
          icon: Icons.call_end,
          color: Colors.red,
          onTap: _leave,
          label: 'Leave',
          bg: Colors.red.withOpacity(0.15),
        ),
        // Chat
        Stack(alignment: Alignment.topRight, children: [
          _controlBtn(
            icon: Icons.chat_bubble_outline,
            color: _chatOpen ? Colors.blue : Colors.white,
            onTap: () => setState(() {
              _chatOpen = !_chatOpen;
              if (_chatOpen) _unread = 0;
            }),
            label: 'Chat',
          ),
          if (_unread > 0)
            Positioned(
              right: 4, top: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text('$_unread',
                    style: const TextStyle(color: Colors.white, fontSize: 9)),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
    Color? bg,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bg ?? Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
        ]),
      ),
    );
  }
}

// Simple message model for chat
class _Msg {
  final String sender;
  final String content;
  final bool isMe;
  _Msg({required this.sender, required this.content, this.isMe = false});
}