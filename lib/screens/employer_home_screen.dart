import 'package:flutter/material.dart';
import '../auth.dart';
import '../user.dart';
import '../job.dart';
import '../server.dart';
import '../filtering.dart';
import 'user_profile_sheet.dart';
import '../widgets/user_avatar.dart';

const _kContractTypes = ['full_time', 'part_time', 'freelance', 'internship'];

String _contractTypeLabel(String type) => switch (type) {
      'full_time' => 'Full-time',
      'part_time' => 'Part-time',
      'freelance' => 'Freelance',
      'internship' => 'Internship',
      _ => type,
    };

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
          widget.server, _employer.token, _filter);
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
      builder: (_) => _LocationSheet(current: _filter.location),
    );
    if (entered != null) {
      _applyFilter(
          _filter.copyWith(location: entered.isEmpty ? null : entered));
    }
  }

  void _showSalarySheet() async {
    final result = await showModalBottomSheet<({int? min, int? max})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SalarySheet(
          currentMin: _filter.salaryMin, currentMax: _filter.salaryMax),
    );
    if (result != null) {
      _applyFilter(
          _filter.copyWith(salaryMin: result.min, salaryMax: result.max));
    }
  }


  Widget _remoteChip() {
    final active = _filter.isRemote == true;
    return FilterChip(
      label: const Text('Remote'),
      selected: active,
      avatar: active ? null : const Icon(Icons.wifi_outlined, size: 16),
      onSelected: (_) =>
          _applyFilter(_filter.copyWith(isRemote: active ? null : true)),
    );
  }

  Widget _contractTypeChip() {
    final active = _filter.contractType != null;
    return FilterChip(
      label: Text(
          active ? _contractTypeLabel(_filter.contractType!) : 'Job type'),
      selected: active,
      avatar: active ? null : const Icon(Icons.work_outline, size: 16),
      onSelected: (_) => _showContractTypeSheet(),
      onDeleted: active
          ? () => _applyFilter(_filter.copyWith(contractType: null))
          : null,
    );
  }

  Widget _locationChip() {
    final active =
        _filter.location != null && _filter.location!.isNotEmpty;
    return FilterChip(
      label: Text(active ? _filter.location! : 'Location'),
      selected: active,
      avatar:
          active ? null : const Icon(Icons.location_on_outlined, size: 16),
      onSelected: (_) => _showLocationSheet(),
      onDeleted:
          active ? () => _applyFilter(_filter.copyWith(location: null)) : null,
    );
  }

  Widget _salaryChip() {
    final hasMin = _filter.salaryMin != null;
    final hasMax = _filter.salaryMax != null;
    final active = hasMin || hasMax;
    String label = 'Salary';
    if (hasMin && hasMax) {
      label = '€${_filter.salaryMin}–€${_filter.salaryMax}';
    } else if (hasMin) {
      label = '≥ €${_filter.salaryMin}';
    } else if (hasMax) {
      label = '≤ €${_filter.salaryMax}';
    }
    return FilterChip(
      label: Text(label),
      selected: active,
      avatar: active ? null : const Icon(Icons.euro_outlined, size: 16),
      onSelected: (_) => _showSalarySheet(),
      onDeleted: active
          ? () => _applyFilter(
              _filter.copyWith(salaryMin: null, salaryMax: null))
          : null,
    );
  }

  Widget _activeChip() {
    final active = _filter.isActive != null;
    String label = active
        ? (_filter.isActive == true ? 'Active' : 'Inactive')
        : 'Status';
    return FilterChip(
      label: Text(label),
      selected: active,
      avatar: active ? null : const Icon(Icons.toggle_on_outlined, size: 16),
      onSelected: (_) => _showActiveSheet(),
      onDeleted: active
          ? () => _applyFilter(_filter.copyWith(isActive: null))
          : null,
    );
  }

  void _showActiveSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _ActiveSheet(current: _filter.isActive),
    );
    if (selected != null) {
      _applyFilter(_filter.copyWith(
        isActive: selected == '__clear__'
            ? null
            : selected == 'true',
      ));
    }
  }


  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JobFormSheet(
        onSubmit: (fields) => _handleCreate(fields),
      ),
    );
  }

  void _showEditSheet(JobPosting job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JobFormSheet(
        existing: job,
        onSubmit: (fields) => _handleUpdate(job, fields),
      ),
    );
  }

  void _showApplicationsSheet(JobPosting job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ApplicationsSheet(
        job: job,
        server: widget.server,
        token: _employer.token,
      ),
    );
  }

  static String? _formatSalary(int? min, int? max) {
    if (min == null && max == null) return null;
    String fmt(int n) => '€${n.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        )}';
    if (min != null && max != null) return '${fmt(min)} – ${fmt(max)}';
    if (min != null) return '≥ ${fmt(min)}';
    return '≤ ${fmt(max!)}';
  }

  static String? _relativeTime(String iso) {
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
        onTap: () => _showApplicationsSheet(job),
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
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6, top: 2),
                          decoration: BoxDecoration(
                            color: job.isActive ? Colors.green : cs.onSurfaceVariant.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            job.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (posted != null)
                          Text(
                            posted,
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
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
                            _InlineMeta(
                              icon: Icons.location_on_outlined,
                              text: job.location,
                            ),
                          if (job.isRemote)
                            const _InlineMeta(
                              icon: Icons.wifi_outlined,
                              text: 'Remote',
                            ),
                          _InlineMeta(
                            icon: Icons.work_history_outlined,
                            text: _contractTypeLabel(job.contractType),
                          ),
                        ],
                      ),
                    ),
                    if (salaryLabel != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          salaryLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
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

  Future<void> _handleCreate(Map<String, dynamic> fields) async {
    try {
      final newJob = await JobPosting.create(
        widget.server,
        _employer.token,
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

  Future<void> _handleUpdate(
      JobPosting job, Map<String, dynamic> fields) async {
    try {
      final updated = await job.update(
        widget.server,
        _employer.token,
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
          final index = _jobs.indexWhere((j) => j.id == job.id);
          if (index != -1) _jobs[index] = updated;
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

  Future<void> _handleDelete(JobPosting job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete job posting'),
        content: Text('Are you sure you want to delete "${job.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
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

  void _showLongPressMenu(JobPosting job) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(job.isActive
                  ? Icons.toggle_off_outlined
                  : Icons.toggle_on_outlined),
              title: Text(job.isActive ? 'Deactivate' : 'Reactivate'),
              onTap: () {
                Navigator.of(context).pop();
                _handleToggleActive(job);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(context).pop();
                _showEditSheet(job);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outlined,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.of(context).pop();
                _handleDelete(job);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleToggleActive(JobPosting job) async {
    try {
      final updated = await job.toggleActive(widget.server, _employer.token);
      if (mounted) {
        setState(() {
          final index = _jobs.indexWhere((j) => j.id == job.id);
          if (index != -1) _jobs[index] = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updated.isActive
                ? '"${updated.title}" reactivated'
                : '"${updated.title}" deactivated'),
          ),
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
                      onPressed: () => _applyFilter(
                          JobPostingFilter(title: _filter.title)),
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

            // job list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error)))
                      : _jobs.isEmpty
                          ? _buildEmptyState(context)
                          : RefreshIndicator(
                              onRefresh: _loadJobs,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _jobs.length,
                                itemBuilder: (context, index) =>
                                    _buildJobCard(context, _jobs[index]),
                              ),
                            ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: _showCreateSheet,
            child: const Icon(Icons.add),
          ),
        ),
      ],
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
            child: Text('Job type',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          ..._kContractTypes.map((type) => RadioListTile<String>(
                title: Text(_contractTypeLabel(type)),
                value: type,
                groupValue: current,
                onChanged: (v) => Navigator.of(context).pop(v),
              )),
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
    _minCtrl =
        TextEditingController(text: widget.currentMin?.toString() ?? '');
    _maxCtrl =
        TextEditingController(text: widget.currentMax?.toString() ?? '');
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Salary range (€)',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Min',
                    prefixIcon: Icon(Icons.euro_outlined),
                    border: OutlineInputBorder(),
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
                    labelText: 'Max',
                    prefixIcon: Icon(Icons.euro_outlined),
                    border: OutlineInputBorder(),
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
              onPressed: () =>
                  Navigator.of(context).pop((min: null, max: null)),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}

// Active/Inactive picker

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
            child: Text('Posting status',
                style: Theme.of(context).textTheme.titleLarge),
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

// Job form sheet

class _JobFormSheet extends StatefulWidget {
  final JobPosting? existing;
  final Future<void> Function(Map<String, dynamic> fields) onSubmit;

  const _JobFormSheet({this.existing, required this.onSubmit});

  @override
  State<_JobFormSheet> createState() => _JobFormSheetState();
}

class _JobFormSheetState extends State<_JobFormSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryMinController = TextEditingController();
  final _salaryMaxController = TextEditingController();

  String _contractType = 'full_time';
  bool _isRemote = false;
  bool _isLoading = false;

  String _contractTypeLabel(String type) => switch (type) {
        'full_time' => 'Full Time',
        'part_time' => 'Part Time',
        'freelance' => 'Freelance',
        'internship' => 'Internship',
        _ => type,
      };

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final job = widget.existing!;
      _titleController.text = job.title;
      _descriptionController.text = job.description;
      _requirementsController.text = job.requirements;
      _locationController.text = job.location;
      _salaryMinController.text = job.salaryMin?.toString() ?? '';
      _salaryMaxController.text = job.salaryMax?.toString() ?? '';
      _contractType = job.contractType;
      _isRemote = job.isRemote;
    }
  }

  Future<void> _handleSubmit() async {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Title and description are required.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    await widget.onSubmit({
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'requirements': _requirementsController.text.trim(),
      'location': _locationController.text.trim(),
      'contractType': _contractType,
      'salaryMin': int.tryParse(_salaryMinController.text.trim()),
      'salaryMax': int.tryParse(_salaryMaxController.text.trim()),
      'isRemote': _isRemote,
    });
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? 'Create job posting'
                    : 'Edit job posting',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.work_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Job description',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _requirementsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Requirements',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.checklist_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _locationController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _salaryMinController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Salary min (€)',
                        prefixIcon: Icon(Icons.euro_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _salaryMaxController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Salary max (€)',
                        prefixIcon: Icon(Icons.euro_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _contractType,
                decoration: const InputDecoration(
                  labelText: 'Contract type',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                items: _kContractTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(_contractTypeLabel(type)),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _contractType = value!),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _isRemote,
                onChanged: (value) => setState(() => _isRemote = value),
                title: const Text('Remote position'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        widget.existing == null ? 'Post' : 'Save'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _locationController.dispose();
    _salaryMinController.dispose();
    _salaryMaxController.dispose();
    super.dispose();
  }
}

// Applications sheet

class _ApplicationsSheet extends StatefulWidget {
  final JobPosting job;
  final Server server;
  final String token;

  const _ApplicationsSheet({
    required this.job,
    required this.server,
    required this.token,
  });

  @override
  State<_ApplicationsSheet> createState() => _ApplicationsSheetState();
}

class _ApplicationsSheetState extends State<_ApplicationsSheet> {
  List<JobApplication> _applications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    try {
      final filter = JobApplicationFilter(job: widget.job.id);
      final applications = await JobApplication.fetchFiltered(
          widget.server, widget.token, filter);
      if (mounted) {
        setState(() {
          _applications = applications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not load applications.';
        });
      }
    }
  }

  Future<void> _handleUpdateStatus(
      JobApplication application, String status) async {
    try {
      await application.updateStatus(widget.server, widget.token, status);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not update application status.')),
        );
      }
    }
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Applications: ${widget.job.title}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error)))
                      : _applications.isEmpty
                          ? const Center(
                              child: Text('No applications yet.'))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _applications.length,
                              itemBuilder: (context, index) {
                                final application =
                                    _applications[index];
                                return ListTile(
                                  leading: GestureDetector(
                                    onTap: () => showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => UserProfileSheet(
                                        userId: application
                                            .candidateUserId!,
                                        server: widget.server,
                                        token: widget.token,
                                      ),
                                    ),
                                    child: UserAvatar(
                                      avatarUrl:
                                          application.candidateAvatar,
                                      displayName: application
                                              .candidateFullName ??
                                          application
                                              .candidateUsername ??
                                          '',
                                    ),
                                  ),
                                  title: Text(application
                                          .candidateFullName ??
                                      application.candidateUsername ??
                                      'Candidate #${application.candidate}'),
                                  subtitle: Text(
                                    application.status[0].toUpperCase() +
                                        application.status.substring(1),
                                    style: TextStyle(
                                        color: _statusColor(context,
                                            application.status)),
                                  ),
                                  trailing: application.status ==
                                          'pending'
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.check,
                                                  color: Colors.green),
                                              tooltip: 'Accept',
                                              onPressed: () =>
                                                  _handleUpdateStatus(
                                                      application,
                                                      'accepted'),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.close,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error),
                                              tooltip: 'Reject',
                                              onPressed: () =>
                                                  _handleUpdateStatus(
                                                      application,
                                                      'rejected'),
                                            ),
                                          ],
                                        )
                                      : null,
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}