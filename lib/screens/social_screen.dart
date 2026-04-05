import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../auth.dart';
import '../server.dart';
import '../user.dart';
import '../post.dart';

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
      final posts = await Post.fetchPosts(widget.server, widget.auth.user!.token);
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
      ),
    );
  }

  Future<void> _toggleLike(Post post) async {
    try {
      final index = _posts.indexWhere((p) => p.id == post.id);
      if (index == -1) return;
      // Optimistic update
      setState(() {
        _posts[index] = Post(
          id: post.id,
          user: post.user,
          content: post.content,
          likesCount: post.likesCount + 1,
          commentsCount: post.commentsCount,
          createdAt: post.createdAt,
          updatedAt: post.updatedAt,
          images: post.images,
        );
      });
      await post.likePost(widget.server, widget.auth.user!.token);
    } catch (e) {
      // If it failed, try unlike (toggle)
      try {
        await post.unlikePost(widget.server, widget.auth.user!.token);
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (mounted && index != -1) setState(() {
          _posts[index] = Post(
            id: post.id,
            user: post.user,
            content: post.content,
            likesCount: (post.likesCount - 1).clamp(0, double.maxFinite.toInt()),
            commentsCount: post.commentsCount,
            createdAt: post.createdAt,
            updatedAt: post.updatedAt,
            images: post.images,
          );
        });
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)));

    final posts = _filteredPosts;

    return Stack(
      children: [
        if (posts.isEmpty)
          Center(
            child: Text(
              widget.searchQuery.isEmpty ? 'No posts yet.' : 'No results for "${widget.searchQuery}".',
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _loadPosts,
            child: ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return _PostCard(
                  post: post,
                  onTap: () => _showPostDetail(post),
                  onLike: () => _toggleLike(post),
                  onComment: () => _showComments(post),
                );
              },
            ),
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
}

class _PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const _PostCard({
    required this.post,
    required this.onTap,
    required this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Text('User #${post.user}', style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 12),

              // Content
              Text(post.content, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),

              // Post images small view
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: post.images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          post.images[index].imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Actions
              Row(
                children: [
                  IconButton(
                    onPressed: onLike,
                    icon: const Icon(Icons.favorite_border),
                    iconSize: 20,
                  ),
                  Text('${post.likesCount}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: onComment,
                    icon: const Icon(Icons.comment_outlined),
                    iconSize: 20,
                  ),
                  Text('${post.commentsCount}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
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
    if (images.isNotEmpty) {
      setState(() => _selectedImages.addAll(images));
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

      if (mounted) {
        Navigator.of(context).pop();
        widget.onCreated(post);
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
  bool _isLoadingImages = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final images = await PostImage.fetchPostImages(
        widget.server,
        widget.auth.user!.token,
        widget.post.id,
      );
      if (mounted) setState(() {
        _images = images;
        _isLoadingImages = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingImages = false);
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
        post: widget.post,
        server: widget.server,
        token: widget.auth.user!.token,
        onUpdated: (updated) {
          widget.onUpdated(updated);
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
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('User #${widget.post.user}', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  // TODO: only show for post owner when userId is available (same thing as reviews)
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
                  Text(widget.post.content, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),

                  // Images
                  if (_isLoadingImages)
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
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final images = await PostImage.fetchPostImages(widget.server, widget.token, widget.post.id);
      if (mounted) setState(() {
        _existingImages = images;
        _isLoadingImages = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingImages = false);
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) setState(() => _newImages.addAll(images));
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

      if (mounted) widget.onUpdated(updated);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not update post.');
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

  const _CommentsSheet({
    required this.post,
    required this.server,
    required this.token,
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
      if (mounted) setState(() {
        _comments = comments;
        _isLoading = false;
      });
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
      if (mounted) setState(() {
        _comments.add(comment);
        _commentController.clear();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not post comment.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // TODO: Same as reviews — no userId stored, so show menu for all comments and let server reject
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
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
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
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                child: Icon(Icons.person_outline, color: Theme.of(context).colorScheme.onPrimaryContainer),
                              ),
                              title: Text('User #${comment.user}', style: Theme.of(context).textTheme.titleSmall),
                              subtitle: Text(comment.content),
                              onLongPress: () => _showCommentMenu(comment),
                            );
                          },
                        ),
            ),
            const Divider(),
            // Comment input
            Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
