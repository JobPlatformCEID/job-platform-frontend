import 'package:flutter/material.dart';

class CompanyProfileSheet extends StatelessWidget {
  final Map<String, dynamic> employer;

  const CompanyProfileSheet({required this.employer});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.business_outlined, size: 32, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    employer['company_name'] as String? ?? '',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if ((employer['location'] as String?)?.isNotEmpty == true) ...[
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16),
                  const SizedBox(width: 8),
                  Text(employer['location'] as String, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if ((employer['website'] as String?)?.isNotEmpty == true) ...[
              Row(
                children: [
                  const Icon(Icons.link_outlined, size: 16),
                  const SizedBox(width: 8),
                  Text(employer['website'] as String, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if ((employer['description'] as String?)?.isNotEmpty == true) ...[
              Text('About', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(employer['description'] as String, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        );
      },
    );
  }
}