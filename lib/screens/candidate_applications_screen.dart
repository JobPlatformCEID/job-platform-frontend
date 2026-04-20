import 'package:flutter/material.dart';
import '../auth.dart';
import '../server.dart';
import '../job.dart';
import '../filtering.dart';
import 'job_detail_sheet.dart';
import 'company_profile_sheet.dart';

const _kContractTypes = ['full_time', 'part_time', 'internship', 'freelance'];

String _contractTypeLabel(String type) => switch (type) {
      'full_time' => 'Full-time',
      'part_time' => 'Part-time',
      'internship' => 'Internship',
      'freelance' => 'Freelance',
      _ => type,
    };

class CandidateApplicationsScreen extends StatefulWidget {
  final Auth auth;
  final Server server;

  const CandidateApplicationsScreen({
    super.key,
    required this.auth,
    required this.server,
  });

  @override
  State<CandidateApplicationsScreen> createState() =>
      _CandidateApplicationsScreenState();
}

class _CandidateApplicationsScreenState
    extends State<CandidateApplicationsScreen> {
  List<JobApplication> _applications = [];
  bool _isLoading = true;
  String? _error;
  JobApplicationFilter _filter = const JobApplicationFilter();
  final _statusOptions = ['All', 'Pending', 'Accepted', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    try {
      final applications = await JobApplication.fetchFiltered(
        widget.server,
        widget.auth.user!.token,
        _filter,
      );
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

  void _onStatusSelected(String status) {
    setState(() {
      _filter = _filter.copyWith(
        status: status == 'All' ? null : status.toLowerCase(),
      );
    });
    _loadApplications();
  }

  void _applyFilter(JobApplicationFilter updated) {
    setState(() => _filter = updated);
    _loadApplications();
  }

  /// Count of non-status active filters (for the badge on the Filters button).
  int get _extraFilterCount {
    return [
      _filter.jobIsRemote != null,
      _filter.jobContractType?.isNotEmpty == true,
      _filter.jobLocation?.isNotEmpty == true,
    ].where((b) => b).length;
  }

  void _showAllFiltersSheet() async {
    final result = await showModalBottomSheet<JobApplicationFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ApplicationFiltersSheet(current: _filter),
    );
    if (result != null) _applyFilter(result);
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_empty_outlined;
    }
  }

  String _selectedStatus() {
    if (_filter.status == null) return 'All';
    return _filter.status![0].toUpperCase() + _filter.status!.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
        actions: [
          // "All Filters" button – shows a badge when extra filters are active
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Filters',
                onPressed: _showAllFiltersSheet,
              ),
              if (_extraFilterCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_extraFilterCount',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)))
              : Column(
                  children: [
                    Container(
                      height: 56,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _statusOptions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final status = _statusOptions[index];
                          final isSelected =
                              _selectedStatus() == status;
                          return ChoiceChip(
                            label: Text(status),
                            selected: isSelected,
                            onSelected: (_) =>
                                _onStatusSelected(status),
                          );
                        },
                      ),
                    ),

                    if (_extraFilterCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            if (_filter.jobIsRemote == true)
                              _summaryChip('Remote', () => _applyFilter(
                                  _filter.copyWith(jobIsRemote: null))),
                            if (_filter.jobContractType?.isNotEmpty ==
                                true)
                              _summaryChip(
                                  _contractTypeLabel(
                                      _filter.jobContractType!),
                                  () => _applyFilter(_filter.copyWith(
                                      jobContractType: null))),
                            if (_filter.jobLocation?.isNotEmpty == true)
                              _summaryChip(_filter.jobLocation!,
                                  () => _applyFilter(_filter.copyWith(
                                      jobLocation: null))),
                          ],
                        ),
                      ),

                    const Divider(height: 1),

                    Expanded(
                      child: _applications.isEmpty
                          ? const Center(
                              child: Text('No applications found.'))
                          : RefreshIndicator(
                              onRefresh: _loadApplications,
                              child: ListView.separated(
                                itemCount: _applications.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(
                                        indent: 16, endIndent: 16),
                                itemBuilder: (context, index) {
                                  final application =
                                      _applications[index];
                                  final status = application.status;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      child: Icon(Icons.work_outline,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer),
                                    ),
                                    title: Text(application.jobTitle ??
                                        'Job #${application.job}'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (application.companyName !=
                                            null)
                                          Text(application.companyName!),
                                        Text(
                                          status[0].toUpperCase() +
                                              status.substring(1),
                                          style: TextStyle(
                                              color: _statusColor(
                                                  context, status)),
                                        ),
                                      ],
                                    ),
                                    trailing: Icon(
                                      _statusIcon(status),
                                      color:
                                          _statusColor(context, status),
                                    ),
                                    onTap: () =>
                                        Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            _ApplicationDetailScreen(
                                          application: application,
                                          server: widget.server,
                                          token:
                                              widget.auth.user!.token,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _summaryChip(String label, VoidCallback onDelete) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(label,
            style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onDelete,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// All-filters bottom sheet 

class _ApplicationFiltersSheet extends StatefulWidget {
  final JobApplicationFilter current;
  const _ApplicationFiltersSheet({required this.current});

  @override
  State<_ApplicationFiltersSheet> createState() =>
      _ApplicationFiltersSheetState();
}

class _ApplicationFiltersSheetState
    extends State<_ApplicationFiltersSheet> {
  late bool? _isRemote;
  late String? _contractType;
  late TextEditingController _locationCtrl;

  @override
  void initState() {
    super.initState();
    _isRemote = widget.current.jobIsRemote;
    _contractType = widget.current.jobContractType;
    _locationCtrl =
        TextEditingController(text: widget.current.jobLocation ?? '');
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('All filters',
                        style:
                            Theme.of(context).textTheme.headlineSmall),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isRemote = null;
                        _contractType = null;
                        _locationCtrl.clear();
                      });
                    },
                    child: const Text('Clear all'),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  // Remote toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remote only'),
                    subtitle: const Text('Show only remote positions'),
                    value: _isRemote == true,
                    onChanged: (v) =>
                        setState(() => _isRemote = v ? true : null),
                  ),
                  const Divider(),

                  // Contract type
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Job type',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Wrap(
                    spacing: 8,
                    children: _kContractTypes.map((type) {
                      final selected = _contractType == type;
                      return FilterChip(
                        label: Text(_contractTypeLabel(type)),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _contractType = selected ? null : type;
                        }),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 32),

                  // Location
                  Text('Location',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Athens, London…',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            // Apply button
            Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: FilledButton(
                onPressed: () {
                  final loc = _locationCtrl.text.trim();
                  Navigator.of(context).pop(
                    widget.current.copyWith(
                      jobIsRemote: _isRemote,
                      jobContractType: _contractType,
                      jobLocation: loc.isEmpty ? null : loc,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: const Text('Show results'),
              ),
            ),
          ],
        );
      },
    );
  }
}

