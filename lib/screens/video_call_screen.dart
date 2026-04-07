import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// One remote participant
// ─────────────────────────────────────────────────────────────────────────────
class _Participant {
  final String username;
  final RTCVideoRenderer renderer;
  RTCPeerConnection? pc;
  bool hasVideo = false;
  bool isDisposed = false;
  _Participant({required this.username, required this.renderer});
}

// ─────────────────────────────────────────────────────────────────────────────
// VideoCallScreen
// ─────────────────────────────────────────────────────────────────────────────
class VideoCallScreen extends StatefulWidget {
  final String roomId;
  final String token;
  final String serverUrl;
  final String currentUsername;
  final bool isHost;
  final String? hostUsername;
  // FIX: Removed existingChannel - always create fresh connection
  final List<dynamic>? initialUsers;
  final List<dynamic>? initialWaiting;

  const VideoCallScreen({
    super.key,
    required this.roomId,
    required this.token,
    required this.serverUrl,
    required this.currentUsername,
    this.isHost = false,
    this.hostUsername,
    this.initialUsers,
    this.initialWaiting,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  // ── Local media ────────────────────────────────────────────────────────────
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _mediaReady  = false;
  bool _isMuted     = false;
  bool _isVideoOff  = false;
  bool _isSpeakerOn = true;

  // ── Participants & pin ─────────────────────────────────────────────────────
  final Map<String, _Participant> _participants = {};
  String? _pinnedUsername;
  final Map<String, List<Map<String, dynamic>>> _pendingIceCandidates = {};

  // FIX 1: Track recently admitted users to suppress duplicate PC creation
  final Set<String> _recentlyAdmitted = {};
  final Map<String, Timer> _admissionTimers = {};

  // ── Chat ───────────────────────────────────────────────────────────────────
  final TextEditingController _msgCtrl      = TextEditingController();
  final ScrollController _chatScroll        = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _showChat = false;

  // ── Waiting panel (host only) ──────────────────────────────────────────────
  bool _showWaitingPanel          = false;
  final Map<String, int> _waitingGuests = {};

  // ── WebSocket ──────────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;

  // ── WebRTC config ──────────────────────────────────────────────────────────
  static const Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };
  static const Map<String, dynamic> _offerConstraints = {
    'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
    'optional': [],
  };

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    debugPrint('[VideoCallScreen] initState called for ${widget.currentUsername}');

    if (!widget.isHost && widget.hostUsername != null) {
      _pinnedUsername = widget.hostUsername;
    }

    // Sync initial lists if provided by CallWaitingRoom
    if (widget.initialWaiting != null) {
      debugPrint('[VideoCallScreen] Initializing with waiting list: ${widget.initialWaiting}');
      _syncWaiting(widget.initialWaiting);
    }
    if (widget.initialUsers != null) {
      debugPrint('[VideoCallScreen] Initializing with active users: ${widget.initialUsers}');
      for (final u in widget.initialUsers!) {
        final name = u['username'] as String? ?? '';
        if (name.isNotEmpty && name != widget.currentUsername) {
          // FIX 1: Skip PC creation for recently admitted users to avoid duplicates
          if (_recentlyAdmitted.contains(name)) {
            debugPrint('[VideoCallScreen] Skipping PC creation for recently admitted $name');
            continue;
          }
          if (widget.currentUsername.compareTo(name) < 0) {
            _ensurePc(name);
          }
        }
      }
    }

    // FIX 2: Always create FRESH WebSocket connection (no channel passing)
    debugPrint('[VideoCallScreen] Creating fresh WebSocket connection');
    _openWebSocket();
    _listenWebSocket();

    // Start renderer init + camera in background
    _localRenderer.initialize().then((_) {
      debugPrint('[VideoCallScreen] Local renderer initialized, starting local media...');
      _startLocalMedia();
    });
  }

