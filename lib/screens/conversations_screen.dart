import 'package:flutter/material.dart';
import '../auth.dart';
import '../server.dart';
import '../conversation.dart';
import 'messages_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final Auth auth;
  final Server server;
  final String searchQuery;

  const ConversationsScreen({
    super.key,
    required this.auth,
    required this.server,
    required this.searchQuery,
  });

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String? _error;

  List<Conversation> get _filteredConversations {
    if (widget.searchQuery.isEmpty) return _conversations;
    final query = widget.searchQuery.toLowerCase();
    return _conversations
        .where((c) => (c.otherUsername ?? '').toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await Conversation.fetchAllConversations(widget.server, widget.auth.user!.token);
      if (mounted) setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load conversations.';
      });
    }
  }

  void _showNewConversationDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New conversation'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'User ID', // TODO: Make it full name when the server supports it
            prefixIcon: Icon(Icons.person_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final userId = int.tryParse(controller.text.trim());
              if (userId == null) return;
              Navigator.of(context).pop();
              await _startConversation(userId);
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  Future<void> _startConversation(int userId) async {
    try {
      final conversation = await Conversation.createConversation(
        widget.server,
        widget.auth.user!.token,
        userId,
      );
      if (mounted) {
        // Add to list if not already there
        final exists = _conversations.any((c) => c.id == conversation.id);
        if (!exists) setState(() => _conversations.insert(0, conversation));
        _openChat(conversation);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start conversation.')),
        );
      }
    }
  }

  void _openChat(Conversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          conversation: conversation,
          server: widget.server,
          auth: widget.auth,
        ),
      ),
    );
  }

  Future<void> _handleDelete(Conversation conversation) async {
    try {
      await conversation.deleteConversation(widget.server, widget.auth.user!.token);
      if (mounted) setState(() => _conversations.removeWhere((c) => c.id == conversation.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete conversation.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)));

    final conversations = _filteredConversations;

    return Stack(
      children: [
        if (conversations.isEmpty)
          Center(
            child: Text(
              widget.searchQuery.isEmpty ? 'No conversations yet.' : 'No results for "${widget.searchQuery}".',
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _loadConversations,
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  title: Text(conversation.otherUsername ?? 'User #${conversation.otherUserId}'),
                  subtitle: conversation.lastMessage != null
                      ? Text(
                          conversation.lastMessage!.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : const Text('No messages yet.'),
                  onTap: () => _openChat(conversation),
                  onLongPress: () => _handleDelete(conversation),
                );
              },
            ),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'new_conversation',
            onPressed: _showNewConversationDialog,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}