import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/signaling_service.dart';
import '../services/call_manager_service.dart';

class CallScreen extends StatefulWidget {
  final String roomId;
  final String currentUsername;
  final String serverHost;

  const CallScreen({
    super.key,
    required this.roomId,
    required this.currentUsername,
    required this.serverHost,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late SignalingService _signaling;
  late CallManager _callManager;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  List<String> _users = [];
  bool _isMuted = false;
  bool _isCameraOff = false;

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  Future<void> _initCall() async {
    // Ask for permissions
    await [Permission.camera, Permission.microphone].request();

    // Set up signaling
    _signaling = SignalingService(currentUsername: widget.currentUsername);

    // Set up call manager
    _callManager = CallManager(
      signaling: _signaling,
      currentUsername: widget.currentUsername,
    );

    // Rebuild UI when remote streams change
    _callManager.onStreamsChanged = () => setState(() {});

    // When user list updates, call any new users
    _signaling.onUserListChanged = (users) {
      setState(() => _users = List<String>.from(
        users.map((u) => u['username']),
      ));

      // Call every user in the room who isn't you
      for (final user in users) {
        final username = user['username'] as String;
        if (username != widget.currentUsername &&
            !_callManager.isConnectedTo(username)) {
          _callManager.callUser(username);
        }
      }
    };

    // Start local camera
    await _localRenderer.initialize();
    final stream = await _callManager.startLocalStream();
    _localRenderer.srcObject = stream;

    // Connect to Django signaling server
    _signaling.connect(widget.roomId, widget.serverHost);

    setState(() {});
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _callManager.localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
  }

  void _toggleCamera() {
    setState(() => _isCameraOff = !_isCameraOff);
    _callManager.localStream?.getVideoTracks().forEach((track) {
      track.enabled = !_isCameraOff;
    });
  }

  @override
  Widget build(BuildContext context) {
    final remoteRenderers = _callManager.remoteRenderers;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [

            // ── Remote videos (grid) ───────────────────────────────────────
            remoteRenderers.isEmpty
                ? const Center(
              child: Text(
                'Waiting for others to join...',
                style: TextStyle(color: Colors.white54),
              ),
            )
                : GridView.builder(
              itemCount: remoteRenderers.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: remoteRenderers.length == 1 ? 1 : 2,
                childAspectRatio: 3 / 4,
              ),
              itemBuilder: (ctx, i) {
                final username = remoteRenderers.keys.elementAt(i);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    RTCVideoView(
                      remoteRenderers[username]!,
                      objectFit: RTCVideoViewObjectFit
                          .RTCVideoViewObjectFitCover,
                    ),
                    Positioned(
                      bottom: 8, left: 8,
                      child: Text(username,
                        style: const TextStyle(
                          color: Colors.white,
                          backgroundColor: Colors.black45,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // ── Your local video (small, top-right corner) ─────────────────
            Positioned(
              top: 16, right: 16,
              width: 100, height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),

            // ── Control bar (bottom) ───────────────────────────────────────
            Positioned(
              bottom: 24, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    label: _isMuted ? 'Unmute' : 'Mute',
                    onTap: _toggleMute,
                  ),
                  _ControlButton(
                    icon: Icons.call_end,
                    label: 'End',
                    color: Colors.red,
                    onTap: () => Navigator.pop(context),
                  ),
                  _ControlButton(
                    icon: _isCameraOff
                        ? Icons.videocam_off
                        : Icons.videocam,
                    label: _isCameraOff ? 'Show Cam' : 'Hide Cam',
                    onTap: _toggleCamera,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _callManager.dispose();
    _signaling.dispose();
    super.dispose();
  }
}

// ── Small reusable control button ─────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white12,
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}