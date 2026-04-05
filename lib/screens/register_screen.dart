import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../server.dart';
import '../user.dart';
import 'build_profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  final Server server;
  final User user;

  const RegisterScreen({super.key, required this.server, required this.user});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  final _usernameController  = TextEditingController();
  final _passwordController  = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController  = TextEditingController();
  final _emailController     = TextEditingController();

  UserRole _selectedRole = UserRole.candidate;
  File?    _avatarFile;
  bool     _isLoading = false;
  String?  _error;

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentStep++;
      _error = null;
    });
  }

  void _handleContinue() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    _goToNextPage();
  }

  Future<void> _handleCreateAccount() async {
    final firstName = _firstNameController.text.trim();
    final lastName  = _lastNameController.text.trim();
    final email     = _emailController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      await widget.user.register(
        _usernameController.text.trim(),
        _passwordController.text,
        _selectedRole,
        firstName: firstName,
        lastName: lastName,
        email: email,
      );
      _goToNextPage(); // go to avatar step
    } on ServerException catch (e) {
      setState(() => _error = _friendlyError(e));
    } catch (e) {
      setState(() => _error = 'Could not connect to the server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _handleFinish({bool skip = false}) async {
    setState(() => _isLoading = true);
    try {
      if (!skip && _avatarFile != null) {
        await widget.user.uploadAvatar(_avatarFile!.path);
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BuildProfileScreen(server: widget.server, user: widget.user),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to upload image.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(ServerException exception) {
    switch (exception.statusCode) {
      case 400: return 'Invalid data. The username may already be taken.';
      default:  return 'Server error (${exception.statusCode}). Try again later.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_currentStep + 1} of 3'),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Set a username and password',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outlined),
              ),
            ),
            const SizedBox(height: 24),
            SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(value: UserRole.candidate, label: Text('Candidate'), icon: Icon(Icons.school_outlined)),
                ButtonSegment(value: UserRole.employer,  label: Text('Employer'),  icon: Icon(Icons.business_outlined)),
              ],
              selected: {_selectedRole},
              onSelectionChanged: (s) => setState(() => _selectedRole = s.first),
            ),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            FilledButton(onPressed: _handleContinue, child: const Text('Continue')),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tell us your name and email',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _firstNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'First name', prefixIcon: Icon(Icons.badge_outlined)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Last name', prefixIcon: Icon(Icons.badge_outlined)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            ),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _handleCreateAccount,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add a profile picture',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('You can always change this later.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),

            // Avatar preview
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 64,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                  backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
                  child: _avatarFile == null
                      ? Icon(Icons.add_a_photo_outlined, size: 36,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(_avatarFile == null ? 'Choose from gallery' : 'Change photo'),
              ),
            ),

            const SizedBox(height: 32),
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: _isLoading ? null : () => _handleFinish(skip: false),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Finish'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : () => _handleFinish(skip: true),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}