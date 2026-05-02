import 'package:flutter/material.dart';
import '../server.dart';
import '../theme/app_theme.dart';
import 'candidate_profile_sheet.dart';
import 'company_profile_sheet.dart';
import '../widgets/user_avatar.dart';

class UserProfileSheet extends StatefulWidget {
  final int userId;
  final Server server;
  final String token;

  const UserProfileSheet({
    super.key,
    required this.userId,
    required this.server,
    required this.token,
  });

  @override
  State<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<UserProfileSheet> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final data = await widget.server.sendGet('/api/users/${widget.userId}/', token: widget.token);
      if (mounted) setState(() {
        _user = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load user profile.';
      });
    }
  }

  void _showCandidateProfile() {
    final profileId = _user!['profile_id'] as int?;
    if (profileId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CandidateProfileSheet(
        profileId: profileId,
        server: widget.server,
        token: widget.token,
      ),
    );
  }

  void _showCompanyProfile() {
    final profileId = _user!['profile_id'] as int?;
    if (profileId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CompanyProfileSheet(
        profileId: profileId,
        server: widget.server,
        token: widget.token,
      ),
    );
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

        final user = _user!;
        final fullName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
        final displayName = fullName.isNotEmpty ? fullName : user['username'] as String;
        final role = user['role'] as String;
        final isCandidate = role == 'candidate';

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            // Avatar + name
            Row(
              children: [
                UserAvatar(
                  avatarUrl: _user!['avatar'] as String?,
                  displayName: displayName,
                  radius: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: Theme.of(context).textTheme.titleLarge),
                      Text('@${user['username']}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Chip(
                  label: Text(isCandidate ? 'Candidate' : 'Employer'),
                  avatar: Icon(
                    isCandidate ? Icons.person_outline : Icons.business_outlined,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Info rows
            _buildInfoRow(context, Icons.badge_outlined, 'User ID', '#${user['id']}'),
            const SizedBox(height: 12),
            _buildInfoRow(context, Icons.email_outlined, 'Email', user['email'] as String? ?? ''),
            const SizedBox(height: 24),

            // Profile button
            if (_user!['profile_id'] != null)
              OutlinedButton.icon(
                onPressed: isCandidate ? _showCandidateProfile : _showCompanyProfile,
                icon: Icon(isCandidate ? Icons.person_outline : Icons.business_outlined),
                label: Text(isCandidate ? 'View Candidate Profile' : 'View Company Profile'),
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
