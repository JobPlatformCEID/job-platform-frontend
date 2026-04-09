import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class CallRoomScreen extends StatefulWidget {
  final String token;
  final String url;
  final String roomName;
  final String displayName;
  final bool isHost;

  const CallRoomScreen({
    super.key,
    required this.token,
    required this.url,
    required this.roomName,
    required this.displayName,
    required this.isHost,
  });

  @override
  State<CallRoomScreen> createState() => _CallRoomScreenState();
}

class _CallRoomScreenState extends State<CallRoomScreen> {
  Room? _room;
  bool _isConnecting = true;
  String? _error;
  bool _isMicMuted = false;
  bool _isCamOff = false;
  List<Participant> _participants = [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final room = Room();
      await room.connect(widget.url, widget.token);

      // Enable camera and mic
      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);

      room.addListener(_onRoomUpdate);

      if (mounted) setState(() {
        _room = room;
        _isConnecting = false;
        _participants = _getParticipants(room);
      });
    } catch (e) {
      if (mounted) setState(() {
        _isConnecting = false;
        _error = 'Could not connect to room.';
      });
    }
  }

  void _onRoomUpdate() {
    if (mounted) setState(() {
      _participants = _getParticipants(_room!);
    });
  }

  List<Participant> _getParticipants(Room room) {
    return [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];
  }

  Future<void> _toggleMic() async {
    await _room?.localParticipant?.setMicrophoneEnabled(_isMicMuted);
    setState(() => _isMicMuted = !_isMicMuted);
  }

  Future<void> _toggleCam() async {
    await _room?.localParticipant?.setCameraEnabled(_isCamOff);
    setState(() => _isCamOff = !_isCamOff);
  }

  Future<void> _leave() async {
    await _room?.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.displayName),
      ),
      body: _isConnecting
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // Video grid
                    Expanded(
                      child: _participants.isEmpty
                          ? const Center(
                              child: Text(
                                'Waiting for participants...',
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _participants.length == 1 ? 1 : 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: _participants.length,
                              itemBuilder: (context, index) {
                                return _ParticipantTile(
                                  participant: _participants[index],
                                );
                              },
                            ),
                    ),

                    // Controls
                    Container(
                      color: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ControlButton(
                            icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                            label: _isMicMuted ? 'Unmute' : 'Mute',
                            onPressed: _toggleMic,
                          ),
                          _ControlButton(
                            icon: _isCamOff ? Icons.videocam_off : Icons.videocam,
                            label: _isCamOff ? 'Cam on' : 'Cam off',
                            onPressed: _toggleCam,
                          ),
                          _ControlButton(
                            icon: Icons.call_end,
                            label: 'Leave',
                            color: Colors.red,
                            onPressed: _leave,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    super.dispose();
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;

  const _ParticipantTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    final videoTrack = participant.videoTrackPublications
        .where((t) => t.track != null && !t.muted)
        .map((t) => t.track as VideoTrack)
        .firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Video or avatar
            if (videoTrack != null)
              VideoTrackRenderer(videoTrack)
            else
              Center(
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.grey[700],
                  child: Text(
                    (participant.name ?? '?')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
              ),

            // Name label
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  participant.name ?? participant.identity,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),

            // Mic muted indicator
            if (participant.isMicrophoneEnabled() == false)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mic_off, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color ?? Colors.grey[800],
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}