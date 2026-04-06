import 'package:flutter/material.dart';
import '../auth.dart';
import '../user.dart';

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
      await _user.fetchProfile();
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
      await _user.updateProfile();
      if (mounted) setState(() {
        _isEditing = false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = 'Could not save profile.';
      });
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
    return Row(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.person_outline,
            size: 48,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoField(
                label: 'Full name',
                value: '${_user.username}', // TODO: replace when we add first/last name on user (needs server change)
              ),
              const SizedBox(height: 8),
              _buildInfoField(
                label: 'Username',
                value: _user.username,
              ),
              const SizedBox(height: 8),
              _buildInfoField(
                label: 'User ID',
                value: '#${_user.userId}'
              ),
            ],
          ),
        ),
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
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Candidate profile details',
          subtitle: 'Skills, Work experience',
          icon: Icons.work_outline,
        ),
      ],
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
          // TODO: Show skills/workexperience later
        },
      ),
    );
  }

  @override
  void dispose() {
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
