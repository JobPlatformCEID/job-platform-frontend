import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';
import 'package:flutter/foundation.dart';

class CallManager {
  final SignalingService signaling;
  final String currentUsername;

  MediaStream? localStream;

  // One RTCPeerConnection per remote user { username: peerConnection }
  final Map<String, RTCPeerConnection> _peers = {};

  // One renderer per remote user — the UI uses these to show video
  final Map<String, RTCVideoRenderer> remoteRenderers = {};

  // Notify UI when renderers change
  VoidCallback? onStreamsChanged;

  // The list of our stun servers
  // these will be used to connect the 2 browsers
  // were gonna use use googles stun servers cause they're the most popular
  final Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  CallManager({
    required this.signaling,
    required this.currentUsername,
  }) {
    _setupSignalingCallbacks();
  }

  // Wire signaling callbacks to WebRTC actions

  void _setupSignalingCallbacks() {

    // Someone sent us an offer → create answer
    signaling.onOfferReceived = (sender, offer) async {
      await _handleOffer(sender, offer);
    };

    // Someone answered our offer → finalise connection
    signaling.onAnswerReceived = (sender, answer) async {
      final peer = _peers[sender];
      if (peer == null) return;
      await peer.setRemoteDescription(
        RTCSessionDescription(answer['sdp'], answer['type']),
      );
    };

    // ICE candidate arrived → add it to the right peer
    signaling.onIceReceived = (sender, candidate) async {
      final peer = _peers[sender];
      if (peer == null) return;
      await peer.addCandidate(
        RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        ),
      );
    };

    // A user left → clean up their peer connection and renderer
    signaling.onUserLeft = (username) {
      _removePeer(username);
    };
  }

  // Get camera & mic

  Future<MediaStream> startLocalStream() async {
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    return localStream!;
  }

  // Call a specific user (you are the initiator)

  Future<void> callUser(String remoteUsername) async {
    final peer = await _createPeer(remoteUsername);

    // Create an offer
    final offer = await peer.createOffer({});
    await peer.setLocalDescription(offer);

    signaling.sendOffer(remoteUsername, {
      'sdp':  offer.sdp,
      'type': offer.type,
    });
  }

  // Someone called you, create and send an answer

  Future<void> _handleOffer(String sender, Map<String, dynamic> offer) async {
    final peer = await _createPeer(sender);

    // Register what THEY want to send you
    await peer.setRemoteDescription(
      RTCSessionDescription(offer['sdp'], offer['type']),
    );

    // Create your acceptance response
    final answer = await peer.createAnswer({});
    await peer.setLocalDescription(answer);

    signaling.sendAnswer(sender, {
      'sdp':  answer.sdp,
      'type': answer.type,
    });
  }

  // Core: Create and configure one RTCPeerConnection

  Future<RTCPeerConnection> _createPeer(String remoteUsername) async {
    final peer = await createPeerConnection(_iceConfig);

    // Add your local camera/mic tracks into this connection
    localStream?.getTracks().forEach((track) {
      peer.addTrack(track, localStream!);
    });

    // When ICE finds a network route, send it to the remote user
    peer.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        signaling.sendIceCandidate(remoteUsername, {
          'candidate':     candidate.candidate,
          'sdpMid':        candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    // When their video/audio stream arrives, create a renderer for the UI
    peer.onTrack = (event) async {
      if (event.streams.isNotEmpty) {
        await _setupRemoteRenderer(remoteUsername, event.streams[0]);
      }
    };

    peer.onConnectionState = (state) {
      print('Peer [$remoteUsername]: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _removePeer(remoteUsername);
      }
    };

    _peers[remoteUsername] = peer;
    return peer;
  }

  //Setup a video renderer for a remote user's stream

  Future<void> _setupRemoteRenderer(String username, MediaStream stream) async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;
    remoteRenderers[username] = renderer;
    onStreamsChanged?.call(); // tell the UI to rebuild
  }

  // Clean up when a user leaves

  void _removePeer(String username) {
    _peers[username]?.close();
    _peers.remove(username);
    remoteRenderers[username]?.dispose();
    remoteRenderers.remove(username);
    onStreamsChanged?.call();
  }

  bool isConnectedTo(String username) => _peers.containsKey(username);

  void dispose() {
    for (final peer in _peers.values) peer.close();
    for (final renderer in remoteRenderers.values) renderer.dispose();
    localStream?.dispose();
  }

}