  @override
  void dispose() {
    debugPrint('[VideoCallScreen] Disposing resources...');
    
    _wsSubscription?.cancel();
    _channel?.sink.close();
    
    // Safe disposal with try/catch guards
    for (final p in _participants.values) {
      try { p.pc?.close(); } catch (e) { debugPrint('[VideoCallScreen] Error closing PC for ${p.username}: $e'); }
      try { if (!p.isDisposed) p.renderer.dispose(); } catch (e) { debugPrint('[VideoCallScreen] Error disposing renderer for ${p.username}: $e'); }
    }
    
    try { _localStream?.dispose(); } catch (e) { debugPrint('[VideoCallScreen] Error disposing local stream: $e'); }
    try { _localRenderer.dispose(); } catch (e) { debugPrint('[VideoCallScreen] Error disposing local renderer: $e'); }
    
    _msgCtrl.dispose();
    _chatScroll.dispose();
    
    // Cancel all admission timers
    for (final timer in _admissionTimers.values) { timer.cancel(); }
    _admissionTimers.clear();
    
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Local media
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _startLocalMedia() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user', 'width': 1280, 'height': 720},
      });
      if (!mounted) { stream.dispose(); return; }
      _localStream = stream;
      _localRenderer.srcObject = stream;
      debugPrint('[VideoCallScreen] Local media secured.');

      // Add tracks to any peer connections already created
      for (final p in _participants.values) {
        if (p.pc != null && !p.isDisposed) {
          debugPrint('[VideoCallScreen] Adding tracks to existing PC for ${p.username}');
          for (final t in stream.getTracks()) {
            try { if (!p.isDisposed) await p.pc!.addTrack(t, stream); } catch (e) { debugPrint('[VideoCallScreen] Error adding track: $e'); }
          }
          debugPrint('[VideoCallScreen] Sending renegotiation offer to ${p.username}');
          await _sendOffer(p.username);
        }
      }

      if (mounted) setState(() => _mediaReady = true);
      if (widget.isHost) {
        debugPrint('[VideoCallScreen] Host announcing call_started');
        _send({'type': 'call_started'});
      }
    } catch (e) {
      debugPrint('[VideoCallScreen] getUserMedia error: $e');
      if (mounted) setState(() => _mediaReady = true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WebSocket
  // ─────────────────────────────────────────────────────────────────────────
  void _openWebSocket() {
    final wsUrl = widget.serverUrl
            .replaceFirst('http://', 'ws://')
            .replaceFirst('https://', 'wss://') +
        '/ws/calls/${widget.roomId}/?token=${widget.token}';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    debugPrint('[VideoCallScreen] WebSocket connected: $wsUrl');
  }

  void _listenWebSocket() {
    debugPrint('[VideoCallScreen] Listening to WebSocket stream');
    _wsSubscription?.cancel();
    if (_channel != null) {
      _wsSubscription = _channel!.stream.listen(
        (raw) => Future.microtask(() => _handleWsMessage(jsonDecode(raw as String) as Map<String, dynamic>)),
        onError: (e) => debugPrint('[VideoCallScreen] WS error: $e'),
        onDone: _onWsClosed,
      );
    }
  }

  void _send(Map<String, dynamic> data) {
    debugPrint('[VideoCallScreen] Sending WS message: ${data['type']}');
    _channel?.sink.add(jsonEncode(data));
  }

  void _onWsClosed() {
    debugPrint('[VideoCallScreen] WS Connection Closed');
    if (!mounted || widget.isHost) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('You have been removed from the call.'),
      backgroundColor: Colors.red,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WebSocket message dispatch
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleWsMessage(Map<String, dynamic> msg) async {
    final type = msg['type'] as String?;
    debugPrint('[VideoCallScreen] Handling WS message of type: $type');

    switch (type) {
      case 'room_status':
        _syncWaiting(msg['waiting_users']);
        final active = msg['users'] as List? ?? [];
        for (final u in active) {
          final name = u['username'] as String? ?? '';
          if (name.isNotEmpty && name != widget.currentUsername) {
            if (_recentlyAdmitted.contains(name)) {
              debugPrint('[VideoCallScreen] Skipping PC creation for recently admitted $name');
              continue;
            }
            if (widget.currentUsername.compareTo(name) < 0) {
              await _ensurePc(name);
            }
          }
        }
        break;

      case 'user_joined':
        _syncWaiting(msg['waiting_users']);
        final joiner = msg['username'] as String?;
        if (joiner == null || joiner == widget.currentUsername) break;
        
        // FIX 1: Skip if this user was recently admitted
        if (_recentlyAdmitted.contains(joiner)) {
          debugPrint('[VideoCallScreen] Skipping duplicate PC creation for recently admitted $joiner');
          return;
        }
        
        if (!_waitingGuests.containsKey(joiner)) {
          if (widget.currentUsername.compareTo(joiner) < 0) {
            debugPrint('[VideoCallScreen] Initiating offer to newly joined active user $joiner');
            await _ensurePc(joiner);
            await _sendOffer(joiner);
          } else {
            debugPrint('[VideoCallScreen] Preparing PC for newly joined active user $joiner');
            await _ensurePc(joiner);
          }
        }
        break;

      case 'user_left':
        _syncWaiting(msg['waiting_users']);
        final leaver = msg['username'] as String?;
        debugPrint('[VideoCallScreen] user_left: leaver=$leaver, currentUsername=${widget.currentUsername}');
        if (leaver != null && leaver != widget.currentUsername) {
          _removeParticipant(leaver);
        }
        break;

      case 'user_admitted':
        _syncWaiting(msg['waiting_users']);
        final admitted = msg['username'] as String?;
        final initiator = msg['initiator'] as String?;
        
        if (admitted != null) {
          // FIX 1: Mark as recently admitted to suppress duplicate handling
          _recentlyAdmitted.add(admitted);
          _admissionTimers[admitted]?.cancel();
          _admissionTimers[admitted] = Timer(const Duration(seconds: 5), () {
            _recentlyAdmitted.remove(admitted);
            _admissionTimers.remove(admitted);
            debugPrint('[VideoCallScreen] Removed $admitted from recently admitted set');
          });
          
          // FIX 2: Use server's initiator field (server-authoritative)
          if (admitted == widget.currentUsername) {
             debugPrint('[VideoCallScreen] I was admitted! Setting up PCs for active users.');
             final active = msg['users'] as List? ?? [];
             for (final u in active) {
               final name = u['username'] as String? ?? '';
               if (name.isNotEmpty && name != widget.currentUsername) {
                 if (initiator == widget.currentUsername) {
                   debugPrint('[VideoCallScreen] I am initiator, creating PC and sending offer to $name');
                   await _ensurePc(name);
                   await _sendOffer(name);
                 } else {
                   debugPrint('[VideoCallScreen] Not initiator, only creating PC for $name (will receive offer)');
                   await _ensurePc(name);
                 }
               }
             }
          } else {
            if (_participants.containsKey(admitted)) {
              debugPrint('[VideoCallScreen] Dropping stale PC for admitted guest $admitted');
              _removeParticipant(admitted);
            }
            if (initiator == widget.currentUsername) {
              debugPrint('[VideoCallScreen] Server designated me as initiator, creating PC and sending offer to $admitted');
              await _ensurePc(admitted);
              await _sendOffer(admitted);
            } else {
              debugPrint('[VideoCallScreen] Guest creating PC for $admitted and waiting for offer');
              await _ensurePc(admitted);
            }
          }
        }
        break;

      case 'offer':
        await _handleOffer(msg['sender'] as String, msg['offer'] as Map<String, dynamic>);
        break;

      case 'answer':
        await _handleAnswer(msg['sender'] as String, msg['answer'] as Map<String, dynamic>);
        break;

      case 'ice_candidate':
        await _handleIce(msg['sender'] as String, msg['candidate'] as Map<String, dynamic>);
        break;

      case 'message':
        _addChat(msg['sender'] as String? ?? 'Unknown', msg['message'] as String? ?? '');
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Waiting list sync
  // ─────────────────────────────────────────────────────────────────────────
  void _syncWaiting(dynamic waitingUsers) {
    final updated = <String, int>{};
    if (waitingUsers is List) {
      for (final u in waitingUsers) {
        if (u is Map) {
          final name = u['username'] as String? ?? '';
          final id   = u['id'] as int?;
          if (name.isNotEmpty && id != null) updated[name] = id;
        }
      }
    }
    if (mounted) setState(() { _waitingGuests..clear()..addAll(updated); });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Peer connection helpers
  // ─────────────────────────────────────────────────────────────────────────
  Future<RTCPeerConnection> _ensurePc(String username) async {
    if (_participants[username]?.pc != null) {
      return _participants[username]!.pc!;
    }

    debugPrint('[VideoCallScreen] Creating new PeerConnection for $username');
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    final participant = _Participant(username: username, renderer: renderer);
    _participants[username] = participant;

    final pc = await createPeerConnection(_iceServers);
    participant.pc = pc;

    // Add tracks immediately if local stream is ready
    if (_localStream != null) {
      debugPrint('[VideoCallScreen] Local stream ready, adding tracks to PC for $username');
      if (_participants.containsKey(username) && !participant.isDisposed) {
        for (final track in _localStream!.getTracks()) {
          try { if (!participant.isDisposed) await pc.addTrack(track, _localStream!); } catch (e) { debugPrint('[VideoCallScreen] Error adding track: $e'); }
        }
      }
    } else {
      debugPrint('[VideoCallScreen] Local stream NOT ready yet for $username. Tracks will be added when stream is ready.');
    }

    debugPrint('[VideoCallScreen] PeerConnection created for $username');

    pc.onTrack = (event) {
      debugPrint('[VideoCallScreen] onTrack triggered for $username. Streams: ${event.streams.length}');
      if (event.streams.isNotEmpty && mounted && !participant.isDisposed) {
        if (_participants.containsKey(username)) {
          setState(() {
            renderer.srcObject = event.streams[0];
            participant.hasVideo = true;
          });
        }
      }
    };

    pc.onIceCandidate = (c) {
      if (c.candidate != null) {
        debugPrint('[VideoCallScreen] ICE candidate generated for $username');
        _send({'type': 'ice_candidate', 'target': username, 'candidate': c.toMap()});
      }
    };

    pc.onConnectionState = (state) {
      debugPrint('[VideoCallScreen] PC state for $username changed to $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        debugPrint('[VideoCallScreen] Removing participant $username due to connection state $state');
        if (mounted) _removeParticipant(username);
      }
    };

    if (mounted) setState(() {});
    return pc;
  }

  void _removeParticipant(String username) {
    debugPrint('[VideoCallScreen] Removing participant $username');
    final p = _participants[username];
    if (p == null) {
      debugPrint('[VideoCallScreen] Participant $username already removed, skipping');
      return;
    }
    if (p.isDisposed) {
      debugPrint('[VideoCallScreen] Participant $username already disposed, skipping');
      _participants.remove(username);
      return;
    }
    _participants.remove(username);
    p.isDisposed = true;
    
    try { p.pc?.close(); } catch (e) { debugPrint('[VideoCallScreen] Error closing PC for $username: $e'); }
    try { p.renderer.dispose(); } catch (e) { debugPrint('[VideoCallScreen] Error disposing renderer for $username: $e'); }
    
    _pendingIceCandidates.remove(username);
    if (_pinnedUsername == username) {
      setState(() => _pinnedUsername = null);
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sendOffer(String target) async {
    debugPrint('[VideoCallScreen] Creating and sending offer to $target');
    final participant = _participants[target];
    if (participant == null || participant.isDisposed) {
      debugPrint('[VideoCallScreen] Participant $target does not exist or is disposed, cannot send offer');
      return;
    }
    final pc = participant.pc;
    if (pc == null) return;
    if (participant.isDisposed) return;
    
    final offer = await pc.createOffer(_offerConstraints);
    if (participant.isDisposed) return;
    await pc.setLocalDescription(offer);
    _send({'type': 'offer', 'target': target, 'offer': offer.toMap()});
  }

  Future<void> _handleOffer(String sender, Map<String, dynamic> offerMap) async {
    debugPrint('[VideoCallScreen] Received offer from $sender');
    final participant = _participants[sender];
    if (participant == null || participant.isDisposed) {
      debugPrint('[VideoCallScreen] Participant $sender does not exist or is disposed, ignoring offer');
      return;
    }
    
    final existingPc = participant.pc;
    if (existingPc != null) {
      RTCSessionDescription? localDesc;
      try { localDesc = await existingPc.getLocalDescription(); } catch (_) { localDesc = null; }
      if (localDesc != null && localDesc.type == 'offer') {
        debugPrint('[VideoCallScreen] PC in wrong state (have-local-offer), removing and recreating');
        _removeParticipant(sender);
        return;
      }
    }
    
    final pc = await _ensurePc(sender);
    if (_participants[sender]?.isDisposed ?? true) {
      debugPrint('[VideoCallScreen] Participant $sender was disposed during offer handling, aborting');
      return;
    }
    
    await pc.setRemoteDescription(RTCSessionDescription(offerMap['sdp'] as String, offerMap['type'] as String));
    
    // Process queued ICE candidates
    final pending = _pendingIceCandidates.remove(sender);
    if (pending != null && pending.isNotEmpty) {
      debugPrint('[VideoCallScreen] Processing ${pending.length} queued ICE candidates for $sender');
      for (final candidate in pending) {
        try {
          await pc.addCandidate(RTCIceCandidate(candidate['candidate'] as String?, candidate['sdpMid'] as String?, candidate['sdpMLineIndex'] as int?));
        } catch (e) { debugPrint('[VideoCallScreen] Error adding queued ICE candidate: $e'); }
      }
    }
    
    // Add local tracks before answering
    if (_localStream != null) {
      debugPrint('[VideoCallScreen] Adding local tracks to PC for $sender before answering');
      for (final track in _localStream!.getTracks()) {
        try { await pc.addTrack(track, _localStream!); } catch (e) { debugPrint('[VideoCallScreen] Error adding track: $e'); }
      }
    }
    
    final answer = await pc.createAnswer(_offerConstraints);
    await pc.setLocalDescription(answer);
    debugPrint('[VideoCallScreen] Sending answer to $sender');
    _send({'type': 'answer', 'target': sender, 'answer': answer.toMap()});
  }

  Future<void> _handleAnswer(String sender, Map<String, dynamic> answerMap) async {
    debugPrint('[VideoCallScreen] Received answer from $sender');
    final participant = _participants[sender];
    if (participant == null || participant.isDisposed) {
      debugPrint('[VideoCallScreen] Participant $sender does not exist or is disposed, ignoring answer');
      return;
    }
    final pc = participant.pc;
    if (pc == null) return;
    if (participant.isDisposed) return;
    
    await pc.setRemoteDescription(RTCSessionDescription(answerMap['sdp'] as String, answerMap['type'] as String));
    
    // Process queued ICE candidates after answer
    final pending = _pendingIceCandidates.remove(sender);
    if (pending != null && pending.isNotEmpty) {
      debugPrint('[VideoCallScreen] Processing ${pending.length} queued ICE candidates for $sender after answer');
      for (final candidate in pending) {
        try {
          await pc.addCandidate(RTCIceCandidate(candidate['candidate'] as String?, candidate['sdpMid'] as String?, candidate['sdpMLineIndex'] as int?));
        } catch (e) { debugPrint('[VideoCallScreen] Error adding queued ICE candidate after answer: $e'); }
      }
    }
  }

  Future<void> _handleIce(String sender, Map<String, dynamic> map) async {
    debugPrint('[VideoCallScreen] Received ICE candidate from $sender');
    final pc = _participants[sender]?.pc;
    if (pc == null) {
      debugPrint('[VideoCallScreen] No PC found for $sender, ignoring ICE candidate');
      return;
    }
    
    // Check if remote description is set (with try/catch for flutter_webrtc quirk)
    RTCSessionDescription? remoteDesc;
    try { remoteDesc = await pc.getRemoteDescription(); } catch (e) { remoteDesc = null; }
    
    if (remoteDesc == null) {
      final queueLength = _pendingIceCandidates[sender]?.length ?? 0;
      if (queueLength >= 20) {
        debugPrint('[VideoCallScreen] Dropping ICE candidate for $sender (queue full: $queueLength)');
        return;
      }
      debugPrint('[VideoCallScreen] Remote description not set yet, queuing ICE candidate for $sender');
      _pendingIceCandidates.putIfAbsent(sender, () => []).add(map);
      return;
    }
    
    try {
      await pc.addCandidate(RTCIceCandidate(map['candidate'] as String?, map['sdpMid'] as String?, map['sdpMLineIndex'] as int?));
      debugPrint('[VideoCallScreen] ICE candidate added for $sender');
    } catch (e) {
      debugPrint('[VideoCallScreen] Error adding ICE candidate for $sender: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Controls
  // ─────────────────────────────────────────────────────────────────────────
  void _toggleMute() { _localStream?.getAudioTracks().forEach((t) => t.enabled = _isMuted); setState(() => _isMuted = !_isMuted); }
  void _toggleVideo() { _localStream?.getVideoTracks().forEach((t) => t.enabled = _isVideoOff); setState(() => _isVideoOff = !_isVideoOff); }
  void _toggleSpeaker() { setState(() => _isSpeakerOn = !_isSpeakerOn); try { Helper.setSpeakerphoneOn(_isSpeakerOn); } catch (_) {} }
  void _endCall() => Navigator.of(context).pop();

  void _acceptGuest(String username) {
    debugPrint('[VideoCallScreen] Host accepting guest $username');
    _send({'type': 'admit_guest', 'username': username});
    setState(() => _waitingGuests.remove(username));
  }

  void _rejectGuest(String username) {
    final id = _waitingGuests[username];
    if (id != null) _send({'type': 'kick', 'user_id': id});
    setState(() => _waitingGuests.remove(username));
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _send({'type': 'message', 'message': text});
    _msgCtrl.clear();
  }

  void _addChat(String sender, String content) {
    setState(() => _messages.add({'sender': sender, 'message': content}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(_chatScroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pin helpers
  // ─────────────────────────────────────────────────────────────────────────
  RTCVideoRenderer get _pinnedRenderer => _pinnedUsername == null ? _localRenderer : (_participants[_pinnedUsername!]?.renderer ?? _localRenderer);
  bool get _pinnedIsLocal => _pinnedUsername == null;
  String get _pinnedLabel => _pinnedUsername == null ? '${widget.currentUsername} (you)' : _pinnedUsername!;
  bool get _pinnedHasVideo => _pinnedIsLocal ? (_mediaReady && !_isVideoOff) : (_participants[_pinnedUsername!]?.hasVideo ?? false);

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final allTiles = <_TileData>[
      (label: '${widget.currentUsername} (you)', renderer: _localRenderer, isLocal: true, hasVideo: _mediaReady && !_isVideoOff, pinKey: null),
      ..._participants.values.map((p) => (label: p.username, renderer: p.renderer, isLocal: false, hasVideo: p.hasVideo, pinKey: p.username)),
    ];
    final guestList = _waitingGuests.keys.toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(children: [
              _ThumbnailStrip(tiles: allTiles, pinnedKey: _pinnedUsername, onPin: (key) => setState(() => _pinnedUsername = key)),
              Expanded(child: _buildMainView()),
              if (_showChat) _buildChatPanel(),
              _buildControlBar(guestList),
            ]),
            if (widget.isHost && _showWaitingPanel) _buildWaitingPanel(guestList),
            if (!_mediaReady)
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: const Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 16), Text('Starting camera...', style: TextStyle(color: Colors.white70, fontSize: 15))],
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return Container(
      color: Colors.grey[900],
      child: Stack(fit: StackFit.expand, children: [
        _pinnedHasVideo
            ? RTCVideoView(_pinnedRenderer, mirror: _pinnedIsLocal, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircleAvatar(radius: 52, backgroundColor: Colors.blueAccent, child: Text(_pinnedLabel.isNotEmpty ? _pinnedLabel[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold))),
                const SizedBox(height: 14), Text(_pinnedLabel, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 6), const Text('Camera off', style: TextStyle(color: Colors.white38, fontSize: 13)),
              ])),
        Positioned(bottom: 14, left: 14, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)), child: Text(_pinnedLabel, style: const TextStyle(color: Colors.white, fontSize: 14)))),
        Positioned(top: 10, right: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)), child: const Text('Double-tap thumbnail to pin', style: TextStyle(color: Colors.white38, fontSize: 10)))),
      ]),
    );
  }

  Widget _buildChatPanel() {
    return Container(
      height: 200, color: Colors.grey[850], padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Column(children: [
        Expanded(
          child: _messages.isEmpty ? const Center(child: Text('No messages yet.', style: TextStyle(color: Colors.white38, fontSize: 13))) : ListView.builder(
              controller: _chatScroll, itemCount: _messages.length, itemBuilder: (_, i) {
                final m = _messages[i]; final sender = m['sender']!; final isMe = sender == widget.currentUsername;
                return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: RichText(text: TextSpan(children: [
                  TextSpan(text: '$sender: ', style: TextStyle(color: isMe ? Colors.lightBlueAccent : Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  TextSpan(text: m['message'], style: const TextStyle(color: Colors.white, fontSize: 12)),
                ])));
              }),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextField(controller: _msgCtrl, onSubmitted: (_) => _sendMessage(), style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: 'Type a message...', hintStyle: const TextStyle(color: Colors.white38, fontSize: 13), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), filled: true, fillColor: Colors.grey[700], border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
          const SizedBox(width: 6), GestureDetector(onTap: _sendMessage, child: const Icon(Icons.send, color: Colors.white, size: 22)),
        ]),
      ]),
    );
  }

  Widget _buildControlBar(List<String> guestList) {
    return Container(
      color: Colors.grey[900], padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _CtrlBtn(icon: _isMuted ? Icons.mic_off : Icons.mic, label: _isMuted ? 'Unmute' : 'Mute', color: _isMuted ? Colors.red : Colors.white, onTap: _toggleMute),
        _CtrlBtn(icon: _isVideoOff ? Icons.videocam_off : Icons.videocam, label: _isVideoOff ? 'Start Video' : 'Stop Video', color: _isVideoOff ? Colors.red : Colors.white, onTap: _toggleVideo),
        _CtrlBtn(icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off, label: 'Speaker', color: _isSpeakerOn ? Colors.white : Colors.grey, onTap: _toggleSpeaker),
        _CtrlBtn(icon: Icons.chat_bubble_outline, label: 'Chat', color: _showChat ? Colors.blueAccent : Colors.white, onTap: () => setState(() => _showChat = !_showChat), badge: (!_showChat && _messages.isNotEmpty) ? '${_messages.length}' : null),
        if (widget.isHost) _CtrlBtn(icon: Icons.people, label: 'Waiting', color: _showWaitingPanel ? Colors.orange : Colors.white, onTap: () => setState(() => _showWaitingPanel = !_showWaitingPanel), badge: guestList.isNotEmpty ? '${guestList.length}' : null),
        GestureDetector(onTap: _endCall, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.call_end, color: Colors.white, size: 26))),
      ]),
    );
  }

  Widget _buildWaitingPanel(List<String> guestList) {
    return Positioned(
      bottom: 80, right: 12, width: 240,
      child: Material(color: Colors.transparent, child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[700]!), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [
            const Icon(Icons.hourglass_top, color: Colors.orange, size: 16), const SizedBox(width: 6),
            Text('Waiting (${guestList.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(), GestureDetector(onTap: () => setState(() => _showWaitingPanel = false), child: const Icon(Icons.close, color: Colors.white54, size: 16)),
          ])),
          const Divider(color: Colors.grey, height: 1),
          if (guestList.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No one waiting', style: TextStyle(color: Colors.white54, fontSize: 13)))
          else Flexible(child: ListView.separated(shrinkWrap: true, padding: const EdgeInsets.all(8), itemCount: guestList.length, separatorBuilder: (_, __) => const SizedBox(height: 6), itemBuilder: (_, i) {
            final u = guestList[i];
            return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)), child: Row(children: [
              CircleAvatar(radius: 16, backgroundColor: Colors.blueAccent, child: Text(u[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              const SizedBox(width: 8), Expanded(child: Text(u, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
              GestureDetector(onTap: () => _acceptGuest(u), child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.check, color: Colors.white, size: 13))),
              const SizedBox(width: 4), GestureDetector(onTap: () => _rejectGuest(u), child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.close, color: Colors.white, size: 13))),
            ]));
          })),
        ]),
      )),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thumbnail strip
