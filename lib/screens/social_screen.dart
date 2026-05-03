import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../auth.dart';
import '../server.dart';
import '../post.dart';
import 'user_profile_sheet.dart';
import '../widgets/user_avatar.dart';

class SocialScreen extends StatefulWidget {
  final Auth auth;
  final Server server;
  final String searchQuery;

  const SocialScreen({
    super.key,
    required this.auth,
    required this.server,
    required this.searchQuery,
  });

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _error;

  List<Post> get _filteredPosts {
    if (widget.searchQuery.isEmpty) return _posts;
    final query = widget.searchQuery.toLowerCase();
    return _posts.where((p) => p.content.toLowerCase().contains(query)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    try {
      final posts = await Post.fetchAllPosts(widget.server, widget.auth.user!.token);
      if (mounted) setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load posts.';
      });
    }
  }

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreatePostSheet(
        server: widget.server,
        token: widget.auth.user!.token,
        onCreated: (post) => setState(() => _posts.insert(0, post)),
      ),
    );
  }

  void _showPostDetail(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PostDetailSheet(
        post: post,
        server: widget.server,
        auth: widget.auth,
        onDeleted: () => setState(() => _posts.removeWhere((p) => p.id == post.id)),
        onUpdated: (updated) => setState(() {
          final index = _posts.indexWhere((p) => p.id == post.id);
          if (index != -1) _posts[index] = updated;
        }),
      ),
    );
  }

  void _showComments(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(
        post: post,
        server: widget.server,
        token: widget.auth.user!.token,
        currentUserId: widget.auth.user!.userId,
        onCommentAdded: () { 
          final index = _posts.indexWhere((p) => p.id == post.id);
          if (index != -1 && mounted) setState(() {
            final p = _posts[index];
            _posts[index] = Post(
              id: p.id,
              user: p.user,
              username: p.username,
              fullName: p.fullName,
              avatar: p.avatar,
              content: p.content,
              likesCount: p.likesCount,
              commentsCount: p.commentsCount + 1,
              images: p.images,
              createdAt: p.createdAt,
              updatedAt: p.updatedAt,
              isLikedByMe: p.isLikedByMe,
            );
          });
        },
      ),
    );
  }

  Future<void> _toggleLike(Post post) async {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return;

    final wasLiked = post.isLikedByMe;

    // Optimistic update
    setState(() {
      _posts[index] = Post(
        id: post.id,
        user: post.user,
        username: post.username,
        fullName: post.fullName,
        avatar: post.avatar,
        content: post.content,
        likesCount: wasLiked ? post.likesCount - 1 : post.likesCount + 1,
        commentsCount: post.commentsCount,
        createdAt: post.createdAt,
        updatedAt: post.updatedAt,
        images: post.images,
        isLikedByMe: !wasLiked,
      );
    });

    try {
      if (wasLiked) {
        await post.unlikePost(widget.server, widget.auth.user!.token);
      } else {
        await post.likePost(widget.server, widget.auth.user!.token);
      }
    } catch (e) {
      // Revert on failure
      if (mounted) setState(() => _posts[index] = post);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)));

    final posts = _filteredPosts;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadPosts,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            itemCount: posts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _PostComposerStub(
                  user: widget.auth.user!,
                  onTap: _showCreateSheet,
                );
              }
              if (posts.isEmpty) {
                return _buildEmptyState(context);
              }
              final post = posts[index - 1];
              return _PostCard(
                post: post,
                server: widget.server,
                token: widget.auth.user!.token,
                onTap: () => _showPostDetail(post),
                onLike: () => _toggleLike(post),
                onComment: () => _showComments(post),
              );
            },
          ),
        ),
        if (posts.isEmpty)
          Positioned.fill(
            top: 88,
            child: IgnorePointer(child: _buildEmptyState(context)),
          ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            heroTag: 'create_post',
            onPressed: _showCreateSheet,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = widget.searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered ? Icons.search_off_outlined : Icons.dynamic_feed_outlined,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              filtered ? 'No results for "${widget.searchQuery}"' : 'No posts yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Try a different search.'
                  : 'Be the first to share something with the community.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

String? _relativeTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return null;
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
  return '${(diff.inDays / 365).floor()}y';
}