//Application detail screen 

class _ApplicationDetailScreen extends StatefulWidget {
  final JobApplication application;
  final Server server;
  final String token;

  const _ApplicationDetailScreen({
    required this.application,
    required this.server,
    required this.token,
  });

  @override
  State<_ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState
    extends State<_ApplicationDetailScreen> {
  JobPosting? _job;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJob();
  }

  Future<void> _loadJob() async {
    try {
      final job = await JobPosting.fetchById(
          widget.server, widget.token, widget.application.job);
      if (mounted) {
        setState(() {
          _job = job;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showJobDetail() {
    if (_job == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => JobDetailSheet(job: _job!),
    );
  }

  void _showCompanyProfile() {
    if (widget.application.employerId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CompanyProfileSheet(
        profileId: widget.application.employerId!,
        server: widget.server,
        token: widget.token,
      ),
    );
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
    final status = widget.application.status;
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.application.jobTitle ?? 'Application Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        _statusColor(context, status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _statusColor(context, status)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: _statusColor(context, status)),
                      const SizedBox(width: 12),
                      Text(
                        'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                        style: TextStyle(
                          color: _statusColor(context, status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _job != null ? _showJobDetail : null,
                  icon: const Icon(Icons.work_outline),
                  label: const Text('Link to job posting'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: widget.application.employerId != null
                      ? _showCompanyProfile
                      : null,
                  icon: const Icon(Icons.business_outlined),
                  label: Text(
                      widget.application.companyName ?? 'Company profile'),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.7),
                        Theme.of(context)
                            .colorScheme
                            .tertiary
                            .withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.psychology_outlined,
                                color: Colors.white),
                            const SizedBox(width: 12),
                            const Text(
                              'Mock AI Interview',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Soon',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}