// ─────────────────────────────────────────────────────────────────────────────
typedef _TileData = ({String label, RTCVideoRenderer renderer, bool isLocal, bool hasVideo, String? pinKey});

class _ThumbnailStrip extends StatelessWidget {
  final List<_TileData> tiles; final String? pinnedKey; final void Function(String? key) onPin;
  const _ThumbnailStrip({required this.tiles, required this.pinnedKey, required this.onPin});

  @override
  Widget build(BuildContext context) {
    return Container(height: 108, color: Colors.black, child: ListView.separated(
      scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), itemCount: tiles.length, separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (_, i) {
        final t = tiles[i]; final isPinned = pinnedKey == t.pinKey;
        return SizedBox(width: 82, child: GestureDetector(onDoubleTap: () => onPin(t.pinKey), child: Container(
          decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(8), border: isPinned ? Border.all(color: Colors.blueAccent, width: 2) : Border.all(color: Colors.grey[800]!, width: 1)),
          child: ClipRRect(borderRadius: BorderRadius.circular(7), child: Stack(fit: StackFit.expand, children: [
            t.hasVideo ? RTCVideoView(t.renderer, mirror: t.isLocal, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover) : Center(child: CircleAvatar(radius: 20, backgroundColor: Colors.blueAccent, child: Text(t.label.isNotEmpty ? t.label[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)))),
            Positioned(bottom: 0, left: 0, right: 0, child: Container(color: Colors.black54, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: Text(t.label, style: const TextStyle(color: Colors.white, fontSize: 9), overflow: TextOverflow.ellipsis, maxLines: 1, textAlign: TextAlign.center))),
            if (isPinned) const Positioned(top: 3, right: 3, child: Icon(Icons.push_pin, color: Colors.blueAccent, size: 12)),
          ])),
        )));
      },
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Control button
// ─────────────────────────────────────────────────────────────────────────────
class _CtrlBtn extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap; final String? badge;
  const _CtrlBtn({required this.icon, required this.label, required this.color, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Stack(clipBehavior: Clip.none, children: [Icon(icon, color: color, size: 26), if (badge != null) Positioned(top: -4, right: -8, child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 9))))]),
      const SizedBox(height: 3), Text(label, style: TextStyle(color: color, fontSize: 9)),
    ]));
  }
}