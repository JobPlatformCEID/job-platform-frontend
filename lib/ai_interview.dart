import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'server_api.dart';

class AiMessage {
  final int id;
  final String role;
  final String content;
  final DateTime createdAt;

  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
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
  final List<AiMessage> messages;

  const InterviewSession({
    required this.id,
    required this.jobPosting,
    required this.jobTitle,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

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
          .map((m) => AiMessage.fromJson(m as Map<String, dynamic>))
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

  static Future<List<InterviewSession>> fetchAll(Server server, String token) async {
    final data = await server.sendGetList('/api/sessions/', token: token);
    return data
        .map((j) => InterviewSession.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<InterviewSession> fetchById(Server server, String token, int id) async {
    final data = await server.sendGet('/api/sessions/$id/', token: token);
    return InterviewSession.fromJson(data);
  }

  static Future<InterviewSession> create(
    Server server,
    String token, {
    required int jobPostingId,
    String title = '',
  }) async {
    final data = await server.sendPost(
      '/api/sessions/',
      {'job_posting_id': jobPostingId, 'title': title},
      token: token,
    );
    return InterviewSession.fromJson(data);
  }

  Future<void> updateTitle(Server server, String token, String newTitle) async {
    await server.sendPut('/api/sessions/$id/', {'title': newTitle}, token: token);
  }

  Future<void> delete(Server server, String token) async {
    await server.sendDelete('/api/sessions/$id/', token: token);
  }

  static WebSocketChannel connect(Server server, String token, int sessionId) {
    final httpUrl = server.getServerUrl();
    if (httpUrl == null) throw Exception('Server not configured.');

    final base = Uri.parse(httpUrl);
    final wsUrl = Uri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      host: base.host,
      port: base.port,
      path: '/ws/interview/$sessionId/',
      queryParameters: {'token': token},
    );

    return WebSocketChannel.connect(wsUrl);
  }
}
