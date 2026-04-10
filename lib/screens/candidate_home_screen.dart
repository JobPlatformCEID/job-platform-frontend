import 'package:flutter/material.dart';
import '../auth.dart';
import '../user.dart';
import '../job.dart';
import '../server.dart';
import 'job_detail_sheet.dart';

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

  Candidate get _candidate => widget.auth.user as Candidate;

  // Filters the full job list by the search query from HomeScreen
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
      builder: (_) => JobDetailSheet(
        job: job,
        onApply: () => _handleApply(job),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)));

    final jobs = _filteredJobs;

    if (jobs.isEmpty) {
      return Center(
        child: Text(
          widget.searchQuery.isEmpty ? 'No job postings available.' : 'No results for "${widget.searchQuery}".',
        ),
      );
    }

    return RefreshIndicator(
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
            onTap: () => _showJobDetails(job),
          );
        },
      ),
    );
  }
}
