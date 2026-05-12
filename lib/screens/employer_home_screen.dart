import 'package:flutter/material.dart';
import '../auth.dart';
import '../user.dart';
import '../job.dart';
import '../server_api.dart';
import '../filtering.dart';
import 'user_profile_sheet.dart';
import '../widgets/user_avatar.dart';
import '../conversation.dart';
import 'messages_screen.dart';

const _kContractTypes = ['full_time', 'part_time', 'freelance', 'internship'];

String _contractTypeLabel(String type) => switch (type) {
  'full_time' => 'Full-time',
  'part_time' => 'Part-time',
  'freelance' => 'Freelance',
  'internship' => 'Internship',
  _ => type,
};

String? _formatSalary(int? min, int? max) {
  if (min == null && max == null) return null;
  String fmt(int n) =>
      '€${n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  if (min != null && max != null) return '${fmt(min)} – ${fmt(max)}';
  if (min != null) return '≥ ${fmt(min)}';
  return '≤ ${fmt(max!)}';
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

class EmployerHomeScreen extends StatefulWidget {
  final Auth auth;
  final Server server;
  final String searchQuery;

  const EmployerHomeScreen({
    super.key,
    required this.auth,
    required this.server,
    required this.searchQuery,
  });

  @override
  State<EmployerHomeScreen> createState() => _EmployerHomeScreenState();
}

class _EmployerHomeScreenState extends State<EmployerHomeScreen> {
  List<JobPosting> _jobs = [];
  bool _isLoading = true;
  String? _error;
  JobPostingFilter _filter = const JobPostingFilter();

  Employer get _employer => widget.auth.user as Employer;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void didUpdateWidget(covariant EmployerHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      _filter = _filter.copyWith(
        title: widget.searchQuery.isEmpty ? null : widget.searchQuery,
      );
      _loadJobs();
    }
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final jobs = await JobPosting.fetchFiltered(
        widget.server,
        _employer.token,
        _filter,
      );
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _applyFilter(JobPostingFilter updated) {
    setState(() => _filter = updated);
    _loadJobs();
  }

  //filter chip sheets

  void _showContractTypeSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _ContractTypeSheet(current: _filter.contractType),
    );
    if (selected != null) {
      _applyFilter(_filter.copyWith(
        contractType: selected == '__clear__' ? null : selected,
      ));
    }
  }

  void _showLocationSheet() async {
    final entered = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LocationSheet(current: _filter.location),
    );
    if (entered != null) {
      _applyFilter(_filter.copyWith(location: entered.isEmpty ? null : entered));
    }
  }

  void _showSalarySheet() async {
    final result = await showModalBottomSheet<({int? min, int? max})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SalarySheet(currentMin: _filter.salaryMin, currentMax: _filter.salaryMax),
    );
    if (result != null) {
      _applyFilter(_filter.copyWith(salaryMin: result.min, salaryMax: result.max));
    }
  }

  void _showActiveSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _ActiveSheet(current: _filter.isActive),
    );
    if (selected != null) {
      _applyFilter(_filter.copyWith(
        isActive: selected == '__clear__' ? null : selected == 'true',
      ));
    }
  }

  //filter chips 

  Widget _remoteChip() {
    final active = _filter.isRemote == true;
    return FilterChip(
      label: const Text('Remote'),
      selected: active,
      avatar: active ? null : const Icon(Icons.wifi_outlined, size: 16),
      onSelected: (_) => _applyFilter(_filter.copyWith(isRemote: active ? null : true)),
    );
  }

  Widget _contractTypeChip() {
    final active = _filter.contractType != null;
    return FilterChip(
      label: Text(active ? _contractTypeLabel(_filter.contractType!) : 'Job type'),
      selected: active,
      avatar: active ? null : const Icon(Icons.work_outline, size: 16),
      onSelected: (_) => _showContractTypeSheet(),
    );
  }

  Widget _locationChip() {
    final active = _filter.location != null && _filter.location!.isNotEmpty;
    return FilterChip(
      label: Text(active ? _filter.location! : 'Location'),
      selected: active,
      avatar: active ? null : const Icon(Icons.location_on_outlined, size: 16),
      onSelected: (_) => _showLocationSheet(),
    );
  }

  Widget _salaryChip() {
    final hasMin = _filter.salaryMin != null;
    final hasMax = _filter.salaryMax != null;
    final active = hasMin || hasMax;
    String label = 'Salary';
    if (hasMin && hasMax) label = '€${_filter.salaryMin}–€${_filter.salaryMax}';
    else if (hasMin) label = '≥ €${_filter.salaryMin}';
    else if (hasMax) label = '≤ €${_filter.salaryMax}';
    return FilterChip(
      label: Text(label),
      selected: active,
      avatar: active ? null : const Icon(Icons.euro_outlined, size: 16),
      onSelected: (_) => _showSalarySheet(),
    );
  }

  Widget _activeChip() {
    final active = _filter.isActive != null;
    final label = active ? (_filter.isActive == true ? 'Active' : 'Inactive') : 'Status';
    return FilterChip(
      label: Text(label),
      selected: active,
      avatar: active ? null : const Icon(Icons.toggle_on_outlined, size: 16),
      onSelected: (_) => _showActiveSheet(),
    );
  }

  //job form 
  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JobFormSheet(onSubmit: _handleCreate),
    );
  }

  Future<void> _handleCreate(Map<String, dynamic> fields) async {
    try {
      final newJob = await JobPosting.create(
        widget.server, _employer.token,
        title: fields['title'],
        description: fields['description'],
        requirements: fields['requirements'],
        contractType: fields['contractType'],
        location: fields['location'],
        salaryMin: fields['salaryMin'],
        salaryMax: fields['salaryMax'],
        isRemote: fields['isRemote'],
      );
      if (mounted) {
        Navigator.of(context).pop();
        setState(() => _jobs.insert(0, newJob));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create job posting.')),
        );
      }
    }
  }

  Future<void> _handleDelete(JobPosting job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete job posting'),
        content: Text('Are you sure you want to delete "${job.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await job.delete(widget.server, _employer.token);
      if (mounted) setState(() => _jobs.removeWhere((j) => j.id == job.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete job posting.')),
        );
      }
    }
  }

  Future<void> _handleToggleActive(JobPosting job) async {
    try {
      final updated = await job.toggleActive(widget.server, _employer.token);
      if (mounted) {
        setState(() {
          final i = _jobs.indexWhere((j) => j.id == job.id);
          if (i != -1) _jobs[i] = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(updated.isActive ? '"${updated.title}" reactivated' : '"${updated.title}" deactivated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update job status.')),
        );
      }
    }
  }

  void _openJobDetail(JobPosting job) async {
    final result = await Navigator.of(context).push<_JobDetailResult>(
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(
          job: job,
          server: widget.server,
          token: _employer.token,
          auth: widget.auth,
        ),
      ),
    );
    if (result == null) return;
    if (result.deleted) {
      setState(() => _jobs.removeWhere((j) => j.id == job.id));
    } else if (result.updated != null) {
      setState(() {
        final i = _jobs.indexWhere((j) => j.id == job.id);
        if (i != -1) _jobs[i] = result.updated!;
      });
    }
  }

  void _showLongPressMenu(JobPosting job) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(job.isActive ? Icons.toggle_off_outlined : Icons.toggle_on_outlined),
              title: Text(job.isActive ? 'Deactivate' : 'Reactivate'),
              onTap: () { Navigator.of(context).pop(); _handleToggleActive(job); },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _JobFormSheet(
                    existing: job,
                    onSubmit: (fields) => _handleUpdate(job, fields),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outlined, color: Theme.of(context).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () { Navigator.of(context).pop(); _handleDelete(job); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdate(JobPosting job, Map<String, dynamic> fields) async {
    try {
      final updated = await job.update(
        widget.server, _employer.token,
        title: fields['title'],
        description: fields['description'],
        requirements: fields['requirements'],
        contractType: fields['contractType'],
        location: fields['location'],
        salaryMin: fields['salaryMin'],
        salaryMax: fields['salaryMax'],
        isRemote: fields['isRemote'],
      );
      if (mounted) {
        Navigator.of(context).pop();
        setState(() {
          final i = _jobs.indexWhere((j) => j.id == job.id);
          if (i != -1) _jobs[i] = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update job posting.')),
        );
      }
    }
  }

  // empty state

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = !(widget.searchQuery.isEmpty && _filter.isEmpty);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered ? Icons.search_off_outlined : Icons.work_off_outlined,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              filtered ? 'No matching postings' : 'No job postings yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Try widening your filters or search.'
                  : 'Tap the + button to create your first posting.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, JobPosting job) {
    final cs = Theme.of(context).colorScheme;
    final salaryLabel = _formatSalary(job.salaryMin, job.salaryMax);
    final posted = _relativeTime(job.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openJobDetail(job),
        onLongPress: () => _showLongPressMenu(job),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Icon(Icons.work_outline, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(right: 6, top: 2),
                          decoration: BoxDecoration(
                            color: job.isActive ? Colors.green : cs.onSurfaceVariant.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            job.title,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (posted != null)
                          Text(posted, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    DefaultTextStyle(
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          if (job.location.isNotEmpty)
                            _InlineMeta(icon: Icons.location_on_outlined, text: job.location),
                          if (job.isRemote)
                            const _InlineMeta(icon: Icons.wifi_outlined, text: 'Remote'),
                          _InlineMeta(icon: Icons.work_history_outlined, text: _contractTypeLabel(job.contractType)),
                        ],
                      ),
                    ),
                    if (salaryLabel != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          salaryLabel,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilterCount = [
      _filter.isRemote != null,
      _filter.contractType != null,
      _filter.location?.isNotEmpty == true,
      _filter.salaryMin != null || _filter.salaryMax != null,
      _filter.isActive != null,
    ].where((b) => b).length;

    return Stack(
      children: [
        Column(
          children: [
            // Filter chips
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (activeFilterCount > 0) ...[
                    ActionChip(
                      avatar: const Icon(Icons.close, size: 16),
                      label: Text('Clear ($activeFilterCount)'),
                      onPressed: () => _applyFilter(JobPostingFilter(title: _filter.title)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _remoteChip(),
                  const SizedBox(width: 8),
                  _contractTypeChip(),
                  const SizedBox(width: 8),
                  _locationChip(),
                  const SizedBox(width: 8),
                  _salaryChip(),
                  const SizedBox(width: 8),
                  _activeChip(),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
                      : _jobs.isEmpty
                          ? _buildEmptyState(context)
                          : RefreshIndicator(
                              onRefresh: _loadJobs,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _jobs.length,
                                itemBuilder: (context, index) => _buildJobCard(context, _jobs[index]),
                              ),
                            ),
            ),
          ],
        ),
        Positioned(
          bottom: 16, right: 16,
          child: FloatingActionButton(
            onPressed: _showCreateSheet,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}


// Job Detail Screen – full-page with applications list, search & filter
class _JobDetailResult {
  final bool deleted;
  final JobPosting? updated;
  const _JobDetailResult({this.deleted = false, this.updated});
}

class JobDetailScreen extends StatefulWidget {
  final JobPosting job;
  final Server server;
  final String token;
  final Auth auth;

  const JobDetailScreen({
    super.key,
    required this.job,
    required this.server,
    required this.token,
    required this.auth,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late JobPosting _job;

  List<JobApplication> _applications = [];
  List<JobApplication> _filtered = [];
  bool _isLoading = true;
  String? _error;

  // local filter state
  String _searchQuery = '';
  String? _statusFilter; // null = all, 'pending', 'accepted', 'rejected'
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _loadApplications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      // fetch with status filter applied server-side if set
      final filter = JobApplicationFilter(
        job: _job.id,
        status: _statusFilter,
      );
      final apps = await JobApplication.fetchFiltered(widget.server, widget.token, filter);
      if (mounted) {
        setState(() {
          _applications = apps;
          _isLoading = false;
        });
        _applyLocalSearch();
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = 'Could not load applications.'; });
    }
  }

  void _applyLocalSearch() {
    final q = _searchQuery.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_applications)
          : _applications.where((a) {
              final name = (a.candidateFullName ?? a.candidateUsername ?? '').toLowerCase();
              return name.contains(q);
            }).toList();
    });
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    _applyLocalSearch();
  }

  void _onStatusFilterChanged(String? status) {
    _statusFilter = status;
    _loadApplications(); // re-fetch with new server-side filter
  }

  Future<void> _handleUpdateStatus(JobApplication application, String status) async {
    try {
      await application.updateStatus(widget.server, widget.token, status);
      if (mounted) {
        setState(() {
          application.status = status;
          _applyLocalSearch();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update application status.')),
        );
      }
    }
  }

  Future<void> _openConversationWithCandidate(int candidateUserId) async {
    try {
      final conversation = await Conversation.createConversation(
        widget.server,
        widget.token,
        candidateUserId,
      );
      if (mounted) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open conversation.')),
        );
      }
    }
  }

  Future<void> _handleToggleActive() async {
    try {
      final updated = await _job.toggleActive(widget.server, widget.token);
      if (mounted) {
        setState(() => _job = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(updated.isActive ? 'Posting reactivated' : 'Posting deactivated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update job status.')),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete job posting'),
        content: Text('Are you sure you want to delete "${_job.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _job.delete(widget.server, widget.token);
      if (mounted) Navigator.of(context).pop(const _JobDetailResult(deleted: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete job posting.')),
        );
      }
    }
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JobFormSheet(
        existing: _job,
        onSubmit: (fields) async {
          try {
            final updated = await _job.update(
              widget.server, widget.token,
              title: fields['title'],
              description: fields['description'],
              requirements: fields['requirements'],
              contractType: fields['contractType'],
              location: fields['location'],
              salaryMin: fields['salaryMin'],
              salaryMax: fields['salaryMax'],
              isRemote: fields['isRemote'],
            );
            if (mounted) {
              Navigator.of(context).pop();
              setState(() => _job = updated);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not update job posting.')),
              );
            }
          }
        },
      ),
    );
  }

  //application card

  Color _statusColor(BuildContext context, String status) => switch (status) {
    'accepted' => Colors.green,
    'rejected' => Theme.of(context).colorScheme.error,
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };

  IconData _statusIcon(String status) => switch (status) {
    'accepted' => Icons.check_circle_outline,
    'rejected' => Icons.cancel_outlined,
    _ => Icons.hourglass_empty_outlined,
  };

  Widget _buildApplicationCard(JobApplication app) {
    final cs = Theme.of(context).colorScheme;
    final name = app.candidateFullName ?? app.candidateUsername ?? 'Candidate #${app.candidate}';
    final statusColor = _statusColor(context, app.status);
    final statusLabel = app.status[0].toUpperCase() + app.status.substring(1);
    final posted = _relativeTime(app.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: app.candidateUserId == null
                  ? null
                  : () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => UserProfileSheet(
                          userId: app.candidateUserId!,
                          server: widget.server,
                          token: widget.token,
                        ),
                      ),
              child: UserAvatar(
                avatarUrl: app.candidateAvatar,
                displayName: name,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Row(
                    children: [
                      Icon(_statusIcon(app.status), size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel, style: TextStyle(fontSize: 12, color: statusColor)),
                      if (posted != null) ...[
                        const SizedBox(width: 8),
                        Text('· $posted', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (app.status == 'pending')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    tooltip: 'Accept',
                    onPressed: () => _handleUpdateStatus(app, 'accepted'),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: cs.error),
                    tooltip: 'Reject',
                    onPressed: () => _handleUpdateStatus(app, 'rejected'),
                  ),
                ],
              ),
            if (app.status == 'accepted' && app.candidateUserId != null)
              IconButton(
                icon: Icon(Icons.chat_bubble_outline, color: cs.primary),
                tooltip: 'Message',
                onPressed: () => _openConversationWithCandidate(app.candidateUserId!),
              ),
          ],
        ),
      ),
    );
  }

  //job detail header

  Widget _buildJobHeader() {
    final cs = Theme.of(context).colorScheme;
    final salaryLabel = _formatSalary(_job.salaryMin, _job.salaryMax);

    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // active badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _job.isActive
                      ? Colors.green.withValues(alpha: 0.15)
                      : cs.onSurfaceVariant.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: _job.isActive ? Colors.green : cs.onSurfaceVariant.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      _job.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _job.isActive ? Colors.green.shade700 : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _contractTypeLabel(_job.contractType),
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_job.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              if (_job.location.isNotEmpty)
                _InlineMeta(icon: Icons.location_on_outlined, text: _job.location),
              if (_job.isRemote)
                const _InlineMeta(icon: Icons.wifi_outlined, text: 'Remote'),
            ],
          ),
          if (salaryLabel != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                salaryLabel,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text('Description', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(_job.description, style: Theme.of(context).textTheme.bodyMedium),
          if (_job.requirements.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Requirements', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(_job.requirements, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Pending count badge for AppBar
    final pendingCount = _applications.where((a) => a.status == 'pending').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_job.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Badge(
                label: Text('$pendingCount'),
                child: const Icon(Icons.inbox_outlined),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _showEditSheet();
              if (v == 'toggle') _handleToggleActive();
              if (v == 'delete') _handleDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  leading: Icon(_job.isActive ? Icons.toggle_off_outlined : Icons.toggle_on_outlined),
                  title: Text(_job.isActive ? 'Deactivate' : 'Reactivate'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outlined, color: cs.error),
                  title: Text('Delete', style: TextStyle(color: cs.error)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Job info header
          _buildJobHeader(),
          const Divider(height: 1),

          // Applications heading + search + filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Applications', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 8),
                    if (!_isLoading)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_applications.length}',
                          style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search applicants…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                // Status filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in {
                        null: 'All',
                        'pending': 'Pending',
                        'accepted': 'Accepted',
                        'rejected': 'Rejected',
                      }.entries) ...[
                        FilterChip(
                          label: Text(entry.value),
                          selected: _statusFilter == entry.key,
                          onSelected: (_) => _onStatusFilterChanged(entry.key),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Applications list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: TextStyle(color: cs.error)))
                    : _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  _applications.isEmpty ? 'No applications yet.' : 'No matching applicants.',
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadApplications,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(top: 8, bottom: 24),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => _buildApplicationCard(_filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InlineMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

class _ContractTypeSheet extends StatelessWidget {
  final String? current;
  const _ContractTypeSheet({this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text('Job type', style: Theme.of(context).textTheme.titleLarge),
          ),
          ..._kContractTypes.map(
            (type) => RadioListTile<String>(
              title: Text(_contractTypeLabel(type)),
              value: type,
              groupValue: current,
              onChanged: (v) => Navigator.of(context).pop(v),
            ),
          ),
          if (current != null)
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Clear'),
              onTap: () => Navigator.of(context).pop('__clear__'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LocationSheet extends StatefulWidget {
  final String? current;
  const _LocationSheet({this.current});

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current ?? '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Location', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'e.g. Athens, London…',
              prefixIcon: Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => Navigator.of(context).pop(_ctrl.text.trim()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
            child: const Text('Apply'),
          ),
          if (widget.current != null && widget.current!.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}

class _SalarySheet extends StatefulWidget {
  final int? currentMin;
  final int? currentMax;
  const _SalarySheet({this.currentMin, this.currentMax});

  @override
  State<_SalarySheet> createState() => _SalarySheetState();
}

class _SalarySheetState extends State<_SalarySheet> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(text: widget.currentMin?.toString() ?? '');
    _maxCtrl = TextEditingController(text: widget.currentMax?.toString() ?? '');
  }

  @override
  void dispose() { _minCtrl.dispose(); _maxCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Salary range (€)', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Min', prefixIcon: Icon(Icons.euro_outlined), border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _maxCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Max', prefixIcon: Icon(Icons.euro_outlined), border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final min = int.tryParse(_minCtrl.text.trim());
              final max = int.tryParse(_maxCtrl.text.trim());
              Navigator.of(context).pop((min: min, max: max));
            },
            child: const Text('Apply'),
          ),
          if (widget.currentMin != null || widget.currentMax != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop((min: null, max: null)),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}

class _ActiveSheet extends StatelessWidget {
  final bool? current;
  const _ActiveSheet({this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text('Posting status', style: Theme.of(context).textTheme.titleLarge),
          ),
          RadioListTile<String>(
            title: const Text('Active'),
            value: 'true',
            groupValue: current == true ? 'true' : null,
            onChanged: (v) => Navigator.of(context).pop(v),
          ),
          RadioListTile<String>(
            title: const Text('Inactive'),
            value: 'false',
            groupValue: current == false ? 'false' : null,
            onChanged: (v) => Navigator.of(context).pop(v),
          ),
          if (current != null)
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Clear'),
              onTap: () => Navigator.of(context).pop('__clear__'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// Job form sheet (create / edit)
class _JobFormSheet extends StatefulWidget {
  final JobPosting? existing;
  final Future<void> Function(Map<String, dynamic> fields) onSubmit;
  const _JobFormSheet({this.existing, required this.onSubmit});

  @override
  State<_JobFormSheet> createState() => _JobFormSheetState();
}

class _JobFormSheetState extends State<_JobFormSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _reqCtrl = TextEditingController();
  final _locCtrl = TextEditingController();
  final _salMinCtrl = TextEditingController();
  final _salMaxCtrl = TextEditingController();
  String _contractType = 'full_time';
  bool _isRemote = false;
  bool _isLoading = false;

  String _label(String type) => switch (type) {
    'full_time' => 'Full Time', 'part_time' => 'Part Time',
    'freelance' => 'Freelance', 'internship' => 'Internship', _ => type,
  };

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final j = widget.existing!;
      _titleCtrl.text = j.title;
      _descCtrl.text = j.description;
      _reqCtrl.text = j.requirements;
      _locCtrl.text = j.location;
      _salMinCtrl.text = j.salaryMin?.toString() ?? '';
      _salMaxCtrl.text = j.salaryMax?.toString() ?? '';
      _contractType = j.contractType;
      _isRemote = j.isRemote;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _reqCtrl.dispose();
    _locCtrl.dispose(); _salMinCtrl.dispose(); _salMaxCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    await widget.onSubmit({
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'requirements': _reqCtrl.text.trim(),
      'location': _locCtrl.text.trim(),
      'contractType': _contractType,
      'salaryMin': int.tryParse(_salMinCtrl.text.trim()),
      'salaryMax': int.tryParse(_salMaxCtrl.text.trim()),
      'isRemote': _isRemote,
    });
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (context, sc) => SingleChildScrollView(
        controller: sc,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Create job posting' : 'Edit job posting',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextField(controller: _titleCtrl, textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.work_outline))),
            const SizedBox(height: 16),
            TextField(controller: _descCtrl, maxLines: 4,
              decoration: const InputDecoration(labelText: 'Job description', alignLabelWithHint: true, prefixIcon: Icon(Icons.edit_outlined))),
            const SizedBox(height: 16),
            TextField(controller: _reqCtrl, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Requirements', alignLabelWithHint: true, prefixIcon: Icon(Icons.checklist_outlined))),
            const SizedBox(height: 16),
            TextField(controller: _locCtrl, textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on_outlined))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextField(controller: _salMinCtrl, keyboardType: TextInputType.number, textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Salary min (€)', prefixIcon: Icon(Icons.euro_outlined)))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _salMaxCtrl, keyboardType: TextInputType.number, textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Salary max (€)', prefixIcon: Icon(Icons.euro_outlined)))),
            ]),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _contractType,
              decoration: const InputDecoration(labelText: 'Contract type', prefixIcon: Icon(Icons.description_outlined)),
              items: _kContractTypes.map((t) => DropdownMenuItem(value: t, child: Text(_label(t)))).toList(),
              onChanged: (v) => setState(() => _contractType = v!),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _isRemote,
              onChanged: (v) => setState(() => _isRemote = v),
              title: const Text('Remote Position'),
              thumbColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.outline),
              trackColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.existing == null ? 'Post' : 'Save'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}