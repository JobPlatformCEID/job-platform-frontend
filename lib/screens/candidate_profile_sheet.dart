import 'package:flutter/material.dart';
import '../server_api.dart';

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
  List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _experience = [];
  List<Map<String, dynamic>> _education = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final id = widget.profileId;
      final results = await Future.wait([
        widget.server.sendGet('/api/candidates/$id/', token: widget.token),
        widget.server.sendGetList('/api/candidates/background/skills/?candidate_id=$id', token: widget.token).catchError((_) => <Map<String, dynamic>>[]),
        widget.server.sendGetList('/api/candidates/background/experience/?candidate_id=$id', token: widget.token).catchError((_) => <Map<String, dynamic>>[]),
        widget.server.sendGetList('/api/candidates/background/education/?candidate_id=$id', token: widget.token).catchError((_) => <Map<String, dynamic>>[]),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>;
          _skills = (results[1] as List).cast<Map<String, dynamic>>();
          _experience = (results[2] as List).cast<Map<String, dynamic>>();
          _education = (results[3] as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not load candidate profile.';
        });
      }
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
        if (_error != null) {
          return Center(
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          );
        }

        final profile = _profile!;

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Text('Candidate Profile', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Basic info
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
              const SizedBox(height: 16),
            ],

            const Divider(),
            const SizedBox(height: 20),

            //Skills
            _SectionHeader(title: 'Skills', icon: Icons.star_outline, count: _skills.length),
            const SizedBox(height: 12),
            if (_skills.isEmpty)
              _EmptySection(label: 'No skills listed')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skills.map((s) {
                  final name = s['name'] as String? ?? s['skill_name'] as String? ?? '';
                  final level = s['level'] as String?;
                  return Chip(
                    label: Text(level != null ? '$name · $level' : name),
                    avatar: const Icon(Icons.check_circle_outline, size: 16),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 20),

            //Work Experience
            _SectionHeader(title: 'Work Experience', icon: Icons.work_history_outlined, count: _experience.length),
            const SizedBox(height: 12),
            if (_experience.isEmpty)
              _EmptySection(label: 'No work experience listed')
            else
              ..._experience.map((e) => _ExperienceCard(data: e)),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 20),

            // Education 
            _SectionHeader(title: 'Education', icon: Icons.school_outlined, count: _education.length),
            const SizedBox(height: 12),
            if (_education.isEmpty)
              _EmptySection(label: 'No education listed')
            else
              ..._education.map((e) => _EducationCard(data: e)),

            const SizedBox(height: 24),
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

//Small shared widgets

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;

  const _SectionHeader({required this.title, required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String label;
  const _EmptySection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ExperienceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = data['title'] as String? ?? data['position'] as String? ?? '';
    final company = data['company'] as String? ?? data['company_name'] as String? ?? '';
    final startDate = _formatDate(data['start_date'] as String?);
    final endDate = data['is_current'] == true || data['end_date'] == null
        ? 'Present'
        : _formatDate(data['end_date'] as String?);
    final description = data['description'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.business_outlined, size: 18, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (company.isNotEmpty)
                  Text(company, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                if (startDate != null)
                  Text(
                    '$startDate – $endDate',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EducationCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EducationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final institution = data['institution'] as String? ?? data['school'] as String? ?? '';
    final degree = data['degree'] as String?;
    final field = data['field_of_study'] as String? ?? data['field'] as String?;
    final startDate = _formatDate(data['start_date'] as String?);
    final endDate = data['end_date'] == null ? 'Present' : _formatDate(data['end_date'] as String?);
    final description = data['description'] as String?;

    final subtitle = [if (degree != null) degree, if (field != null) field]
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.school_outlined, size: 18, color: cs.onSecondaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(institution, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                if (startDate != null)
                  Text(
                    '$startDate – $endDate',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _formatDate(String? iso) {
  if (iso == null) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[dt.month - 1]} ${dt.year}';
}