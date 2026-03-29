import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/signaling_service.dart';
import '../services/call_manager_service.dart';
import 'package:flutter/foundation.dart';
import '../server.dart';

class CallScreen extends StatefulWidget {
final String roomId;
  final String currentUsername;
  final Server server; // <-- NEW

  const CallScreen({
    super.key,
    required this.roomId,
    required this.currentUsername,
    required this.server, // <-- NEW
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  SignalingService? _signaling;
  CallManager? _callManager;
  RTCVideoRenderer? _localRenderer; // Make nullable instead of late
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isReady = false;
  List<String> _users = [];

  @override
  void initState() {
    super.initState();
    // Defer ALL heavy work until after first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCall();
    });
  }

  Future<void> _initCall() async {
    _localRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();

    _signaling = SignalingService(currentUsername: widget.currentUsername);
    _callManager = CallManager(
      signaling: _signaling!,
      currentUsername: widget.currentUsername,
    );

    _callManager!.onStreamsChanged = () { if (mounted) setState(() {}); };

    // Request permissions and start camera BEFORE connecting
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      await [Permission.camera, Permission.microphone].request();
    } 

    try {
      final stream = await _callManager!.startLocalStream();
      if (mounted) setState(() => _localRenderer!.srcObject = stream);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }

    _signaling!.onUserListChanged = (users) {
      if (!mounted) return;
      setState(() => _users = List<String>.from(
        users.map((u) => u['username']),
      ));

      for (final user in users) {
        final username = user['username'] as String;
        if (username != widget.currentUsername &&
            !_callManager!.isConnectedTo(username)) {
          if (widget.currentUsername.compareTo(username) < 0) {
            _callManager!.callUser(username);
          }
        }
      }
    };

   final baseUrl = widget.server.getServerUrl() ?? 'http://10.0.2.2:8000';
    final wsUrl = baseUrl.replaceFirst('http', 'ws').replaceFirst('8000', '8001');
    
    _signaling!.connect(widget.roomId, wsUrl); 
    
    if (mounted) setState(() => _isReady = true);
  }
  void _toggleMute() {
    final newMuted = !_isMuted;
    _callManager?.localStream?.getAudioTracks()
        .forEach((track) => track.enabled = !newMuted);
    setState(() => _isMuted = newMuted);
  }

  void _toggleCamera() {
    setState(() => _isCameraOff = !_isCameraOff);
    _callManager?.localStream?.getVideoTracks().forEach((track) {
      track.enabled = !_isCameraOff;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final remoteRenderers = _callManager?.remoteRenderers ?? {};

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [

            // Remote videos (background)
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

            // Your local video (small, top-right corner)
            if (_localRenderer != null)
              Positioned(
                top: 16, right: 16,
                width: 100, height: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(
                    _localRenderer!,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),

            // Control bar (bottom)
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
    _localRenderer?.dispose();
    _callManager?.dispose();
    _signaling?.dispose();
    super.dispose();
  }
}

// Small reusable control button
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