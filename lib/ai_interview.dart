import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'server_api.dart';
import 'auth.dart';

class Message {
  final int id;
  final String role;
  final String content;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isUser => role == 'user';
}

class InterviewSession {
  final int id;
  final int jobPosting;
  final String jobTitle;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Message> messages;

  const InterviewSession({
    required this.id,
    required this.jobPosting,
    required this.jobTitle,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  // falls back to the posting title when no custom title has been set
  String get displayTitle => title.isNotEmpty ? title : jobTitle;

  factory InterviewSession.fromJson(Map<String, dynamic> json) {
    final msgs = json['messages'] as List<dynamic>? ?? [];
    return InterviewSession(
      id: json['id'] as int,
      jobPosting: json['job_posting'] as int,
      jobTitle: json['job_title'] as String? ?? 'Job Posting #${json['job_posting']}',
      title: json['title'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      messages: msgs
          .map((m) => Message.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  InterviewSession copyWith({String? title, DateTime? updatedAt}) {
    return InterviewSession(
      id: id,
      jobPosting: jobPosting,
      jobTitle: jobTitle,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages,
    );
  }
}

sealed class ChatEvent {}

class ChatUserMessageConfirmed extends ChatEvent {
  final Message message;
  ChatUserMessageConfirmed(this.message);
}

class ChatAiMessageReceived extends ChatEvent {
  final Message message;
  ChatAiMessageReceived(this.message);
}

class ChatErrorReceived extends ChatEvent {
  final String message;
  ChatErrorReceived(this.message);
}

class ChatConnectionError extends ChatEvent {
  final Object error;
  ChatConnectionError(this.error);
}

class ChatConnectionClosed extends ChatEvent {}

class InterviewService {
  final Server server;
  final Auth auth;

  InterviewService({required this.server, required this.auth});

  String? get _token => auth.user?.token;

  Future<List<InterviewSession>> fetchSessions() async {
    final token = _token;
    if (token == null) throw Exception('Not authenticated.');
    final data = await server.sendGetList('/api/sessions/', token: token);
    return data
        .map((j) => InterviewSession.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<InterviewSession> fetchSession(int id) async {
    final token = _token;
    if (token == null) throw Exception('Not authenticated.');
    final data = await server.sendGet('/api/sessions/$id/', token: token);
    return InterviewSession.fromJson(data);
  }

  Future<InterviewSession> createSession({
    required int jobPostingId,
    String title = '',
  }) async {
    final token = _token;
    if (token == null) throw Exception('Not authenticated.');
    final data = await server.sendPost(
      '/api/sessions/',
      {'job_posting_id': jobPostingId, 'title': title},
      token: token,
    );
    return InterviewSession.fromJson(data);
  }

  Future<void> updateSessionTitle(int id, String title) async {
    final token = _token;
    if (token == null) throw Exception('Not authenticated.');
    await server.sendPut('/api/sessions/$id/', {'title': title}, token: token);
  }

  Future<void> deleteSession(int id) async {
    final token = _token;
    if (token == null) throw Exception('Not authenticated.');
    await server.sendDelete('/api/sessions/$id/', token: token);
  }

  ChatConnection openChat(int sessionId) {
    final httpUrl = server.getServerUrl();
    final token = _token;

    if (httpUrl == null) throw Exception('Server not configured.');
    if (token == null) throw Exception('Not authenticated.');

    final base = Uri.parse(httpUrl);
    final wsUrl = Uri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      host: base.host,
      port: base.port,
      path: '/ws/interview/$sessionId/',
      queryParameters: {'token': token},
    );

    return ChatConnection._(WebSocketChannel.connect(wsUrl));
  }
}

class ChatConnection {
  final WebSocketChannel _channel;
  late final Stream<ChatEvent> events;

  ChatConnection._(this._channel) {
    events = _channel.stream.map<ChatEvent>((raw) {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (data['type'] as String) {
        case 'user_message':
          return ChatUserMessageConfirmed(
            Message.fromJson(data['message'] as Map<String, dynamic>),
          );
        case 'ai_message':
          return ChatAiMessageReceived(
            Message.fromJson(data['message'] as Map<String, dynamic>),
          );
        default:
          return ChatErrorReceived(
            data['message'] as String? ?? 'An error occurred.',
          );
      }
    }).handleError((Object e) => ChatConnectionError(e)).asBroadcastStream();
  }

  void sendMessage(String content) {
    _channel.sink.add(jsonEncode({'content': content}));
  }

  Future<void> dispose() => _channel.sink.close();
}
