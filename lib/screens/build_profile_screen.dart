import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../server.dart';
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

  bool get _isCandidate => widget.auth.user is Candidate;

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

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isCandidate) {
        final candidate = widget.auth.user as Candidate;
        candidate.phone = _phoneController.text.trim();
        candidate.location = _locationController.text.trim();
        candidate.bio = _bioController.text.trim();
        // move update here cause if it was after cv cause updateProfile calls fetch profile
        await widget.auth.user!.updateProfile();
        if (_cvBytes != null && _cvFileName != null) {
          await candidate.uploadCV(_cvBytes!, _cvFileName!);
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
      case 400:
        return 'Invalid data. Please check your inputs.';
      case 401:
        return 'Session expired. Please log in again.';
      default:
        return 'Server error (${e.statusCode}). Try again later.';
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

      // CV upload
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
                      onPressed: _removeCV,
                    ),
                  ],
                )
              : Column(
                  children: [
                    Icon(Icons.upload_file_outlined, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to upload a PDF (optional)',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
        ),
      ),
      const SizedBox(height: 24),
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