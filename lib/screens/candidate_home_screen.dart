import 'package:flutter/material.dart';
import '../server_api/auth.dart';
import '../server_api/user.dart';
import '../server_api/job.dart';
import '../server_api/server.dart';
import '../server_api/filtering.dart';
import 'job_detail_sheet.dart';
import 'candidate_applications_screen.dart';

// Contract type options – keep in sync with your backend choices.
const _kContractTypes = ['full_time', 'part_time', 'internship', 'freelance'];

String _contractTypeLabel(String type) => switch (type) {
      'full_time' => 'Full-time',
      'part_time' => 'Part-time',
      'internship' => 'Internship',
      'freelance' => 'Freelance',
      _ => type,
    };

class CandidateHomeScreen extends StatefulWidget {
  final Auth auth;
  final Server server;
  final String searchQuery;

  const CandidateHomeScreen({
    super.key,
    required this.auth,
    required this.server,
    required this.searchQuery,
  });

  @override
  State<CandidateHomeScreen> createState() => _CandidateHomeScreenState();
}

class _CandidateHomeScreenState extends State<CandidateHomeScreen> {
  List<JobPosting> _jobs = [];
  bool _isLoading = true;
  String? _error;
  JobPostingFilter _filter = const JobPostingFilter();

  Candidate get _candidate => widget.auth.user as Candidate;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final jobs = await JobPosting.fetchFiltered(
          widget.server, _candidate.token, _filter);
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
          _error = 'Could not load job postings.';
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant CandidateHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      _filter = _filter.copyWith(
        title: widget.searchQuery.isEmpty ? null : widget.searchQuery,
      );
      _loadJobs();
    }
  }

  // filter helpers 

  void _applyFilter(JobPostingFilter updated) {
    setState(() => _filter = updated);
    _loadJobs();
  }

  void _clearFilter(JobPostingFilter updated) => _applyFilter(updated);

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
      _applyFilter(_filter.copyWith(
        location: entered.isEmpty ? null : entered,
      ));
    }
  }

  void _showSalarySheet() async {
    final result = await showModalBottomSheet<({int? min, int? max})>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _SalarySheet(currentMin: _filter.salaryMin, currentMax: _filter.salaryMax),
    );
    if (result != null) {
      _applyFilter(_filter.copyWith(
        salaryMin: result.min,
        salaryMax: result.max,
      ));
    }
  }

  
  Future<void> _handleApply(JobPosting job) async {
    try {
      await job.apply(widget.server, _candidate.token);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Could not apply. You may have already applied.')),
        );
      }
    }
  }

  void _showJobDetails(JobPosting job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => JobDetailSheet(
        job: job,
        onApply: () => _handleApply(job),
      ),
    );
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
              filtered ? 'No matching jobs' : 'No job postings yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Try widening your filters or search.'
                  : 'Check back soon — new postings appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            if (filtered) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _applyFilter(JobPostingFilter(title: _filter.title)),
                icon: const Icon(Icons.clear),
                label: const Text('Clear filters'),
              ),
            ],
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
        onTap: () => _showJobDetails(job),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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

  
  Widget _remoteChip() {
    final active = _filter.isRemote == true;
    return FilterChip(
      label: const Text('Remote'),
      selected: active,
      avatar: active ? null : const Icon(Icons.wifi_outlined, size: 16),
      onSelected: (_) {
        _applyFilter(_filter.copyWith(isRemote: active ? null : true));
      },
    );
  }

  Widget _contractTypeChip() {
    final active = _filter.contractType != null;
    return FilterChip(
      label:
          Text(active ? _contractTypeLabel(_filter.contractType!) : 'Job type'),
      selected: active,
      avatar: active
          ? null
          : const Icon(Icons.work_outline, size: 16),
      onSelected: (_) => _showContractTypeSheet(),
      onDeleted: active
          ? () => _clearFilter(
              _filter.copyWith(contractType: null))
          : null,
    );
  }

  Widget _locationChip() {
    final active =
        _filter.location != null && _filter.location!.isNotEmpty;
    return FilterChip(
      label: Text(active ? _filter.location! : 'Location'),
      selected: active,
      avatar: active
          ? null
          : const Icon(Icons.location_on_outlined, size: 16),
      onSelected: (_) => _showLocationSheet(),
      onDeleted: active
          ? () => _clearFilter(_filter.copyWith(location: null))
          : null,
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
          ? () => _clearFilter(
              _filter.copyWith(salaryMin: null, salaryMax: null))
          : null,
    );
  }

  
  @override
  Widget build(BuildContext context) {
    final activeFilterCount = [
      _filter.isRemote != null,
      _filter.contractType != null,
      _filter.location?.isNotEmpty == true,
      _filter.salaryMin != null || _filter.salaryMax != null,
    ].where((b) => b).length;

    return Column(
      children: [
        
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Applications shortcut
              ActionChip(
                avatar: const Icon(Icons.assignment_outlined, size: 16),
                label: const Text('My Applications'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CandidateApplicationsScreen(
                        auth: widget.auth,
                        server: widget.server,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              // "All filters" clear button shown only when something is active
              if (activeFilterCount > 0) ...[
                ActionChip(
                  avatar: const Icon(Icons.close, size: 16),
                  label: Text('Clear ($activeFilterCount)'),
                  onPressed: () {
                    _applyFilter(JobPostingFilter(
                      title: _filter.title, // keep the search query
                    ));
                  },
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
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(_error!,
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.error)))
                  : _jobs.isEmpty
                      ? _buildEmptyState(context)
                      : RefreshIndicator(
                          onRefresh: _loadJobs,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _jobs.length,
                            itemBuilder: (context, index) =>
                                _buildJobCard(context, _jobs[index]),
                          ),
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
          ..._kContractTypes.map((type) {
            final label = _contractTypeLabel(type);
            return RadioListTile<String>(
              title: Text(label),
              value: type,
              groupValue: current,
              onChanged: (v) => Navigator.of(context).pop(v),
            );
          }),
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

// Location input sheet

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
            onSubmitted: (_) =>
                Navigator.of(context).pop(_ctrl.text.trim()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_ctrl.text.trim()),
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

// Salary range sheet 

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
    _minCtrl = TextEditingController(
        text: widget.currentMin?.toString() ?? '');
    _maxCtrl = TextEditingController(
        text: widget.currentMax?.toString() ?? '');
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