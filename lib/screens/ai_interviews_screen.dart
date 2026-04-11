import 'package:flutter/material.dart';
import '../server.dart';
import '../auth.dart';
import 'ai_chat_screen.dart';

class InterviewSession {
  final int id;
  final String jobRole;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Message> messages;

  const InterviewSession({
    required this.id,
    required this.jobRole,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  String get displayTitle => title.isNotEmpty ? title : jobRole;

  factory InterviewSession.fromJson(Map<String, dynamic> json) {
    final msgs = json['messages'] as List<dynamic>? ?? [];
    return InterviewSession(
      id: json['id'] as int,
      jobRole: json['job_role'] as String,
      title: json['title'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      messages: msgs.map((m) => Message.fromJson(m as Map<String, dynamic>)).toList(),
    );
  }

  static Future<List<InterviewSession>> fetchSessions(Server server, String token) async {
    final response = await server.sendGetList('/api/sessions/', token: token);
    final List<dynamic> data = response as List<dynamic>;
    return data.map((j) => InterviewSession.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<InterviewSession> createSession(
    Server server,
    String token, {
    required String jobRole,
    String title = '',
  }) async {
    final response = await server.sendPost(
      '/api/sessions/',
      {'job_role': jobRole, 'title': title},
      token: token,
    );
    return InterviewSession.fromJson(response as Map<String, dynamic>);
  }

  static Future<void> editTitle(Server server, String token, int id, String title) async {
    await server.sendPut(
      '/api/sessions/$id/',
      {'title': title},
      token: token,
    );
  }

  static Future<void> deleteSession(Server server, String token, int id) async {
    await server.sendDelete('/api/sessions/$id/', token: token);
  }
}

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
  List<InterviewSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final token = widget.auth.user?.token;
      if (token == null) {
        setState(() => _loading = false);
        return;
      }
      final sessions = await InterviewSession.fetchSessions(widget.server, token);
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sessions: $e'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  Future<void> _createSession() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _CreateSessionDialog(),
    );
    if (result == null) return;

    try {
      final token = widget.auth.user!.token;
      final session = await InterviewSession.createSession(
        widget.server,
        token,
        jobRole: result['jobRole']!,
        title: result['title'] ?? '',
      );
      setState(() => _sessions.insert(0, session));
      _openChat(session);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create: $e'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
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
      final token = widget.auth.user!.token;
      await InterviewSession.editTitle(widget.server, token, session.id, result);
      setState(() {
        final idx = _sessions.indexWhere((s) => s.id == session.id);
        if (idx != -1) {
          _sessions[idx] = InterviewSession(
            id: session.id,
            jobRole: session.jobRole,
            title: result,
            createdAt: session.createdAt,
            updatedAt: DateTime.now(),
            messages: session.messages,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
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
      final token = widget.auth.user!.token;
      await InterviewSession.deleteSession(widget.server, token, session.id);
      setState(() => _sessions.removeWhere((s) => s.id == session.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  void _openChat(InterviewSession session) async {
    final token = widget.auth.user?.token;
    if (token == null) return;

    try {
      final response = await widget.server.sendGet(
        '/api/sessions/${session.id}/',
        token: token,
      );
      final fullSession = InterviewSession.fromJson(response as Map<String, dynamic>);

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load session: $e'),
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
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
              ? const Center(child: Text('No sessions yet. Tap + to create one.'))
              : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (ctx, i) {
                    final s = _sessions[i];
                    return ListTile(
                      title: Text(s.displayTitle),
                      subtitle: Text(s.jobRole),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _editTitle(s);
                          } else if (value == 'delete') {
                            _deleteSession(s);
                          }
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
                                Text('Delete', style: TextStyle(color: Colors.red)),
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
