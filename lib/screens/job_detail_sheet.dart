import 'package:flutter/material.dart';
import '../job.dart';
import '../theme/app_theme.dart';

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
        return Container(
          color: AppTheme.background,
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero gradient header
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 180,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryDark, AppTheme.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppTheme.radiusLarge),
                        ),
                      ),
                    ),
                    // Overlapping avatar
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -48,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: AppTheme.primary,
                            child: Text(
                              job.title.isNotEmpty ? job.title[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 56),
                // Company name centered
                Text(
                  'Company #${job.employer}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 4),
                // Job title centered
                Text(
                  job.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Pill tags row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (job.location.isNotEmpty)
                        _Pill(icon: Icons.location_on_outlined, text: job.isRemote ? '${job.location} (Remote)' : job.location),
                      if (job.isRemote && job.location.isEmpty)
                        const _Pill(icon: Icons.wifi_outlined, text: 'Remote'),
                      _Pill(icon: Icons.work_outline, text: _contractTypeText),
                      _Pill(icon: Icons.euro_outlined, text: _salaryText),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Sections
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _SectionCard(title: 'Description', body: job.description),
                ),
                if (job.requirements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _SectionCard(title: 'Requirements', body: job.requirements),
                  ),
                ],
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _SectionCard(
                    title: 'Posted',
                    body: job.createdAt.substring(0, 10).split('-').reversed.join('/'),
                  ),
                ),
                const SizedBox(height: 32),
                if (onApply != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: onApply,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                        ),
                        child: const Text('Apply Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

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

class _SectionCard extends StatelessWidget {
  final String title;
  final String body;
  const _SectionCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }
}
