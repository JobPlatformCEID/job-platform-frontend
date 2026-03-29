import 'package:flutter/material.dart';
import '../server/server.dart';
import '../user/user.dart';
import 'home_screen.dart';

class BuildProfileScreen extends StatefulWidget {
  final Server server;
  final User user;

  const BuildProfileScreen({super.key, required this.server, required this.user});

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

  bool get _isCandidate => widget.user.getRole() == UserRole.candidate;

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_isCandidate) {
        await widget.user.buildCandidateProfile(
          phone: _phoneController.text.trim(),
          location: _locationController.text.trim(),
          bio: _bioController.text.trim(),
        );
      } else {
        await widget.user.buildEmployerProfile(
          companyName: _companyNameController.text.trim(),
          description: _companyDescriptionController.text.trim(),
          location: _employerLocationController.text.trim(),
          website: _companyWebsiteController.text.trim(),
        );
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
        builder: (_) => HomeScreen(server: widget.server, user: widget.user),
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
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
          // Renders +30 as a prefix inside the themed field, just like prefixIcon
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