class _PostComposerStub extends StatelessWidget {
  final dynamic user;
  final VoidCallback onTap;
  const _PostComposerStub({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              UserAvatar(
                avatarUrl: user.avatarUrl,
                displayName: user.fullName,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    "What's on your mind?",
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final Server server;
  final String token;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const _PostCard({
    required this.post,
    required this.server,
    required this.token,
    required this.onTap,
    required this.onLike,
    required this.onComment,
  });

  void _openProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => UserProfileSheet(
        userId: post.user,
        server: server,
        token: token,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final time = _relativeTime(post.createdAt);
    final edited = post.updatedAt != post.createdAt;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openProfile(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      UserAvatar(
                        avatarUrl: post.avatar,
                        displayName: post.fullName,
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.fullName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (time != null)
                              Row(
                                children: [
                                  Text(
                                    time,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  if (edited) ...[
                                    Text(
                                      ' · edited',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              if (post.content.isNotEmpty)
                Text(
                  post.content,
                  style: const TextStyle(fontSize: 15, height: 1.35),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),

              if (post.images.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PostImages(images: post.images),
              ],

              const SizedBox(height: 4),
              Row(
                children: [
                  _PostAction(
                    icon: post.isLikedByMe
                        ? Icons.favorite
                        : Icons.favorite_border,
                    iconColor: post.isLikedByMe ? Colors.red : cs.onSurfaceVariant,
                    label: '${post.likesCount}',
                    onTap: onLike,
                  ),
                  const SizedBox(width: 4),
                  _PostAction(
                    icon: Icons.mode_comment_outlined,
                    iconColor: cs.onSurfaceVariant,
                    label: '${post.commentsCount}',
                    onTap: onComment,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _PostAction({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(icon, key: ValueKey(icon), size: 20, color: iconColor),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostImages extends StatelessWidget {
  final List<PostImage> images;
  const _PostImages({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 600),
          child: Image.network(
            images[0].imageUrl,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              height: 200,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      );
    }
    if (images.length == 2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1,
          child: Row(
            children: [
              Expanded(child: _img(context, images[0].imageUrl)),
              const SizedBox(width: 2),
              Expanded(child: _img(context, images[1].imageUrl)),
            ],
          ),
        ),
      );
    }
    // 3+ images: 1 large left + up to 2 stacked right
    final extra = images.length - 3;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: Row(
          children: [
            Expanded(flex: 2, child: _img(context, images[0].imageUrl)),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _img(context, images[1].imageUrl)),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _img(context, images[2].imageUrl),
                        if (extra > 0)
                          Container(
                            color: Colors.black.withValues(alpha: 0.55),
                            alignment: Alignment.center,
                            child: Text(
                              '+$extra',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _img(BuildContext context, String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  final Server server;
  final String token;
  final void Function(Post post) onCreated;

  const _CreatePostSheet({
    required this.server,
    required this.token,
    required this.onCreated,
  });

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _contentController = TextEditingController();
  final _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
  bool _isLoading = false;
  String? _error;

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage();
    final maxImageLen =  20 * 1024 * 1024;

    final List<XFile> oversized = [];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      if (bytes.length > maxImageLen) {
        oversized.add(image);
      } else {
        setState(() => _selectedImages.add(image));
      }
    }
    if (oversized.isNotEmpty && mounted) {
      setState(() => _error = '${oversized.length} image(s) exceeded the 20MB limit and were not added.');
    }
  }

  Future<void> _handleSubmit() async {
    if (_contentController.text.trim().isEmpty) {
      setState(() => _error = 'Post content cannot be empty.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      // Step 1: Create the post
      final post = await Post.createPost(
        widget.server,
        widget.token,
        content: _contentController.text.trim(),
      );

      // Step 2: Upload images one by one
      for (final image in _selectedImages) {
        final bytes = await image.readAsBytes();
        await PostImage.uploadImage(
          widget.server,
          widget.token,
          post.id,
          bytes,
          image.name,
        );
      }

      final fresh = await Post.fetchPost(widget.server, widget.token, post.id);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated(fresh);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not create post.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        return SafeArea(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create new post', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 24),

                TextField(
                  controller: _contentController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Post text',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Selected images preview
                if (_selectedImages.isNotEmpty) ...[
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final image = _selectedImages[index];
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FutureBuilder<Uint8List>(
                                future: image.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) return const SizedBox(width: 80);
                                  return Image.memory(
                                    snapshot.data!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedImages.removeAt(index)),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onError),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: [
                    const Text('Photos:'),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.upload_outlined),
                      label: const Text('Upload'),
                    ),
                  ],
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500)),
                ],

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Post'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}

class _PostDetailSheet extends StatefulWidget {
  final Post post;
  final Server server;
  final Auth auth;
  final VoidCallback onDeleted;
  final void Function(Post updated) onUpdated;

  const _PostDetailSheet({
    required this.post,
    required this.server,
    required this.auth,
    required this.onDeleted,
    required this.onUpdated,
  });

  @override
  State<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<_PostDetailSheet> {
  List<PostImage> _images = [];
  bool _isLoading = true;
  late Post _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _fetchPost();
  }

  Future<void> _fetchPost() async {
    try {
      final fresh = await Post.fetchPost(widget.server, widget.auth.user!.token, widget.post.id);
      if (mounted) setState(() {
        _post = fresh;
        _images = fresh.images;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _images = widget.post.images;  // fallback to what we have from social feed
        _isLoading = false;
      });
    }
  }

  void _openFullScreen(PostImage image) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenImageView(imageUrl: image.imageUrl),
      ),
    );
  }

  void _showPostMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(context).pop();
                _showEditSheet();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outlined, color: Theme.of(context).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.of(context).pop();
                _handleDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditPostSheet(
        post: _post,
        server: widget.server,
        token: widget.auth.user!.token,
        onUpdated: (updated) {
          widget.onUpdated(updated);
          if (mounted) setState(() {
            _post = updated;
            _images = updated.images;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _handleDelete() async {
    try {
      await widget.post.deletePost(widget.server, widget.auth.user!.token);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDeleted();
      }
    } catch (e) {
      if (mounted) setState(() {});
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => UserProfileSheet(
                        userId: _post.user,
                        server: widget.server,
                        token: widget.auth.user!.token,
                      ),
                    ),
                    child: UserAvatar(
                      avatarUrl: _post.avatar,
                      displayName: _post.fullName,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_post.fullName, style: Theme.of(context).textTheme.titleSmall),
                  ),
                  if (_post.user == widget.auth.user!.userId)
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: _showPostMenu,
                    ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(_post.content, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),

                  // Images
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_images.isNotEmpty) ...[
                    Text('Photos', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        final image = _images[index];
                        return GestureDetector(
                          onTap: () => _openFullScreen(image),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              image.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 64),
        ),
      ),
    );
  }
}

class _EditPostSheet extends StatefulWidget {
  final Post post;
  final Server server;
  final String token;
  final void Function(Post updated) onUpdated;

  const _EditPostSheet({
    required this.post,
    required this.server,
    required this.token,
    required this.onUpdated,
  });

  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  late final TextEditingController _contentController;
  bool _isLoading = false;
  String? _error;
  List<PostImage> _existingImages = [];
  final List<XFile> _newImages = [];
  bool _isLoadingImages = true;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.content);
    _existingImages = List.from(widget.post.images);
    _isLoadingImages = false;
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    final maxImageLen =  20 * 1024 * 1024;

    final List<XFile> oversized = [];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      if (bytes.length > maxImageLen) {
        oversized.add(image);
      } else {
        setState(() => _newImages.add(image));
      }
    }
    if (oversized.isNotEmpty && mounted) {
      setState(() => _error = '${oversized.length} image(s) exceeded the 20MB limit and were not added.');
    }
  }

  Future<void> _deleteExistingImage(PostImage image) async {
    try {
      await image.deleteImage(widget.server, widget.token);
      if (mounted) setState(() => _existingImages.removeWhere((i) => i.id == image.id));
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not delete image.');
    }
  }

  Future<void> _handleSubmit() async {
    if (_contentController.text.trim().isEmpty) {
      setState(() => _error = 'Post content cannot be empty.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final updated = await widget.post.updatePost(
        widget.server,
        widget.token,
        content: _contentController.text.trim(),
      );

      // Upload new images
      for (final image in _newImages) {
        final bytes = await image.readAsBytes();
        await PostImage.uploadImage(
          widget.server,
          widget.token, 
          widget.post.id,
          bytes,
          image.name,
        );
      }

      // Re-fetch to get updated images list
      final fresh = await Post.fetchPost(
        widget.server,
        widget.token,
        updated.id,
      );

      if (mounted) widget.onUpdated(fresh);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not update post.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit post', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          TextField(
            controller: _contentController,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Post text',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingImages)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Existing images
            if (_existingImages.isNotEmpty) ...[
              Text('Current photos', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final image = _existingImages[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            image.imageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _deleteExistingImage(image),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onError),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // New images preview
            if (_newImages.isNotEmpty) ...[
              Text('New photos', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _newImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final image = _newImages[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<Uint8List>(
                            future: image.readAsBytes(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox(width: 80);
                              return Image.memory(snapshot.data!, width: 80, height: 80, fit: BoxFit.cover);
                            },
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _newImages.removeAt(index)),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onError),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Upload button
            Row(
              children: [
                const Text('Add photos:'),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.upload_outlined),
                  label: const Text('Upload'),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _handleSubmit,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}

class _CommentsSheet extends StatefulWidget {
  final Post post;
  final Server server;
  final String token;
  final int currentUserId;
  final VoidCallback? onCommentAdded;

  const _CommentsSheet({
    required this.post,
    required this.server,
    required this.token,
    required this.currentUserId,
    this.onCommentAdded,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  List<Comment> _comments = [];
  bool _isLoading = true;
  String? _error;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await Comment.fetchCommentsForPost(
        widget.server,
        widget.token,
        widget.post.id,
      );
      if (mounted) {
        setState(() {
          // Sort comments to show the current user's ones first
          comments.sort((a, b) {
            if (a.user == widget.currentUserId) return -1;
            if (b.user == widget.currentUserId) return 1;
            return 0;
          });
          _comments = comments;
          _isLoading = false;
      });
      }
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load comments.';
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final comment = await Comment.createComment(
        widget.server,
        widget.token,
        widget.post.id,
        content: _commentController.text.trim(),
      );
      if (mounted) {
        _commentController.clear();
        await _loadComments();
      }
      widget.onCommentAdded?.call(); 
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not post comment.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showCommentMenu(Comment comment) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(context).pop();
                _showEditCommentSheet(comment);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outlined, color: Theme.of(context).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.of(context).pop();
                _handleDeleteComment(comment);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCommentSheet(Comment comment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditCommentSheet(
        comment: comment,
        server: widget.server,
        token: widget.token,
        onUpdated: (updated) => setState(() {
          final index = _comments.indexWhere((c) => c.id == updated.id);
          if (index != -1) _comments[index] = updated;
        }),
      ),
    );
  }

  Future<void> _handleDeleteComment(Comment comment) async {
    try {
      await comment.deleteComment(widget.server, widget.token);
      if (mounted) setState(() => _comments.removeWhere((c) => c.id == comment.id));
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not delete comment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: Duration.zero,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text('Comments', style: Theme.of(context).textTheme.headlineSmall),
              ),
              const Divider(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _comments.isEmpty
                        ? const Center(child: Text('No comments yet.'))
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _comments.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final comment = _comments[index];
                              return ListTile(
                                leading: GestureDetector(
                                  onTap: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => UserProfileSheet(
                                      userId: comment.user,
                                      server: widget.server,
                                      token: widget.token,
                                    ),
                                  ),
                                  child: UserAvatar(
                                    avatarUrl: comment.avatar,
                                    displayName: comment.fullName ?? comment.username ?? '',
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(comment.fullName ?? comment.username ?? 'User #${comment.user}', style: Theme.of(context).textTheme.titleSmall),
                                    if (comment.user == widget.currentUserId) ...[
                                      const SizedBox(width: 8),
                                      Chip(
                                        label: const Text('Me'),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(comment.content),
                                onLongPress: comment.user == widget.currentUserId
                                    ? () => _showCommentMenu(comment)
                                    : null,
                              );
                            },
                          ),
              ),
              const Divider(),
              // Comment input
              Padding(
                padding: EdgeInsets.only(
                  left: 16, right: 16, top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleSubmit(),
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSubmitting
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _handleSubmit,
                          ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class _EditCommentSheet extends StatefulWidget {
  final Comment comment;
  final Server server;
  final String token;
  final void Function(Comment updated) onUpdated;

  const _EditCommentSheet({
    required this.comment,
    required this.server,
    required this.token,
    required this.onUpdated,
  });

  @override
  State<_EditCommentSheet> createState() => _EditCommentSheetState();
}

class _EditCommentSheetState extends State<_EditCommentSheet> {
  late final TextEditingController _contentController;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.comment.content);
  }

  Future<void> _handleSubmit() async {
    if (_contentController.text.trim().isEmpty) {
      setState(() => _error = 'Comment cannot be empty.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final updated = await widget.comment.updateComment(
        widget.server,
        widget.token,
        content: _contentController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onUpdated(updated);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not update comment.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit comment', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          TextField(
            controller: _contentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Comment',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _handleSubmit,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}
