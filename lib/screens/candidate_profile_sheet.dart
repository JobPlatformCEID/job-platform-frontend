import 'package:flutter/material.dart';
import '../server.dart';

class CandidateProfileSheet extends StatefulWidget {
  final int profileId;
  final Server server;
  final String token;

  const CandidateProfileSheet({
    super.key,
    required this.profileId,
    required this.server,
    required this.token,
  });

  @override
  State<CandidateProfileSheet> createState() => _CandidateProfileSheetState();
}

class _CandidateProfileSheetState extends State<CandidateProfileSheet> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await widget.server.sendGet('/api/candidates/${widget.profileId}/', token: widget.token);
      if (mounted) setState(() {
        _profile = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load candidate profile.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        if (_isLoading) return const Center(child: CircularProgressIndicator());
        if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)));

        final profile = _profile!;

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Text('Candidate Profile', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            if ((profile['location'] as String?)?.isNotEmpty == true) ...[
              _buildInfoRow(context, Icons.location_on_outlined, 'Location', profile['location'] as String),
              const SizedBox(height: 12),
            ],
            if ((profile['phone'] as String?)?.isNotEmpty == true) ...[
              _buildInfoRow(context, Icons.phone_outlined, 'Phone', profile['phone'] as String),
              const SizedBox(height: 12),
            ],
            if ((profile['bio'] as String?)?.isNotEmpty == true) ...[
              Text('Bio', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(profile['bio'] as String, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            if (profile['score'] != null)
              _buildInfoRow(context, Icons.star_outline, 'Score', '${profile['score']}'),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            // Skills placeholder
            Row(
              children: [
                Text('Skills', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                Chip(
                  label: const Text('Coming soon'),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Work Experience placeholder
            Row(
              children: [
                Text('Work Experience', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                Chip(
                  label: const Text('Coming soon'),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Education placeholder
            Row(
              children: [
                Text('Education', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 8),
                Chip(
                  label: const Text('Coming soon'),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

          ],
        );
      },
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}