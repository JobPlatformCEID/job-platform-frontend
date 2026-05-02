import 'dart:async';
import 'package:flutter/material.dart';
import '../server.dart';
import '../auth.dart';
import '../ai_interview.dart';
import '../theme/app_theme.dart';

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
        backgroundColor: AppTheme.error,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth > 1024
        ? ((screenWidth - 860) / 2).clamp(24.0, 120.0)
        : 16.0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('✦', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Assistant',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Online',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.success,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
                  itemCount: _messages.length + (_isAiTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) return const _TypingIndicator();
                    return _MessageBubble(message: _messages[index]);
                  },
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: _InputBar(
                controller: _controller,
                onSend: _sendMessage,
                enabled: !_isSending && !_isAiTyping,
                isThinking: _isAiTyping,
              ),
            ),
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
          color: isUser
              ? AppTheme.primary.withValues(alpha: 0.2)
              : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('✦', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
            Flexible(
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? AppTheme.primary : AppTheme.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),
          ],
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
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('✦', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
            const _Dot(delay: 0),
            const SizedBox(width: 4),
            const _Dot(delay: 200),
            const SizedBox(width: 4),
            const _Dot(delay: 400),
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
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppTheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final bool isThinking;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.enabled,
    required this.isThinking,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _shimmerAnim = Tween(begin: 0.0, end: 1.0).animate(_shimmerCtrl);
  }

  @override
  void didUpdateWidget(covariant _InputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isThinking && !oldWidget.isThinking) {
      _shimmerCtrl.repeat(reverse: true);
    } else if (!widget.isThinking && oldWidget.isThinking) {
      _shimmerCtrl.stop();
      _shimmerCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isThinking
        ? Color.lerp(AppTheme.primary, AppTheme.accent, _shimmerAnim.value) ?? AppTheme.cardBorder
        : AppTheme.cardBorder;

    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, child) {
        return Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    enabled: widget.enabled,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Type your answer…',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.primary, width: 2),
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
                  onPressed: widget.enabled ? widget.onSend : null,
                  icon: const Icon(Icons.send_rounded),
                  color: AppTheme.primary,
                  disabledColor: AppTheme.divider,
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surfaceAlt,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}