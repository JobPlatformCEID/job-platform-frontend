import 'package:flutter/material.dart';
import '../server_api.dart';
import '../auth.dart';
import '../user.dart';
import '../review.dart';
import 'user_profile_sheet.dart';
import '../widgets/user_avatar.dart';

class ReviewsScreen extends StatefulWidget {
  final Auth auth;
  final Server server;

  const ReviewsScreen({super.key, required this.auth, required this.server});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<Map<String, dynamic>> _employers = [];
  bool _isLoading = true;
  String? _error;

  final _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredEmployers {
    if (_searchQuery.isEmpty) return _employers;
    final query = _searchQuery.toLowerCase();
    return _employers
        .where((e) => (e['company_name'] as String).toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadEmployers();
  }

  Future<void> _loadEmployers() async {
      try {
        final employers = await fetchEmployersList(widget.server, widget.auth.user!.token);
        if (mounted) {
          setState(() {
            _employers = employers;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() {
          _isLoading = false;
          _error = 'Could not load employers.';
        });
      }
    }

  void _showReviews(Map<String, dynamic> employer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewsSheet(
        employer: employer,
        server: widget.server,
        token: widget.auth.user!.token,
        auth: widget.auth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))));

    final employers = _filteredEmployers;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search employers',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: employers.isEmpty
          ? Center(
              child: Text(
                _searchQuery.isEmpty ? 'No employers found.' : 'No results for "$_searchQuery".',
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadEmployers,
              child: ListView.separated(
                itemCount: employers.length,
                separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  final employer = employers[index];
                  final employerId = employer['id'] as int;
                  final avatarUrl = employer['avatar'] as String?;
                  final userId = employer['user'] as int?;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Icon(Icons.business_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer)
                            : null,
                      ),
                      title: Text(employer['company_name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: (employer['location'] as String?)?.isNotEmpty == true
                          ? Text(employer['location'] as String)
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showReviews(employer),
                    ),
                  );
                },
              ),
            ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _ReviewsSheet extends StatefulWidget {
  final Map<String, dynamic> employer;
  final Server server;
  final String token;
  final Auth auth;

  const _ReviewsSheet({
    required this.employer,
    required this.server,
    required this.token,
    required this.auth,
  });

  @override
  State<_ReviewsSheet> createState() => _ReviewsSheetState();
}

class _ReviewsSheetState extends State<_ReviewsSheet> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await Review.fetchReviewsForEmployer(
        widget.server,
        widget.token,
        widget.employer['id'] as int,
      );
      if (mounted) {
        setState(() {
          // Sort so the current user's review appears first
          reviews.sort((a, b) {
            if (a.owner == widget.auth.user!.userId) return -1;
            if (b.owner == widget.auth.user!.userId) return 1;
            return 0;
          });
          _reviews = reviews;
          _isLoading = false;
      });
      }
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load reviews.';
      });
    }
  }

  void _showCreateReviewSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateReviewSheet(
        employer: widget.employer,
        server: widget.server,
        token: widget.token,
        onCreated: (review) => setState(() => _reviews.insert(0, review)),
        onSuccess: () => ReviewFeedbackMessage.showSuccess(context),
        onAlreadyReviewed: () => ReviewFeedbackMessage.showAlreadyReviewed(context),
      ),
    );
  }

  void _showReviewMenu(Review review) {
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
                _showEditReviewSheet(review);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outlined, color: Theme.of(context).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Review?'),
                    content: const Text('Are you sure you want to delete this review?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _handleDelete(review);
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditReviewSheet(Review review) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateReviewSheet(
        employer: widget.employer,
        server: widget.server,
        token: widget.token,
        existing: review,
        onCreated: (updated) => setState(() {
          final index = _reviews.indexWhere((r) => r.id == updated.id);
          if (index != -1) _reviews[index] = updated;
        }),
      ),
    );
  }

  Future<void> _handleDelete(Review review) async {
    try {
      await Review.delete(
        widget.server,
        widget.token,
        widget.employer['id'] as int,
        review.id,
      );
      if (mounted) setState(() => _reviews.removeWhere((r) => r.id == review.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete review.')),
        );
      }
    }
  }

  // Builds a row of stars for a given score out of 10
  Widget _buildStars(BuildContext context, int score) {
    const totalStars = 5;
    final filled = (score / 2).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalStars, (i) => Icon(
        i < filled ? Icons.star : Icons.star_border,
        size: 16,
        color: Theme.of(context).colorScheme.primary,
      )),
    );
  }

  double get _averageScore {
    if (_reviews.isEmpty) return 0;
    return _reviews.map((r) => r.score).reduce((a, b) => a + b) / _reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.employer['company_name'] as String? ?? '',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (!_isLoading && _reviews.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _buildStars(context, _averageScore.round()),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_averageScore.toStringAsFixed(1)} / 10 · ${_reviews.length} review${_reviews.length == 1 ? '' : 's'}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
                          : _reviews.isEmpty
                              ? const Center(child: Text('No reviews yet.'))
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _reviews.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final review = _reviews[index];
                                    return ListTile(
                                      leading: GestureDetector(
                                        onTap: review.owner != null ? () => showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          builder: (_) => UserProfileSheet(
                                            userId: review.owner!,
                                            server: widget.server,
                                            token: widget.token,
                                          ),
                                        ) : null,
                                        child: UserAvatar(
                                          avatarUrl: review.ownerAvatar,
                                          displayName: review.ownerFullName ?? review.ownerUsername ?? '',
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Text(
                                            '${review.ownerFullName ?? review.ownerUsername ?? 'User #${review.owner}'} · ${review.score}/10${review.edited ? ' (edited)' : ''}',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                          if (review.owner == widget.auth.user!.userId) ...[
                                            const SizedBox(width: 8),
                                            Chip(
                                              label: const Text('Me'),
                                              padding: EdgeInsets.zero,
                                              visualDensity: VisualDensity.compact,
                                            ),
                                          ],
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildStars(context, review.score),
                                          if (review.content.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(review.content),
                                          ],
                                        ],
                                      ),
                                      onLongPress: review.owner == widget.auth.user!.userId
                                          ? () => _showReviewMenu(review)
                                          : null,
                                    );
                                  },
                                ),
                ),
              ],
            ),
            if (widget.auth.user is Candidate)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  heroTag: 'create_review',
                  onPressed: _showCreateReviewSheet,
                  child: const Icon(Icons.add),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CreateReviewSheet extends StatefulWidget {
  final Map<String, dynamic> employer;
  final Server server;
  final String token;
  final void Function(Review review) onCreated;
  final Review? existing;
  final VoidCallback? onSuccess;
  final VoidCallback? onAlreadyReviewed;

  const _CreateReviewSheet({
    required this.employer,
    required this.server,
    required this.token,
    required this.onCreated,
    this.existing,
    this.onSuccess,
    this.onAlreadyReviewed,
  });

  @override
  State<_CreateReviewSheet> createState() => _CreateReviewSheetState();
}

