import 'dart:async';
import 'package:flutter/material.dart';
import '../server.dart';
import '../auth.dart';
import '../ai_interview.dart';

class AiChatScreen extends StatefulWidget {
  final Server server;
  final Auth auth;
  final int sessionId;
  final String sessionTitle;
  final List<Message> initialMessages;

  const AiChatScreen({
    super.key,
    required this.server,
    required this.auth,
    required this.sessionId,
    required this.sessionTitle,
    required this.initialMessages,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  late final List<Message> _messages;
  late final ChatConnection _chat;
  late final StreamSubscription<ChatEvent> _subscription;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isAiTyping = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messages = List.from(widget.initialMessages);
    final service = InterviewService(server: widget.server, auth: widget.auth);
    try {
      _chat = service.openChat(widget.sessionId);
      _subscription = _chat.events.listen(
        _onEvent,
        onError: (Object e) => _onEvent(ChatConnectionError(e)),
        onDone: () => _onEvent(ChatConnectionClosed()),
      );
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showError(e.toString()),
      );
    }
  }

  void _onEvent(ChatEvent event) {
    switch (event) {
      case ChatUserMessageConfirmed(:final message):
        // swap the optimistic placeholder with the real one from the server
        setState(() {
          final idx = _messages.lastIndexWhere((m) => m.isUser);
          if (idx != -1) _messages[idx] = message;
          _isSending = false;
        });

      case ChatAiMessageReceived(:final message):
        setState(() {
          _messages.add(message);
          _isAiTyping = false;
        });
        _scrollToBottom();

      case ChatErrorReceived(:final message):
        setState(() {
          _isAiTyping = false;
          _isSending = false;
        });
        _showError(message);

      case ChatConnectionError():
        setState(() {
          _isAiTyping = false;
          _isSending = false;
        });
        _showError('Connection error. Please restart the session.');

      case ChatConnectionClosed():
        _showError('Connection closed.');
    }
  }

  Future<void> _sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isSending || _isAiTyping) return;

    // add it immediately so the UI feels instant
    final optimistic = Message(
      id: -1,
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(optimistic);
      _isAiTyping = true;
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom();

    _chat.sendMessage(content);
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFda3633),
      ),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    _chat.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161b22),
        title: Text(
          widget.sessionTitle,
          style: const TextStyle(color: Color(0xFFc9d1d9)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFc9d1d9)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isAiTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return const _TypingIndicator();
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            onSend: _sendMessage,
            enabled: !_isSending && !_isAiTyping,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1f6feb) : const Color(0xFF21262d),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.content,
          style: const TextStyle(color: Color(0xFFc9d1d9), fontSize: 15),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF21262d),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(delay: 0),
            SizedBox(width: 4),
            _Dot(delay: 200),
            SizedBox(width: 4),
            _Dot(delay: 400),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: const CircleAvatar(radius: 4, backgroundColor: Color(0xFF58a6ff)),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161b22),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                style: const TextStyle(color: Color(0xFFc9d1d9)),
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type your answer…',
                  hintStyle: const TextStyle(color: Color(0xFF6e7681)),
                  filled: true,
                  fillColor: const Color(0xFF0d1117),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send_rounded),
              color: const Color(0xFF58a6ff),
              disabledColor: const Color(0xFF30363d),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF21262d),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}