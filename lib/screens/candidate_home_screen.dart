import 'package:flutter/material.dart';
import '../auth.dart';
import '../user.dart';
import '../job.dart';
import '../server.dart';
import '../filtering.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';
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

  
  Widget _remoteChip() {
    final active = _filter.isRemote == true;
    return FilterChip(
      label: const Text('Remote', style: TextStyle(fontSize: 13)),
      selected: active,
      avatar: active ? null : const Icon(Icons.wifi_outlined, size: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        _applyFilter(_filter.copyWith(isRemote: active ? null : true));
      },
    );
  }

  Widget _contractTypeChip() {
    final active = _filter.contractType != null;
    return FilterChip(
      label: Text(
        active ? _contractTypeLabel(_filter.contractType!) : 'Job type',
        style: const TextStyle(fontSize: 13),
      ),
      selected: active,
      avatar: active ? null : const Icon(Icons.work_outline, size: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => _showContractTypeSheet(),
      onDeleted: active
          ? () => _clearFilter(_filter.copyWith(contractType: null))
          : null,
    );
  }

  Widget _locationChip() {
    final active = _filter.location != null && _filter.location!.isNotEmpty;
    return FilterChip(
      label: Text(
        active ? _filter.location! : 'Location',
        style: const TextStyle(fontSize: 13),
      ),
      selected: active,
      avatar: active ? null : const Icon(Icons.location_on_outlined, size: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      visualDensity: VisualDensity.compact,
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
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: active,
      avatar: active ? null : const Icon(Icons.euro_outlined, size: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => _showSalarySheet(),
      onDeleted: active
          ? () => _clearFilter(_filter.copyWith(salaryMin: null, salaryMax: null))
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
              if (activeFilterCount > 0) ...[
                ActionChip(
                  avatar: const Icon(Icons.close, size: 16),
                  label: Text('Clear ($activeFilterCount)'),
                  onPressed: () {
                    _applyFilter(JobPostingFilter(
                      title: _filter.title,
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
        const Divider(height: 1, color: AppTheme.divider),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _error != null
                  ? Center(
                      child: Text(_error!,
                          style: const TextStyle(color: AppTheme.error)))
                  : _jobs.isEmpty
                      ? Center(
                          child: Text(
                            widget.searchQuery.isEmpty && _filter.isEmpty
                                ? 'No job postings available.'
                                : 'No results for your current filters.',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppTheme.primary,
                          onRefresh: _loadJobs,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemCount: _jobs.length,
                            itemBuilder: (context, index) {
                              final job = _jobs[index];
                              return _JobCard(
                                job: job,
                                onTap: () => _showJobDetails(job),
                                onApply: () => _handleApply(job),
                              );
                            },
                          ),
                        ),
        ),
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

class _JobCard extends StatelessWidget {
  final JobPosting job;
  final VoidCallback onTap;
  final VoidCallback onApply;

  const _JobCard({required this.job, required this.onTap, required this.onApply});

  String get _salaryText {
    if (job.salaryMin == null && job.salaryMax == null) return '';
    if (job.salaryMin != null && job.salaryMax != null) return '€${job.salaryMin}–€${job.salaryMax}';
    if (job.salaryMin != null) return '≥€${job.salaryMin}';
    return '≤€${job.salaryMax}';
  }

  String get _contractLabel => _contractTypeLabel(job.contractType);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.cardDecoration(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP ROW: avatar + company name + timestamp
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    job.title.isNotEmpty ? job.title[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Company #${job.employer}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  job.createdAt.substring(0, 10).split('-').reversed.join('/'),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Job title
            Text(
              job.title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Pill tags
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (job.location.isNotEmpty)
                  _PillTag(icon: Icons.location_on_outlined, text: job.location),
                if (job.isRemote)
                  const _PillTag(icon: Icons.wifi_outlined, text: 'Remote'),
                _PillTag(icon: Icons.work_outline, text: _contractLabel),
                if (_salaryText.isNotEmpty)
                  _PillTag(icon: Icons.euro_outlined, text: _salaryText),
              ],
            ),
            const SizedBox(height: 12),
            // BOTTOM ROW: Save + Apply
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.bookmark_outline, color: AppTheme.textSecondary, size: 20),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: FilledButton(
                    onPressed: onApply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Apply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillTag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PillTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: AppTheme.pillTagDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}