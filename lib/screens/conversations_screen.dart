import 'package:flutter/material.dart';
import '../server_api/auth.dart';
import '../server_api/server.dart';
import '../server_api/user.dart';
import '../server_api/conversation.dart';
import 'messages_screen.dart';
import '../widgets/user_avatar.dart';
import 'user_profile_sheet.dart';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UserSearchSheet(
        onSearch: (q) => User.searchUsers(widget.server, widget.auth.user!.token, q),
        onSelected: (userId) => _startConversation(userId),
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
    ).then((_) => _loadConversations());
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
                  leading: GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => UserProfileSheet(
                        userId: conversation.otherUserId!,
                        server: widget.server,
                        token: widget.auth.user!.token,
                      ),
                    ),
                    child: UserAvatar(
                      avatarUrl: conversation.otherUserAvatar,
                      displayName: conversation.otherUsername ?? '',
                    ),
                  ),
                  title: Text(conversation.otherFullName ?? conversation.otherUsername ?? 'User #${conversation.otherUserId}'),
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

class _UserSearchSheet extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function(String q) onSearch;
  final void Function(int userId) onSelected;

  const _UserSearchSheet({
    required this.onSearch,
    required this.onSelected,
  });

  @override
  State<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<_UserSearchSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await widget.onSearch(q.trim());
      if (mounted) setState(() => _results = results);
    } catch (_) {} finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _search,
                decoration: const InputDecoration(
                  hintText: 'Search by name or username...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _controller.text.length < 2
                                ? 'Type at least 2 characters'
                                : 'No users found.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final user = _results[index];
                            final fullName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
                            final displayName = fullName.isNotEmpty ? fullName : user['username'] as String;
                            return ListTile(
                              leading: UserAvatar(
                                avatarUrl: user['avatar'] as String?,
                                displayName: displayName,
                              ),
                              title: Text(displayName),
                              subtitle: Text('@${user['username']}'),
                              trailing: Chip(
                                label: Text(user['role'] as String),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                widget.onSelected(user['id'] as int);
                              },
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
