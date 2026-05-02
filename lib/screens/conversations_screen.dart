import 'package:flutter/material.dart';
import '../auth.dart';
import '../server.dart';
import '../user.dart';
import '../conversation.dart';
import '../theme/app_theme.dart';
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
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)));

    final conversations = _filteredConversations;

    return Stack(
      children: [
        if (conversations.isEmpty)
          Center(
            child: Text(
              widget.searchQuery.isEmpty ? 'No conversations yet.' : 'No results for "${widget.searchQuery}".',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _loadConversations,
            color: AppTheme.primary,
            child: ListView.separated(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const Divider(
                color: AppTheme.divider,
                indent: 76,
                endIndent: 16,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final name = conversation.otherFullName ?? conversation.otherUsername ?? 'User #${conversation.otherUserId}';
                return InkWell(
                  onTap: () => _openChat(conversation),
                  onLongPress: () => _handleDelete(conversation),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
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
                            radius: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (conversation.lastMessage != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                      ),
                                      child: Text(
                                        _formatTimestamp(conversation.lastMessage!.createdAt),
                                        style: const TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                conversation.lastMessage?.content ?? 'No messages yet.',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff.inDays < 7) return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][dt.weekday - 1];
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
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
