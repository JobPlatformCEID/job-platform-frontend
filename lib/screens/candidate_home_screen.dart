import 'package:flutter/material.dart';
import '../auth.dart';
import '../user.dart';
import '../job.dart';
import '../server.dart';

class CandidateHomeScreen extends StatefulWidget {
  final Auth auth;
  final Server server;

  const CandidateHomeScreen({super.key, required this.auth, required this.server});

  @override
  State<CandidateHomeScreen> createState() => _CandidateHomeScreenState();
}

class _CandidateHomeScreenState extends State<CandidateHomeScreen> {
  List<JobPosting> _jobs = [];
  bool _isLoading = true;
  String? _error;

  Candidate get _candidate => widget.auth.user as Candidate;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    try {
      final jobs = await JobPosting.fetchAll(widget.server, _candidate.token);
      if (mounted) setState(() {
        _jobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load job postings.';
      });
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
          const SnackBar(content: Text('Could not apply. You may have already applied.')),
        );
      }
    }
  }

  void _showJobDetails(JobPosting job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JobDetailSheet(
        job: job,
        onApply: () => _handleApply(job),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)));

    if (_jobs.isEmpty) {
      return const Center(child: Text('No job postings available.'));
    }

    return RefreshIndicator(
      onRefresh: _loadJobs,
      child: ListView.builder(
        itemCount: _jobs.length,
        itemBuilder: (context, index) {
          final job = _jobs[index];
          return ListTile(
            title: Text(job.title),
            subtitle: Text(
              [
                if (job.location.isNotEmpty) job.location,
                if (job.isRemote) 'Remote',
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showJobDetails(job),
          );
        },
      ),
    );
  }
}

class _JobDetailSheet extends StatelessWidget {
  final JobPosting job;
  final VoidCallback onApply;

  const _JobDetailSheet({required this.job, required this.onApply});

  String get _salaryText {
    if (job.salaryMin == null && job.salaryMax == null) return 'Not specified';
    if (job.salaryMin != null && job.salaryMax != null) {
      return '€${job.salaryMin} – €${job.salaryMax}';
    }
    if (job.salaryMin != null) return 'From €${job.salaryMin}';
    return 'Up to €${job.salaryMax}';
  }

  String get _contractTypeText {
    switch (job.contractType) {
      case 'full_time': return 'Full Time';
      case 'part_time': return 'Part Time';
      case 'freelance': return 'Freelance';
      case 'internship': return 'Internship';
      default: return job.contractType;
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
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                job.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (job.location.isNotEmpty) ...[
                    const Icon(Icons.location_on_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(job.isRemote ? '${job.location} (Remote)' : job.location,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ] else if (job.isRemote) ...[
                    const Icon(Icons.location_on_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text('Remote', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(width: 12),
                  Chip(label: Text(_contractTypeText)),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(context, 'Description', job.description),
              if (job.requirements.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSection(context, 'Requirements', job.requirements),
              ],
              const SizedBox(height: 16),
              _buildSection(context, 'Salary', _salaryText),
              const SizedBox(height: 16),
              _buildSection(
                context,
                'Posted',
                job.createdAt.substring(0, 10).split('-').reversed.join('/'),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: onApply,
                child: const Text('Apply'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(content, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}