import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef OnUserListChanged = void Function(List<dynamic> users);
typedef OnOfferReceived   = void Function(String sender, Map<String, dynamic> offer);
typedef OnAnswerReceived  = void Function(String sender, Map<String, dynamic> answer);
typedef OnIceReceived     = void Function(String sender, Map<String, dynamic> candidate);
typedef OnUserLeft        = void Function(String username);

class SignalingService {
  WebSocketChannel? _channel;
  final String currentUsername;
  final _storage = const FlutterSecureStorage();

  OnUserListChanged? onUserListChanged;
  OnOfferReceived?   onOfferReceived;
  OnAnswerReceived?  onAnswerReceived;
  OnIceReceived?     onIceReceived;
  OnUserLeft?        onUserLeft;

  SignalingService({required this.currentUsername});

  Future<void> connect(String roomId, String host) async {
    final token = await _storage.read(key: 'auth_token');
    final uri = Uri.parse('$host/ws/calls/$roomId/?token=$token');

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
          (message) {
        _handleMessage(jsonDecode(message));
      },
      onError: (e) => print('WS Error: $e'),
      onDone:  () => print('WS Closed'),
    );
  }

  void _handleMessage(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'user_joined':
        onUserListChanged?.call(data['users']);
        break;
      case 'user_left':
        onUserLeft?.call(data['username']);
        onUserListChanged?.call(data['users']);
        break;
      case 'offer':
        onOfferReceived?.call(data['sender'], data['offer']);
        break;
      case 'answer':
        onAnswerReceived?.call(data['sender'], data['answer']);
        break;
      case 'ice_candidate':
        onIceReceived?.call(data['sender'], data['candidate']);
        break;
    }
  }

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