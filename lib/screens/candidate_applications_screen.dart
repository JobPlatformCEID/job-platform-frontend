import 'package:flutter/material.dart';
import '../auth.dart';
import '../server.dart';
import '../job.dart';
import 'job_detail_sheet.dart';
import 'company_profile_sheet.dart';

class CandidateApplicationsScreen extends StatefulWidget {
  final Auth auth;
  final Server server;

  const CandidateApplicationsScreen({
    super.key,
    required this.auth,
    required this.server,
  });

  @override
  State<CandidateApplicationsScreen> createState() => _CandidateApplicationsScreenState();
}

class _CandidateApplicationsScreenState extends State<CandidateApplicationsScreen> {
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
      final applications = await JobApplication.fetchApplications(
        widget.server,
        widget.auth.user!.token,
      );
      if (mounted) setState(() {
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load applications.';
      });
    }
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'accepted': return Colors.green;
      case 'rejected': return Theme.of(context).colorScheme.error;
      default: return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'accepted': return Icons.check_circle_outline;
      case 'rejected': return Icons.cancel_outlined;
      default: return Icons.hourglass_empty_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Applications')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
              : _applications.isEmpty
                  ? const Center(child: Text('No applications yet.'))
                  : RefreshIndicator(
                      onRefresh: _loadApplications,
                      child: ListView.separated(
                        itemCount: _applications.length,
                        separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
                        itemBuilder: (context, index) {
                          final application = _applications[index];
                          final status = application.status;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Icon(Icons.work_outline, color: Theme.of(context).colorScheme.onPrimaryContainer),
                            ),
                            title: Text(application.jobTitle ?? 'Job #${application.job}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (application.companyName != null)
                                  Text(application.companyName!),
                                Text(
                                  status[0].toUpperCase() + status.substring(1),
                                  style: TextStyle(color: _statusColor(context, status)),
                                ),
                              ],
                            ),
                            trailing: Icon(
                              _statusIcon(status),
                              color: _statusColor(context, status),
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _ApplicationDetailScreen(
                                  application: application,
                                  server: widget.server,
                                  token: widget.auth.user!.token,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

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
  State<_ApplicationDetailScreen> createState() => _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<_ApplicationDetailScreen> {
  JobPosting? _job;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJob();
  }

  Future<void> _loadJob() async {
    try {
      final job = await JobPosting.fetchById(widget.server, widget.token, widget.application.job);
      if (mounted) setState(() {
        _job = job;
        _isLoading = false;
      });
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
      case 'accepted': return Colors.green;
      case 'rejected': return Theme.of(context).colorScheme.error;
      default: return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.application.status;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.application.jobTitle ?? 'Application Details'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Status banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _statusColor(context, status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor(context, status)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: _statusColor(context, status)),
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

                // Link to job posting
                OutlinedButton.icon(
                  onPressed: _job != null ? _showJobDetail : null,
                  icon: const Icon(Icons.work_outline),
                  label: const Text('Link to job posting'),
                ),
                const SizedBox(height: 12),

                // Link to company profile
                OutlinedButton.icon(
                  onPressed: widget.application.employerId != null
                      ? _showCompanyProfile
                      : null,
                  icon: const Icon(Icons.business_outlined),
                  label: Text(widget.application.companyName ?? 'Company profile'),
                ),
                const SizedBox(height: 24),
                
                // Mock AI interview button: TODO
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                        Theme.of(context).colorScheme.tertiary.withOpacity(0.7),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.psychology_outlined, color: Colors.white),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Soon',
                                style: TextStyle(color: Colors.white, fontSize: 12),
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
