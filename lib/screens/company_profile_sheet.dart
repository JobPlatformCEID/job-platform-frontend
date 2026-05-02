import 'package:flutter/material.dart';
import '../server.dart';
import '../theme/app_theme.dart';

class CompanyProfileSheet extends StatefulWidget {
  final int profileId;
  final Server server;
  final String token;

  const CompanyProfileSheet({
    super.key,
    required this.profileId,
    required this.server,
    required this.token,
  });

  @override
  State<CompanyProfileSheet> createState() => _CompanyProfileSheetState();
}

class _CompanyProfileSheetState extends State<CompanyProfileSheet> {
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
      final data = await widget.server.sendGet(
        '/api/employers/${widget.profileId}/',
        token: widget.token,
      );
      if (mounted) setState(() {
        _profile = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load company profile.';
      });
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
        if (_isLoading) return const Center(child: CircularProgressIndicator());
        if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)));

        final employer = _profile!;
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                 // TODO: What should this avatar show? Maybe a photo of the company?
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
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 16),
                const SizedBox(width: 8),
                Text(employer['location'] as String, style: Theme.of(context).textTheme.bodyMedium),
              ]),
              const SizedBox(height: 16),
            ],
            if ((employer['website'] as String?)?.isNotEmpty == true) ...[
              Row(children: [
                const Icon(Icons.link_outlined, size: 16),
                const SizedBox(width: 8),
                Text(employer['website'] as String, style: Theme.of(context).textTheme.bodyMedium),
              ]),
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