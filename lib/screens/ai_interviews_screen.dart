import 'package:flutter/material.dart';
import '../server.dart';
import '../auth.dart';
import '../ai_interview.dart';
import 'ai_chat_screen.dart';

class AiInterviewsScreen extends StatefulWidget {
  final Server server;
  final Auth auth;

  const AiInterviewsScreen({
    super.key,
    required this.server,
    required this.auth,
  });

  @override
  State<AiInterviewsScreen> createState() => _AiInterviewsScreenState();
}

class _AiInterviewsScreenState extends State<AiInterviewsScreen> {
  late final InterviewService _service;
  List<InterviewSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = InterviewService(server: widget.server, auth: widget.auth);
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await _service.fetchSessions();
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Failed to load sessions: $e');
    }
  }

  Future<void> _createSession() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _CreateSessionDialog(),
    );
    if (result == null) return;

    try {
      final session = await _service.createSession(
        jobRole: result['jobRole']!,
        title: result['title'] ?? '',
      );
      setState(() => _sessions.insert(0, session));
      _openChat(session);
    } catch (e) {
      _showError('Failed to create: $e');
    }
  }

  Future<void> _editTitle(InterviewSession session) async {
    final controller = TextEditingController(text: session.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result == session.title) return;

    try {
      await _service.updateSessionTitle(session.id, result);
      setState(() {
        final idx = _sessions.indexWhere((s) => s.id == session.id);
        if (idx != -1) {
          _sessions[idx] = session.copyWith(
            title: result,
            updatedAt: DateTime.now(),
          );
        }
      });
    } catch (e) {
      _showError('Failed to update: $e');
    }
  }

  Future<void> _deleteSession(InterviewSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text('Delete "${session.displayTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _service.deleteSession(session.id);
      setState(() => _sessions.removeWhere((s) => s.id == session.id));
    } catch (e) {
      _showError('Failed to delete: $e');
    }
  }

  Future<void> _openChat(InterviewSession session) async {
    try {
      // fetch the full session so we have all messages before entering chat
      final fullSession = await _service.fetchSession(session.id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => AiChatScreen(
            server: widget.server,
            auth: widget.auth,
            sessionId: fullSession.id,
            sessionTitle: fullSession.displayTitle,
            initialMessages: fullSession.messages,
          ),
        ),
      );
    } catch (e) {
      _showError('Failed to load session: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.fixed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Interviews'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createSession,
            tooltip: 'New Session',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(
                  child: Text('No sessions yet. Tap + to create one.'),
                )
              : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (ctx, i) {
                    final s = _sessions[i];
                    return ListTile(
                      title: Text(s.displayTitle),
                      subtitle: Text(s.jobRole),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _editTitle(s);
                          if (value == 'delete') _deleteSession(s);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18),
                                SizedBox(width: 8),
                                Text('Edit title'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _openChat(s),
                    );
                  },
                ),
    );
  }
}

class _CreateSessionDialog extends StatefulWidget {
  const _CreateSessionDialog();

  @override
  State<_CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<_CreateSessionDialog> {
  final _roleCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _roleCtrl,
            decoration: const InputDecoration(
              labelText: 'Job Role *',
              hintText: 'e.g. Software Engineer',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              hintText: 'e.g. Senior Position',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final role = _roleCtrl.text.trim();
            if (role.isEmpty) return;
            Navigator.pop(context, {
              'jobRole': role,
              'title': _titleCtrl.text.trim(),
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _roleCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }
}