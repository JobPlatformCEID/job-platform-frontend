import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../server_api.dart';
import '../auth.dart';
import '../user.dart';
import 'main_screen.dart';

class BuildProfileScreen extends StatefulWidget {
  final Server server;
  final Auth auth;

  const BuildProfileScreen({super.key, required this.server, required this.auth});

  @override
  State<BuildProfileScreen> createState() => _BuildProfileScreenState();
}

class _BuildProfileScreenState extends State<BuildProfileScreen> {
  bool _isLoading = false;
  String? _error;

  // Candidate controllers
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();

  // Employer controllers
  final _companyNameController = TextEditingController();
  final _companyDescriptionController = TextEditingController();
  final _employerLocationController = TextEditingController();
  final _companyWebsiteController = TextEditingController();

  // CV (candidates only)
  Uint8List? _cvBytes;
  String? _cvFileName;

  // Background data (candidates only)
  final List<Skill> _skills = [];
  final List<Education> _educations = [];
  final List<WorkExperience> _experiences = [];

  bool get _isCandidate => widget.auth.user is Candidate;
  Candidate get _candidate => widget.auth.user as Candidate;

  Future<void> _pickCV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    setState(() {
      _cvBytes = result.files.single.bytes;
      _cvFileName = result.files.single.name;
    });
  }

  void _removeCV() => setState(() {
    _cvBytes = null;
    _cvFileName = null;
  });

  // --- Skills ---

  void _showAddSkillDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add skill'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _submitSkill(controller.text, ctx),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => _submitSkill(controller.text, ctx),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _submitSkill(String name, BuildContext dialogCtx) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    Navigator.pop(dialogCtx);
    setState(() => _skills.add(Skill(name: trimmed)));
  }

  // --- Education ---

  void _showAddEducationDialog() {
    final institutionCtrl = TextEditingController();
    final degreeCtrl = TextEditingController();
    String level = 'bachelor';
    DateTime? graduationDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add education'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: institutionCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Institution',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: degreeCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Degree / Field of study',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: level,
                  decoration: const InputDecoration(
                    labelText: 'Level',
                    prefixIcon: Icon(Icons.bar_chart_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'high_school', child: Text('High School')),
                    DropdownMenuItem(value: 'bachelor',    child: Text('Bachelor')),
                    DropdownMenuItem(value: 'master',      child: Text('Master')),
                    DropdownMenuItem(value: 'phd',         child: Text('PhD')),
                  ],
                  onChanged: (v) => setDialogState(() => level = v!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    graduationDate != null
                        ? 'Graduated ${graduationDate!.year}'
                        : 'Graduation date (optional)',
                    style: TextStyle(
                      color: graduationDate != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1950),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => graduationDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (institutionCtrl.text.trim().isEmpty || degreeCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                setState(() => _educations.add(Education(
                  institution: institutionCtrl.text.trim(),
                  degree: degreeCtrl.text.trim(),
                  level: level,
                  graduationDate: graduationDate != null
                      ? '${graduationDate!.year}-${graduationDate!.month.toString().padLeft(2, '0')}-${graduationDate!.day.toString().padLeft(2, '0')}'
                      : null,
                )));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // Work Experience

  void _showAddExperienceDialog() {
    final titleCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    String employmentType = 'full_time';
    DateTime? startDate;
    DateTime? endDate;
    bool isCurrent = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add experience'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Job title',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: companyCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Company',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: employmentType,
                  decoration: const InputDecoration(
                    labelText: 'Employment type',
                    prefixIcon: Icon(Icons.schedule_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'full_time',  child: Text('Full Time')),
                    DropdownMenuItem(value: 'part_time',  child: Text('Part Time')),
                    DropdownMenuItem(value: 'freelance',  child: Text('Freelance')),
                    DropdownMenuItem(value: 'internship', child: Text('Internship')),
                    DropdownMenuItem(value: 'contract',   child: Text('Contract')),
                  ],
                  onChanged: (v) => setDialogState(() => employmentType = v!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    startDate != null
                        ? 'Started ${_formatDate(startDate!)}'
                        : 'Start date *',
                    style: TextStyle(
                      color: startDate != null
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => startDate = picked);
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isCurrent,
                  title: const Text('I currently work here'),
                  onChanged: (v) => setDialogState(() {
                    isCurrent = v!;
                    if (isCurrent) endDate = null;
                  }),
                ),
                if (!isCurrent)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(
                      endDate != null
                          ? 'Ended ${_formatDate(endDate!)}'
                          : 'End date (optional)',
                      style: TextStyle(
                        color: endDate != null
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialogState(() => endDate = picked);
                    },
                  ),
                const SizedBox(height: 4),
                TextField(
                  controller: descriptionCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty ||
                    companyCtrl.text.trim().isEmpty ||
                    startDate == null) return;
                Navigator.pop(ctx);
                setState(() => _experiences.add(WorkExperience(
                  title: titleCtrl.text.trim(),
                  company: companyCtrl.text.trim(),
                  startDate: _toApiDate(startDate!),
                  endDate: endDate != null ? _toApiDate(endDate!) : null,
                  description: descriptionCtrl.text.trim(),
                  employmentType: employmentType,
                )));
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${_monthName(d.month)} ${d.year}';

  String _toApiDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];

  String _employmentLabel(String type) => {
    'full_time': 'Full Time',
    'part_time': 'Part Time',
    'freelance': 'Freelance',
    'internship': 'Internship',
    'contract': 'Contract',
  }[type] ?? type;

  String _levelLabel(String level) => {
    'high_school': 'High School',
    'bachelor': 'Bachelor',
    'master': 'Master',
    'phd': 'PhD',
  }[level] ?? level;

  // --- Submit ---

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isCandidate) {
        _candidate.phone = _phoneController.text.trim();
        _candidate.location = _locationController.text.trim();
        _candidate.bio = _bioController.text.trim();
        await widget.auth.user!.updateProfile();

        if (_cvBytes != null && _cvFileName != null) {
          await _candidate.uploadCV(_cvBytes!, _cvFileName!);
        }

        // Save background data
        for (final skill in _skills) {
          await _candidate.addSkill(skill.name);
        }
        for (final edu in _educations) {
          await _candidate.addEducation(edu);
        }
        for (final exp in _experiences) {
          await _candidate.addExperience(exp);
        }
      } else {
        final employer = widget.auth.user as Employer;
        employer.companyName = _companyNameController.text.trim();
        employer.description = _companyDescriptionController.text.trim();
        employer.location = _employerLocationController.text.trim();
        employer.website = _companyWebsiteController.text.trim();
        await widget.auth.user!.updateProfile();
      }
      if (mounted) _navigateToHome();
    } on ServerException catch (e) {
      setState(() => _error = _friendlyError(e));
    } catch (e) {
      setState(() => _error = 'Could not connect to the server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainScreen(server: widget.server, auth: widget.auth),
      ),
      (_) => false,
    );
  }

  String _friendlyError(ServerException e) {
    switch (e.statusCode) {
      case 400: return 'Invalid data. Please check your inputs.';
      case 401: return 'Session expired. Please log in again.';
      default:  return 'Server error (${e.statusCode}). Try again later.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCandidate ? 'Build your profile' : "Build your company's profile"),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isCandidate) ..._buildCandidateFields()
            else ..._buildEmployerFields(),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            FilledButton(
              onPressed: _isLoading ? null : _handleSubmit,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('All done'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCandidateFields() {
    return [
      // --- Basic info ---
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: 'Phone number',
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '+30',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _locationController,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Location',
          prefixIcon: Icon(Icons.location_on_outlined),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _bioController,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: 'Bio',
          alignLabelWithHint: true,
          prefixIcon: Icon(Icons.edit_outlined),
        ),
      ),
      const SizedBox(height: 24),

      // --- CV upload ---
      Text('CV / Resume', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _cvBytes == null ? _pickCV : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cvBytes != null
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _cvBytes != null
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: _cvBytes != null ? 2 : 1,
            ),
          ),
          child: _cvBytes != null
              ? Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _cvFileName!,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            '${(_cvBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      onPressed: _removeCV,
                    ),
                  ],
                )
              : Column(
                  children: [
                    Icon(Icons.upload_file_outlined, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text('Tap to upload a PDF (optional)',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
        ),
      ),
      const SizedBox(height: 32),

      // --- Skills ---
      _SectionHeader(
        title: 'Skills',
        subtitle: 'Add your technical and soft skills',
        onAdd: _showAddSkillDialog,
      ),
      const SizedBox(height: 12),
      if (_skills.isEmpty)
        _EmptyState(label: 'No skills added yet')
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _skills.map((s) => Chip(
            label: Text(s.name),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => setState(() => _skills.remove(s)),
          )).toList(),
        ),
      const SizedBox(height: 32),

      // --- Education ---
      _SectionHeader(
        title: 'Education',
        subtitle: 'Add your academic background',
        onAdd: _showAddEducationDialog,
      ),
      const SizedBox(height: 12),
      if (_educations.isEmpty)
        _EmptyState(label: 'No education added yet')
      else
        Column(
          children: _educations.map((e) => _BackgroundCard(
            icon: Icons.school_outlined,
            title: e.degree,
            subtitle: e.institution,
            trailing: _levelLabel(e.level),
            detail: e.graduationDate != null ? 'Graduated ${e.graduationDate!.substring(0, 4)}' : null,
            onDelete: () => setState(() => _educations.remove(e)),
          )).toList(),
        ),
      const SizedBox(height: 32),

      // --- Work Experience ---
      _SectionHeader(
        title: 'Work Experience',
        subtitle: 'Add your professional experience',
        onAdd: _showAddExperienceDialog,
      ),
      const SizedBox(height: 12),
      if (_experiences.isEmpty)
        _EmptyState(label: 'No experience added yet')
      else
        Column(
          children: _experiences.map((e) => _BackgroundCard(
            icon: Icons.work_outline,
            title: e.title,
            subtitle: e.company,
            trailing: _employmentLabel(e.employmentType),
            detail: e.endDate != null
                ? '${e.startDate.substring(0, 7)} → ${e.endDate!.substring(0, 7)}'
                : 'Since ${e.startDate.substring(0, 7)}',
            onDelete: () => setState(() => _experiences.remove(e)),
          )).toList(),
        ),
      const SizedBox(height: 32),
    ];
  }

  List<Widget> _buildEmployerFields() {
    return [
      TextField(
        controller: _companyNameController,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Company name',
          prefixIcon: Icon(Icons.business_outlined),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _companyDescriptionController,
        maxLines: 3,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Company description',
          alignLabelWithHint: true,
          prefixIcon: Icon(Icons.edit_outlined),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _employerLocationController,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          labelText: 'Location',
          prefixIcon: Icon(Icons.location_on_outlined),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _companyWebsiteController,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Company website',
          hintText: 'https://',
          prefixIcon: Icon(Icons.language_outlined),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _companyNameController.dispose();
    _companyDescriptionController.dispose();
    _employerLocationController.dispose();
    _companyWebsiteController.dispose();
    super.dispose();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        IconButton.filled(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          tooltip: 'Add $title',
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;
  const _EmptyState({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _BackgroundCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final String? detail;
  final VoidCallback onDelete;

  const _BackgroundCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.detail,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (detail != null)
              Text(detail!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        isThreeLine: detail != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(label: Text(trailing, style: const TextStyle(fontSize: 11))),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Theme.of(context).colorScheme.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}