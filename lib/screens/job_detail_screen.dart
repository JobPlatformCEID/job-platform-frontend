import 'package:flutter/material.dart';
import '../server.dart';
import '../user.dart';

class JobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final Server server;
  final User user;

  const JobDetailScreen({
    super.key,
    required this.job,
    required this.server,
    required this.user,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _hasApplied = false;
  bool _isApplying = false;

  Future<void> _apply() async {
    setState(() => _isApplying = true);
    try {
      // TODO: wire to ApiService.applyForJob(widget.job['id'])
      await Future.delayed(const Duration(seconds: 1)); // placeholder
      setState(() => _hasApplied = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to apply. Please try again.')),
        );
      }
    } finally {
      setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              job['title'],
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),

            // Company
            Text(
              job['company'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),

            // Info chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(Icons.location_on_outlined, job['location']),
                _InfoChip(Icons.euro_outlined, '${job['salary']} EUR/month'),
                _InfoChip(Icons.calendar_today_outlined, job['posted']),
                if (job['remote'] == true)
                  _InfoChip(Icons.wifi_outlined, 'Remote'),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Description
            _Section(title: 'Job Description', content: job['description']),
            const SizedBox(height: 16),

            // Requirements
            _Section(title: 'Job Requirements', content: job['requirements']),
            const SizedBox(height: 16),

            // Location / Map placeholder
            if (job['remote'] != true) ...[
              Text('Location', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 40,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(job['location'],
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Employer profile link
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.business_outlined),
              label: Text('View ${job['company']} profile'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),

      // Apply button pinned at bottom
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: FilledButton(
          onPressed: _hasApplied || _isApplying ? null : _apply,
          child: _isApplying
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_hasApplied ? 'Applied ✓' : 'Apply'),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String content;

  const _Section({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(content,
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}