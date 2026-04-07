import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final String livekitUrl;   // e.g. wss://your-project.livekit.cloud
  final String livekitToken; // JWT from Django
  final String currentUsername;
  final bool isHost;
  final String? hostUsername;

  const VideoCallScreen({
    super.key,
    required this.roomId,
    required this.livekitUrl,
    required this.livekitToken,
    required this.currentUsername,
    this.isHost = false,
    this.hostUsername,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late Room _room;
  List<Participant> _participants = [];

  bool _isMuted    = false;
  bool _isVideoOff = false;
  bool _showChat   = false;

  final List<Map<String, String>> _messages = [];
  final TextEditingController _msgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    _room = Room();
    _room.addListener(_onRoomUpdate);

    try {
      await _room.connect(widget.livekitUrl, widget.livekitToken,
          roomOptions: const RoomOptions(
            adaptiveStream: true,
            dynacast: true,
          ));

      // Enable camera + mic
      await _room.localParticipant?.setCameraEnabled(true);
      await _room.localParticipant?.setMicrophoneEnabled(true);

      _refresh();
    } catch (e) {
      debugPrint('Error connecting to LiveKit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to video call: $e')),
        );
      }
    }
  }

  void _onRoomUpdate() => _refresh();

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _participants = [
        _room.localParticipant!,
        ..._room.remoteParticipants.values,
      ];
    });
  }

  Future<void> _toggleMute() async {
    final enabled = _isMuted; // currently muted → we want to enable
    await _room.localParticipant?.setMicrophoneEnabled(enabled);
    setState(() => _isMuted = !_isMuted);
  }

  Future<void> _toggleVideo() async {
    final enabled = _isVideoOff;
    await _room.localParticipant?.setCameraEnabled(enabled);
    setState(() => _isVideoOff = !_isVideoOff);
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _room.localParticipant?.publishData(
      text.codeUnits,
      reliable: true,
    );
    setState(() => _messages.add({'sender': widget.currentUsername, 'message': text}));
    _msgCtrl.clear();
  }

  Future<void> _endCall() async {
    await _room.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _room.removeListener(_onRoomUpdate);
    _room.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildGrid()),
            if (_showChat) _buildChatPanel(),
            _buildControlBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_participants.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 3 / 4,
      ),
      itemCount: _participants.length,
      itemBuilder: (_, i) => _buildTile(_participants[i]),
    );
  }

  Widget _buildTile(Participant participant) {
    final isLocal = participant is LocalParticipant;
    final label = participant.identity;

    // Get first video track
    VideoTrack? videoTrack;
    for (final pub in participant.videoTrackPublications) {
      if (!pub.muted && pub.track != null && pub.track is VideoTrack) {
        videoTrack = pub.track as VideoTrack;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[850], borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(fit: StackFit.expand, children: [
          videoTrack != null
              ? VideoTrackRenderer(videoTrack)
              : Center(child: CircleAvatar(
                  radius: 28, backgroundColor: Colors.blueAccent,
                  child: Text(label.isNotEmpty ? label[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                )),
          Positioned(bottom: 6, left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: Text(isLocal ? 'You' : label,
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            )),
        ]),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _CtrlBtn(icon: _isMuted ? Icons.mic_off : Icons.mic, label: _isMuted ? 'Unmute' : 'Mute', color: _isMuted ? Colors.red : Colors.white, onTap: _toggleMute),
        _CtrlBtn(icon: _isVideoOff ? Icons.videocam_off : Icons.videocam, label: _isVideoOff ? 'Start Video' : 'Stop Video', color: _isVideoOff ? Colors.red : Colors.white, onTap: _toggleVideo),
        _CtrlBtn(icon: Icons.chat_bubble_outline, label: 'Chat', color: _showChat ? Colors.blueAccent : Colors.white, onTap: () => setState(() => _showChat = !_showChat)),
        GestureDetector(
          onTap: _endCall,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.call_end, color: Colors.white, size: 26),
          ),
        ),
      ]),
    );
  }

Widget _buildChatPanel() {
  return Container(
    height: 200,
    color: Colors.grey[850],
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
    child: Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages yet.',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final m = _messages[i];
                    final isMe = m['sender'] == widget.currentUsername;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${m['sender']}: ',
                              style: TextStyle(
                                color: isMe ? Colors.lightBlueAccent : Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text: m['message'],
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: Colors.grey[700],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _sendMessage,
              child: const Icon(Icons.send, color: Colors.white, size: 22),
            ),
          ],
        ),
      ],
    ),
  );
}
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 26),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(color: color, fontSize: 9)),
    ]),
  );
}
