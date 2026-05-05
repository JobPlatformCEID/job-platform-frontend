import 'package:flutter/material.dart';
import '../server_api/job.dart';

class JobDetailSheet extends StatelessWidget {
  final JobPosting job;
  final VoidCallback? onApply;

  const JobDetailSheet({super.key, required this.job, this.onApply});

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
              if (onApply != null)
                FilledButton(onPressed: onApply, child: const Text('Apply')),
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
