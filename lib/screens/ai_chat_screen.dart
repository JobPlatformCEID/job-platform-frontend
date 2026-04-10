import 'package:flutter/material.dart';
import '../server.dart';
import '../auth.dart';

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
  bool get isAssistant => role == 'assistant';
}

class AiChatScreen extends StatelessWidget {
  final Server server;
  final Auth auth;
  final int sessionId;
  final String sessionTitle;
  final List<Message> messages;

  const AiChatScreen({
    super.key,
    required this.server,
    required this.auth,
    required this.sessionId,
    required this.sessionTitle,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161b22),
        title: Text(sessionTitle, style: const TextStyle(color: Color(0xFFc9d1d9))),
        iconTheme: const IconThemeData(color: Color(0xFFc9d1d9)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Color(0xFF58a6ff),
            ),
            const SizedBox(height: 16),
            const Text(
              'AI Chat Coming Soon',
              style: TextStyle(
                color: Color(0xFFc9d1d9),
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Session: $sessionTitle',
              style: const TextStyle(
                color: Color(0xFF8b949e),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Messages loaded: ${messages.length}',
              style: const TextStyle(
                color: Color(0xFF8b949e),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'flutter_chat integration pending',
              style: TextStyle(
                color: Color(0xFF6e7681),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
