import 'package:flutter/material.dart';
import '../auth.dart';
import '../user.dart';
import '../job.dart';
import '../server.dart';

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

  Employer get _employer => widget.auth.user as Employer;

  // Filters the employer's job list by the search query from HomeScreen
  List<JobPosting> get _filteredJobs {
    if (widget.searchQuery.isEmpty) return _jobs;
    final query = widget.searchQuery.toLowerCase();
    return _jobs.where((job) => job.title.toLowerCase().contains(query)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    try {
      // fetchProfile first to ensure employerProfileId is populated
      if (_employer.employerProfileId == null) {
        await _employer.fetchProfile();
      }
      final allJobs = await JobPosting.fetchAll(widget.server, _employer.token);
      if (mounted) setState(() {
        _jobs = allJobs.where((j) => j.employer == _employer.employerProfileId).toList();   // TODO 1: Make this filtering happen server-side
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = e.toString();
      });
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

  Future<void> _handleUpdate(JobPosting job, Map<String, dynamic> fields) async {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)));

    final jobs = _filteredJobs;

    return Stack(
      children: [
        if (jobs.isEmpty)
          Center(
            child: Text(
              widget.searchQuery.isEmpty
                  ? 'No job postings yet. Tap + to create one.'
                  : 'No results for "${widget.searchQuery}".',
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _loadJobs,
            child: ListView.separated(
              separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return ListTile(
                  title: Text(job.title),
                  subtitle: Text(
                    [
                      if (job.location.isNotEmpty) job.location,
                      if (job.isRemote) 'Remote',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showApplicationsSheet(job),
                  onLongPress: () => _showLongPressMenu(job),
                );
              },
            ),
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

  void _showLongPressMenu(JobPosting job) {
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
                _showEditSheet(job);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outlined, color: Theme.of(context).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
}

// Bottom sheet for creating or editing a job posting
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

  final List<String> _contractTypes = ['full_time', 'part_time', 'freelance', 'internship'];

  String _contractTypeLabel(String type) {
    switch (type) {
      case 'full_time': return 'Full Time';
      case 'part_time': return 'Part Time';
      case 'freelance': return 'Freelance';
      case 'internship': return 'Internship';
      default: return type;
    }
  }

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
    if (_titleController.text.trim().isEmpty || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required.')),
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
                widget.existing == null ? 'Create job posting' : 'Edit job posting',
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
                items: _contractTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(_contractTypeLabel(type)),
                )).toList(),
                onChanged: (value) => setState(() => _contractType = value!),
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
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(widget.existing == null ? 'Post' : 'Save'),
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

// Bottom sheet showing applications for a job posting
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
      final all = await JobApplication.fetchApplications(widget.server, widget.token);
      if (mounted) setState(() {
         // TODO: Maybe we should add a server-side endpoint to get all applications for each job
        _applications = all.where((a) => a.job == widget.job.id).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load applications.';
      });
    }
  }

  Future<void> _handleUpdateStatus(JobApplication application, String status) async {
    try {
      await application.updateStatus(widget.server, widget.token, status);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update application status.')),
        );
      }
    }
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'accepted': return Colors.green;
      case 'rejected': return Theme.of(context).colorScheme.error;
      default: return Theme.of(context).colorScheme.onSurfaceVariant;
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
                      ? Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
                      : _applications.isEmpty
                          ? const Center(child: Text('No applications yet.'))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _applications.length,
                              itemBuilder: (context, index) {
                                final application = _applications[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    child: Icon(
                                      Icons.person_outline,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                  title: Text(application.candidateFullName ?? application.candidateUsername ?? 'Candidate #${application.candidate}'),
                                  subtitle: Text(
                                    application.status[0].toUpperCase() + application.status.substring(1),
                                    style: TextStyle(color: _statusColor(context, application.status)),
                                  ),
                                  trailing: application.status == 'pending'
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.check, color: Colors.green),
                                              tooltip: 'Accept',
                                              onPressed: () => _handleUpdateStatus(application, 'accepted'),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.close, color: Theme.of(context).colorScheme.error),
                                              tooltip: 'Reject',
                                              onPressed: () => _handleUpdateStatus(application, 'rejected'),
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