class _CreateReviewSheetState extends State<_CreateReviewSheet> {
  final _contentController = TextEditingController();
  int _score = 5;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _score = widget.existing!.score;
      _contentController.text = widget.existing!.content;
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _isLoading = true);
    try {
      final review = widget.existing == null
          ? await Review.create(
              widget.server,
              widget.token,
              widget.employer['id'] as int,
              score: _score,
              content: _contentController.text.trim(),
            )
          : await Review.update(
              widget.server,
              widget.token,
              widget.employer['id'] as int,
              widget.existing!.id,
              score: _score,
              content: _contentController.text.trim(),
            );
      if (mounted) {
        //make the user go back a screen so that they actually see it
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('review submitted successfully')),
        );
        Navigator.of(context).pop();
        widget.onCreated(review);
        widget.onSuccess?.call();
      }
    } on ServerException catch (e) {
      if (mounted) {
        if (e.statusCode == 403) {
          widget.onAlreadyReviewed?.call();
        } else {
          ReviewFeedbackMessage.showError(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ReviewFeedbackMessage.showError(context);
      }
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
          Text(widget.existing == null ? 'Leave a review' : 'Edit review', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),

          // Score slider
          Text('Score: $_score / 10', style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: _score.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: '$_score',
            onChanged: (value) => setState(() => _score = value.round()),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _contentController,
            maxLines: 4,
            maxLength: 400,
            decoration: const InputDecoration(
              labelText: 'Review (optional)',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.edit_outlined),
            ),
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _isLoading ? null : _handleSubmit,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(widget.existing == null ? 'Submit' : 'Save'),
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

class ReviewFeedbackMessage {
  static void showSuccess(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('Review submitted successfully.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  static void showError(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('Could not submit review.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  static void showAlreadyReviewed(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('You have already reviewed this employer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}
