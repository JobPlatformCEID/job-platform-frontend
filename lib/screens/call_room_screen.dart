import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../calls.dart';

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
  bool _hasUnreadMessages = false;
  bool _userLeaving = false;
  List<Participant> _participants = [];
  final List<CallMessage> _messages = [];
  final List<Future<void> Function()> _unsubs = [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final room = Room();

      room.addListener(_onRoomUpdate);

      _unsubs.add(room.events.on<DataReceivedEvent>((e) => _onData(e)));
      _unsubs.add(room.events.on<RoomDisconnectedEvent>((e) {
        if (mounted && !_userLeaving) Navigator.of(context).pop();
      }));

      await room.connect(
        widget.url,
        widget.token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      // Enable camera and mic
      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);

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

  void _onData(DataReceivedEvent e) {
    try {
      final json = jsonDecode(utf8.decode(e.data)) as Map<String, dynamic>;
      final message = CallMessage(
        senderName: e.participant?.name ?? e.participant?.identity ?? 'Unknown',
        content: json['content'] as String,
        sentAt: DateTime.now(),
      );
      if (mounted) setState(() {
        _messages.add(message);
        _hasUnreadMessages = true;
      });
    } catch (_) {}
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

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    final bytes = utf8.encode(jsonEncode({'content': content.trim()}));
    await _room?.localParticipant?.publishData(bytes, reliable: true);
    if (mounted) setState(() {
      _messages.add(CallMessage(
        senderName: widget.displayName,
        content: content.trim(),
        sentAt: DateTime.now(),
      ));
    });
  }

  void _openChat() {
    setState(() => _hasUnreadMessages = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChatPanel(
        messages: _messages,
        displayName: widget.displayName,
        onSend: _sendMessage,
        room: _room!,
      ),
    );
  }

  Future<void> _leave() async {
    setState(() => _userLeaving = true);
    await _room?.disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildVideoGrid() {
    final count = _participants.length;

    if (count == 0) {
      return const Center(
        child: Text('Waiting for participants...', style: TextStyle(color: Colors.white)),
      );
    }

    // Layout for 1 participant
    if (count == 1) {
      return _ParticipantTile(participant: _participants[0]);
    }

    // Layout for 2 participants
    if (count == 2) {
      // On larger screens show side by side, on smaller stack vertically
      return LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 600;
          return isWide
              ? Row(
                  children: [
                    Expanded(child: _ParticipantTile(participant: _participants[0])),
                    const SizedBox(width: 8),
                    Expanded(child: _ParticipantTile(participant: _participants[1])),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: _ParticipantTile(participant: _participants[0])),
                    const SizedBox(height: 8),
                    Expanded(child: _ParticipantTile(participant: _participants[1])),
                  ],
                );
        },
      );
    }

    // Layout for 3 participants (grid)
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = count <= 4 ? 2 : 3;
        final rows = (count / crossAxisCount).ceil();

        return Column(
          children: List.generate(rows, (rowIndex) {
            final startIndex = rowIndex * crossAxisCount;
            final endIndex = (startIndex + crossAxisCount).clamp(0, count);
            final rowItems = _participants.sublist(startIndex, endIndex);

            return Expanded(
              child: Row(
                children: [
                  ...rowItems.map((p) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _ParticipantTile(participant: p),
                    ),
                  )),
                  // Fill empty slots in last row
                  if (rowItems.length < crossAxisCount)
                    ...List.generate(
                      crossAxisCount - rowItems.length,
                      (_) => const Expanded(child: SizedBox()),
                    ),
                ],
              ),
            );
          }),
        );
      },
    );
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
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _buildVideoGrid(),
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
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _ControlButton(
                                icon: Icons.chat_outlined,
                                label: 'Chat',
                                onPressed: _openChat,
                              ),
                              if (_hasUnreadMessages)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
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
    for (final cancel in _unsubs) { cancel(); }
    _unsubs.clear();
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    super.dispose();
  }
}

class _ChatPanel extends StatefulWidget {
  final List<CallMessage> messages;
  final String displayName;
  final Future<void> Function(String content) onSend;
  final Room room;

  const _ChatPanel({
    required this.messages,
    required this.displayName,
    required this.onSend,
    required this.room,
  });

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    widget.room.addListener(_onRoomUpdate);
  }

  void _onRoomUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    widget.room.removeListener(_onRoomUpdate);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    setState(() => _isSending = true);
    _controller.clear();
    await widget.onSend(content);
    setState(() => _isSending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  const Icon(Icons.chat_outlined, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'In-call chat',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: widget.messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet.',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.messages.length,
                      itemBuilder: (context, index) {
                        final message = widget.messages[index];
                        final isOwn = message.senderName == widget.displayName;
                        return Align(
                          alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: isOwn ? Colors.blue : Colors.grey[700],
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: isOwn ? const Radius.circular(12) : const Radius.circular(4),
                                bottomRight: isOwn ? const Radius.circular(4) : const Radius.circular(12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isOwn)
                                  Text(
                                    message.senderName,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                Text(
                                  message.content,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                Text(
                                  _formatTime(message.sentAt),
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(color: Colors.white24),
            Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isSending
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _handleSend,
                        ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ParticipantTile extends StatefulWidget {
  final Participant participant;

  const _ParticipantTile({required this.participant});

  @override
  State<_ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<_ParticipantTile> {
  late ConnectionQuality _quality;
  late final List<Future<void> Function()> _unsubs;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _quality = widget.participant.connectionQuality;
    _unsubs = [
      widget.participant.events.on<ParticipantConnectionQualityUpdatedEvent>((e) {
        if (mounted) setState(() => _quality = e.connectionQuality);
      }),
      widget.participant.events.on<SpeakingChangedEvent>((e) {
        if (mounted) setState(() => _isSpeaking = e.speaking);
      }),
    ];
  }

  @override
  void dispose() {
    for (final cancel in _unsubs) { cancel(); }
    super.dispose();
  }

  Widget _buildQualityIcon() {
    IconData icon;
    Color color;

    switch (_quality) {
      case ConnectionQuality.excellent:
        icon = Icons.signal_cellular_alt;
        color = Colors.green;
      case ConnectionQuality.good:
        icon = Icons.signal_cellular_alt_2_bar;
        color = Colors.orange;
      case ConnectionQuality.poor:
        icon = Icons.signal_cellular_alt_1_bar;
        color = Colors.red;
      case ConnectionQuality.lost:
        icon = Icons.signal_cellular_off;
        color = Colors.red;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoTrack = widget.participant.videoTrackPublications
        .where((t) => t.track != null && !t.muted)
        .map((t) => t.track as VideoTrack)
        .firstOrNull;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: _isSpeaking
            ? Border.all(color: Colors.green, width: 3)
            : null,
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
                    (widget.participant.name ?? '?')[0].toUpperCase(),
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
                  widget.participant.name ?? widget.participant.identity,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            if (widget.participant.isMicrophoneEnabled() == false)
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
            Positioned(
              top: 8,
              left: 8,
              child: _buildQualityIcon(),
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