import 'package:flutter/material.dart';
import '../server_api.dart';
import '../auth.dart';
import '../ai_interview.dart';
import '../job.dart';
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
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (ctx) => _CreateSessionDialog(
        server: widget.server,
        auth: widget.auth,
      ),
    );
    if (result == null) return;

    try {
      final session = await _service.createSession(
        jobPostingId: result['jobPostingId']! as int,
        title: result['title'] as String? ?? '',
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => AiChatScreen(
            server: widget.server,
            auth: widget.auth,
            sessionId: session.id,
            sessionTitle: session.displayTitle,
            initialMessages: [],
          ),
        ),
      );
      if (mounted) _loadSessions();
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
      final fullSession = await _service.fetchSession(session.id);
      if (!mounted) return;
      await Navigator.push(
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
      if (mounted) _loadSessions();
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
                      subtitle: Text(s.jobTitle),
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
  final Server server;
  final Auth auth;

  const _CreateSessionDialog({
    required this.server,
    required this.auth,
  });

  @override
  State<_CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<_CreateSessionDialog> {
  final _jobIdCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  JobPosting? _preview;
  bool _loading = false;
  String? _error;

  Future<void> _loadPreview() async {
    final id = int.tryParse(_jobIdCtrl.text.trim());
    if (id == null) {
      setState(() {
        _preview = null;
        _error = 'Enter a valid numeric job posting id.';
      });
      return;
    }

    final token = widget.auth.user?.token;
    if (token == null) {
      setState(() {
        _preview = null;
        _error = 'Not authenticated.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _preview = null;
    });

    try {
      final posting = await JobPosting.fetchById(widget.server, token, id);
      if (!mounted) return;
      setState(() => _preview = posting);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not find job posting: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Session'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _jobIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Job Posting ID *',
                        hintText: 'e.g. 12',
                      ),
                      autofocus: true,
                      onChanged: (_) {
                        if (_preview != null || _error != null) {
                          setState(() {
                            _preview = null;
                            _error = null;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _loading ? null : _loadPreview,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    tooltip: 'Preview posting',
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
              if (_preview != null) ...[
                const SizedBox(height: 12),
                _JobPostingPreview(posting: _preview!),
              ],
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _preview == null
              ? null
              : () {
                  Navigator.pop(context, {
                    'jobPostingId': _preview!.id,
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
    _jobIdCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }
}

class _JobPostingPreview extends StatelessWidget {
  final JobPosting posting;

  const _JobPostingPreview({required this.posting});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            posting.title,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            posting.description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          if (posting.requirements.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              posting.requirements,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}