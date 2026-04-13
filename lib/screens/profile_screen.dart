import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import '../auth.dart';
import '../user.dart';
import '../widgets/user_avatar.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      await Future.wait([
        _user.fetchMe(),
        _user.fetchProfile(),
      ]);
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

        _buildSectionCard(
          title: 'Candidate profile details',
          subtitle: 'Skills, Work experience',
          icon: Icons.work_outline,
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

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Show skills/work experience later
        },
      ),
    );
  }

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