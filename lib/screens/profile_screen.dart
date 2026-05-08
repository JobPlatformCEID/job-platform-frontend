import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import '../auth.dart';
import '../server_api.dart';
import '../user.dart';
import '../widgets/user_avatar.dart';
import 'cv_builder_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Auth auth;

  const ProfileScreen({super.key, required this.auth});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isEditing = false;
  String? _error;

  User get _user => widget.auth.user!;
  bool get _isCandidate => _user is Candidate;

  XFile? _pendingAvatar;
  Uint8List? _pendingAvatarBytes;

  // Pending CV (candidates only)
  Uint8List? _pendingCvBytes;
  String? _pendingCvFileName;

  // User controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  // Candidate controllers
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _bioController = TextEditingController();

  // Employer controllers
  final _companyNameController = TextEditingController();
  final _companyDescriptionController = TextEditingController();
  final _employerLocationController = TextEditingController();
  final _websiteController = TextEditingController();

  // Candidate background data (loaded + locally managed)
  List<Skill> _skills = [];
  List<Education> _educations = [];
  List<WorkExperience> _experiences = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final futures = <Future>[
        _user.fetchMe(),
        _user.fetchProfile(),
      ];
      if (_isCandidate) {
        final c = _user as Candidate;
        futures.addAll([
          c.fetchSkills(),
          c.fetchEducations(),
          c.fetchExperiences(),
        ]);
      }
      await Future.wait(futures);
      if (_isCandidate) {
        final c = _user as Candidate;
        _skills = List<Skill>.from(c.skills);
        _educations = List<Education>.from(c.educations);
        _experiences = List<WorkExperience>.from(c.experiences);
      }
      _syncControllersFromUser();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not load profile.';
      });
    }
  }

  // Populates controllers from the user object after a fetch
  void _syncControllersFromUser() {
    _firstNameController.text = _user.firstName;
    _lastNameController.text = _user.lastName;
    _emailController.text = _user.email;

    if (_isCandidate) {
      final candidate = _user as Candidate;
      _phoneController.text = candidate.phone;
      _locationController.text = candidate.location;
      _bioController.text = candidate.bio;
    } else {
      final employer = _user as Employer;
      _companyNameController.text = employer.companyName;
      _companyDescriptionController.text = employer.description;
      _employerLocationController.text = employer.location;
      _websiteController.text = employer.website;
    }
  }

  // Writes controller values back to the user object before a save
  void _syncUserFromControllers() {
    _user.firstName = _firstNameController.text.trim();
    _user.lastName = _lastNameController.text.trim();
    _user.email = _emailController.text.trim();

    if (_isCandidate) {
      final candidate = _user as Candidate;
      candidate.phone = _phoneController.text.trim();
      candidate.location = _locationController.text.trim();
      candidate.bio = _bioController.text.trim();
    } else {
      final employer = _user as Employer;
      employer.companyName = _companyNameController.text.trim();
      employer.description = _companyDescriptionController.text.trim();
      employer.location = _employerLocationController.text.trim();
      employer.website = _websiteController.text.trim();
    }
  }

  Future<void> _handleSave() async {
    _syncUserFromControllers();
    setState(() => _isLoading = true);
    try {
      final candidate = _isCandidate ? _user as Candidate : null;

      await Future.wait([
        _user.updateMe(),
        // CV upload must not run in parallel with updateProfile because
        // uploadCV calls fetchProfile internally after the PATCH
        if (!_isCandidate || _pendingCvBytes == null)
          _user.updateProfile(),
        if (_pendingAvatar != null && _pendingAvatarBytes != null)
          _user.updateAvatar(_pendingAvatarBytes!, _pendingAvatar!.name),
      ]);

      // For candidates with a pending CV: updateProfile first, then CV upload
      if (candidate != null && _pendingCvBytes != null) {
        await candidate.updateProfile();
        await candidate.uploadCV(_pendingCvBytes!, _pendingCvFileName!);
      }

      // Persist any newly added background items for candidates
      if (candidate != null) {
        final savedSkills = List<Skill>.from(candidate.skills);
        final savedEducations = List<Education>.from(candidate.educations);
        final savedExperiences = List<WorkExperience>.from(candidate.experiences);

        for (final s in _skills) {
          if (!savedSkills.any((e) => e.name == s.name)) {
            await candidate.addSkill(s.name);
          }
        }
        for (final edu in _educations) {
          if (!savedEducations.any((e) =>
              e.institution == edu.institution && e.degree == edu.degree)) {
            await candidate.addEducation(edu);
          }
        }
        for (final exp in _experiences) {
          if (!savedExperiences.any((e) =>
              e.title == exp.title &&
              e.company == exp.company &&
              e.startDate == exp.startDate)) {
            await candidate.addExperience(exp);
          }
        }

        // Refresh lists from server after saves
        await Future.wait([
          candidate.fetchSkills(),
          candidate.fetchEducations(),
          candidate.fetchExperiences(),
        ]);
        _skills = List<Skill>.from(candidate.skills);
        _educations = List<Education>.from(candidate.educations);
        _experiences = List<WorkExperience>.from(candidate.experiences);
      }

      if (mounted) setState(() {
        _isEditing = false;
        _isLoading = false;
        _pendingAvatar = null;
        _pendingAvatarBytes = null;
        _pendingCvBytes = null;
        _pendingCvFileName = null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not save profile.';
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      _pendingAvatar = image;
      _pendingAvatarBytes = bytes;
    });
  }

  Future<void> _pickCV() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    setState(() {
      _pendingCvBytes = result.files.single.bytes;
      _pendingCvFileName = result.files.single.name;
    });
  }

  void _removePendingCV() => setState(() {
    _pendingCvBytes = null;
    _pendingCvFileName = null;
  });

  Future<void> _downloadCV(String cvUrl) async {
    final uri = Uri.parse(cvUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open CV.')),
        );
      }
    }
  }

  void _openCvBuilder() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CvBuilderScreen(server: widget.auth.user!.server, auth: widget.auth),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      floatingActionButton: _isLoading || _error != null
          ? null
          : FloatingActionButton(
              onPressed: _isEditing
                  ? _handleSave
                  : () => setState(() => _isEditing = true),
              child: Icon(_isEditing ? Icons.check : Icons.edit_outlined),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildFields(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Avatar
        Stack(
          children: [
            _pendingAvatarBytes != null
                ? CircleAvatar(
                    radius: 48,
                    backgroundImage: MemoryImage(_pendingAvatarBytes!),
                  )
                : UserAvatar(
                    avatarUrl: _user.avatarUrl,
                    displayName: _user.fullName,
                    radius: 48,
                  ),
            if (_isEditing)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(Icons.camera_alt_outlined, size: 16, color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Chip(
          label: Text(_isCandidate ? 'Candidate' : 'Employer'),
          avatar: Icon(_isCandidate ? Icons.person_outline : Icons.business_outlined, size: 16),
        ),
        const SizedBox(height: 24),
        _buildInfoField(label: 'Username', value: _user.username),
        const SizedBox(height: 8),
        _buildInfoField(label: 'User ID', value: '#${_user.userId}'),
        const SizedBox(height: 8),
        _buildEditableField(label: 'First name', controller: _firstNameController, icon: Icons.person_outline),
        const SizedBox(height: 8),
        _buildEditableField(label: 'Last name', controller: _lastNameController, icon: Icons.person_outline),
        const SizedBox(height: 8),
        _buildEditableField(label: 'Email', controller: _emailController, icon: Icons.email_outlined),
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildFields() {
    if (_isCandidate) {
      return _buildCandidateFields();
    } else {
      return _buildEmployerFields();
    }
  }

  Widget _buildCandidateFields() {
    final candidate = _user as Candidate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          readOnly: !_isEditing,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
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
        _buildEditableField(
          label: 'Location',
          controller: _locationController,
          icon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 16),
        _buildEditableField(
          label: 'Bio',
          controller: _bioController,
          icon: Icons.edit_outlined,
          maxLines: 5,
        ),
        const SizedBox(height: 24),

        // CV section
        Text(
          'CV / Resume',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        _buildCvWidget(candidate),
        const SizedBox(height: 16),

        // CV Builder section (only in edit mode for candidates)
        if (_isEditing) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.description_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'CV Builder',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _openCvBuilder(),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Open'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a professional CV using your profile data. Choose from multiple templates and export as PDF.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // --- Skills ---
        _ProfileSectionHeader(
          title: 'Skills',
          onAdd: _isEditing ? _showAddSkillDialog : null,
        ),
        const SizedBox(height: 8),
        if (_skills.isEmpty)
          _ProfileEmptyState(label: _isEditing ? 'No skills yet — tap + to add' : 'No skills added')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skills.map((s) => Chip(
              label: Text(s.name),
              deleteIcon: _isEditing ? const Icon(Icons.close, size: 16) : null,
              onDeleted: _isEditing ? () => _deleteSkill(s) : null,
            )).toList(),
          ),

        const SizedBox(height: 24),

        // --- Education ---
        _ProfileSectionHeader(
          title: 'Education',
          onAdd: _isEditing ? _showAddEducationDialog : null,
        ),
        const SizedBox(height: 8),
        if (_educations.isEmpty)
          _ProfileEmptyState(label: _isEditing ? 'No education yet — tap + to add' : 'No education added')
        else
          Column(
            children: _educations.map((e) => _ProfileBackgroundCard(
              icon: Icons.school_outlined,
              title: e.degree,
              subtitle: e.institution,
              trailing: _levelLabel(e.level),
              detail: e.graduationDate != null ? 'Graduated ${e.graduationDate!.substring(0, 4)}' : null,
              onDelete: _isEditing ? () => _deleteEducation(e) : null,
            )).toList(),
          ),

        const SizedBox(height: 24),

        // --- Work Experience ---
        _ProfileSectionHeader(
          title: 'Work Experience',
          onAdd: _isEditing ? _showAddExperienceDialog : null,
        ),
        const SizedBox(height: 8),
        if (_experiences.isEmpty)
          _ProfileEmptyState(label: _isEditing ? 'No experience yet — tap + to add' : 'No experience added')
        else
          Column(
            children: _experiences.map((e) => _ProfileBackgroundCard(
              icon: Icons.work_outline,
              title: e.title,
              subtitle: e.company,
              trailing: _employmentLabel(e.employmentType),
              detail: e.endDate != null
                  ? '${e.startDate.substring(0, 7)} → ${e.endDate!.substring(0, 7)}'
                  : 'Since ${e.startDate.substring(0, 7)}',
              onDelete: _isEditing ? () => _deleteExperience(e) : null,
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildCvWidget(Candidate candidate) {
    // Editing mode: a new CV has been picked
    if (_isEditing && _pendingCvBytes != null) {
      return _buildCvPendingCard();
    }

    // Editing mode: no pending CV yet
    if (_isEditing) {
      return _buildCvUploadZone(candidate.cvUrl != null);
    }

    // View mode: CV exists on the server
    if (candidate.cvUrl != null) {
      return _buildCvDownloadCard(candidate.cvUrl!);
    }

    // View mode: no CV at all
    return _buildCvEmptyCard();
  }

  Widget _buildCvPendingCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pendingCvFileName!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  '${(_pendingCvBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB · Pending upload',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            tooltip: 'Remove',
            onPressed: _removePendingCV,
          ),
        ],
      ),
    );
  }

  Widget _buildCvUploadZone(bool hasExisting) {
    return GestureDetector(
      onTap: _pickCV,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          children: [
            Icon(Icons.upload_file_outlined, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              hasExisting ? 'Tap to replace your CV (PDF)' : 'Tap to upload a CV (PDF)',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCvDownloadCard(String cvUrl) {
    // Extract a display filename from the URL, fallback to generic label
    final fileName = Uri.parse(cvUrl).pathSegments.lastWhere(
      (s) => s.isNotEmpty,
      orElse: () => 'curriculum_vitae.pdf',
    );

    return InkWell(
      onTap: () => _downloadCV(cvUrl),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Tap to download',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.download_outlined, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildCvEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 28),
          const SizedBox(width: 12),
          Text(
            'No CV uploaded',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployerFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildEditableField(
          label: 'Company name',
          controller: _companyNameController,
          icon: Icons.business_outlined,
        ),
        const SizedBox(height: 16),
        _buildEditableField(
          label: 'Company description',
          controller: _companyDescriptionController,
          icon: Icons.edit_outlined,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildEditableField(
          label: 'Website',
          controller: _websiteController,
          icon: Icons.language_outlined,
        ),
        const SizedBox(height: 16),
        _buildEditableField(
          label: 'Location',
          controller: _employerLocationController,
          icon: Icons.location_on_outlined,
        ),
      ],
    );
  }

  // Read-only field for non-editable values (username, full name)
  Widget _buildInfoField({
    required String label,
    required String value,
    IconData? icon,
    int maxLines = 1,
  }) {
    return TextField(
      readOnly: true,
      maxLines: maxLines,
      controller: TextEditingController(text: value),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
    );
  }

  // Editable field that respects _isEditing
  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    int maxLines = 1,
  }) {
    return TextField(
      readOnly: !_isEditing,
      maxLines: maxLines,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
    );
  }

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

  void _deleteSkill(Skill skill) => setState(() => _skills.remove(skill));

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

  void _deleteEducation(Education edu) => setState(() => _educations.remove(edu));

  // --- Work Experience ---

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

  void _deleteExperience(WorkExperience exp) => setState(() => _experiences.remove(exp));

  // --- Label helpers ---

  String _formatDate(DateTime d) =>
      '${_monthName(d.month)} ${d.year}';

  String _toApiDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _monthName(int m) => const [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ][m];

  String _levelLabel(String level) => {
    'high_school': 'High School',
    'bachelor': 'Bachelor',
    'master': 'Master',
    'phd': 'PhD',
  }[level] ?? level;

  String _employmentLabel(String type) => {
    'full_time': 'Full Time',
    'part_time': 'Part Time',
    'freelance': 'Freelance',
    'internship': 'Internship',
    'contract': 'Contract',
  }[type] ?? type;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _companyNameController.dispose();
    _companyDescriptionController.dispose();
    _employerLocationController.dispose();
    _websiteController.dispose();
    super.dispose();
  }
}

class _ProfileSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAdd;

  const _ProfileSectionHeader({required this.title, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (onAdd != null)
          IconButton.filled(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            tooltip: 'Add $title',
          ),
      ],
    );
  }
}

class _ProfileEmptyState extends StatelessWidget {
  final String label;
  const _ProfileEmptyState({required this.label});

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

class _ProfileBackgroundCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final String? detail;
  final VoidCallback? onDelete;

  const _ProfileBackgroundCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.detail,
    this.onDelete,
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
            if (onDelete != null)
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