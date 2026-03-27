import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

// Callback type definitions
typedef OnUserListChanged = void Function(List<dynamic> users);
typedef OnOfferReceived   = void Function(String sender, Map<String, dynamic> offer);
typedef OnAnswerReceived  = void Function(String sender, Map<String, dynamic> answer);
typedef OnIceReceived     = void Function(String sender, Map<String, dynamic> candidate);
typedef OnUserLeft        = void Function(String username);

class SignalingService {
  WebSocketChannel? _channel;
  final String currentUsername;

  // the callbacks
  OnUserListChanged? onUserListChanged;
  OnOfferReceived?   onOfferReceived;
  OnAnswerReceived?  onAnswerReceived;
  OnIceReceived?     onIceReceived;
  OnUserLeft?        onUserLeft;

  SignalingService({required this.currentUsername});

  // Connect to the Django signaling server

  void connect(String roomId, String host) {
    final uri = Uri.parse('ws://$host/ws/calls/$roomId/');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
          (message) => _handleMessage(jsonDecode(message)),
      onError: (e)    => print('WebSocket error: $e'),
      onDone:  ()     => print('WebSocket closed'),
    );
  }

  // route incoming Django messages to the right callback

  void _handleMessage(Map<String, dynamic> data) {
    switch (data['type']) {

      case 'user_joined':
        onUserListChanged?.call(data['users']);
        break;

      case 'user_left':
        onUserLeft?.call(data['username']);
        onUserListChanged?.call(data['users']);
        break;

    // Someone sent an offer
      case 'offer':
        onOfferReceived?.call(data['sender'], data['offer']);
        break;

    // You called someone and they accepted , they sent an answer
      case 'answer':
        onAnswerReceived?.call(data['sender'], data['answer']);
        break;

    // Routing info to help establish the direct P2P connection
      case 'ice_candidate':
        onIceReceived?.call(data['sender'], data['candidate']);
        break;
    }
  }

  // ─── Send helpers ─────────────────────────────────────────────────────────

  void sendOffer(String target, Map<String, dynamic> offer) {
    _send({'type': 'offer', 'target': target, 'offer': offer});
  }

  void sendAnswer(String target, Map<String, dynamic> answer) {
    _send({'type': 'answer', 'target': target, 'answer': answer});
  }

  void sendIceCandidate(String target, Map<String, dynamic> candidate) {
    _send({'type': 'ice_candidate', 'target': target, 'candidate': candidate});
  }

  void _send(Map<String, dynamic> data) {
    _channel?.sink.add(jsonEncode(data));
  }

  void dispose() {
    _channel?.sink.close();
  }
}