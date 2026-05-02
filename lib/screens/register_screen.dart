import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../server.dart';
import '../auth.dart';
import '../theme/app_theme.dart';
import 'build_profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  final Server server;
  final Auth auth;

  const RegisterScreen({super.key, required this.server, required this.auth});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.candidate;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  // For avatar uploading on register
  XFile? _selectedAvatar;
  Uint8List? _avatarBytes;

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _selectedAvatar = image;
      _avatarBytes = bytes;
    });
  }

  // Shared state variables
  bool _isLoading = false;
  String? _error;

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

  // Step 1: Validate that all fields were filled and continue
  void _handleContinue() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    _goToNextPage();
  }

  // Step 2: Get remaining user data and create the account
  Future<void> _handleCreateAccount() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.auth.register(
        _usernameController.text.trim(),
        _passwordController.text,
        _selectedRole,
        firstName: firstName,
        lastName: lastName,
        email: email,
      );

      // Upload avatar if selected
      if (_selectedAvatar != null && _avatarBytes != null) {
        await widget.auth.user!.updateAvatar(_avatarBytes!, _selectedAvatar!.name);
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BuildProfileScreen(server: widget.server, auth: widget.auth),
          ),
        );
      }
    } on ServerException catch (e) {
      setState(() => _error = _friendlyError(e));
    } catch (e) {
      setState(() => _error = 'Could not connect to the server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(ServerException exception) {
    switch (exception.statusCode) {
      case 400:
        return 'Invalid data. The username may already be taken.';
      default:
        return 'Server error (${exception.statusCode}). Try again later.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_currentStep + 1} of 2'),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStep1(),
          _buildStep2(),
        ],
      ),
    );
  }

  // Step 1: Credentials and role
  Widget _buildStep1() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set a username and password',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.person_outlined, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.lock_outlined, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 24),

            SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(
                  value: UserRole.candidate,
                  label: Text('Candidate'),
                  icon: Icon(Icons.school_outlined),
                ),
                ButtonSegment(
                  value: UserRole.employer,
                  label: Text('Employer'),
                  icon: Icon(Icons.business_outlined),
                ),
              ],
              selected: {_selectedRole},
              onSelectionChanged: (selection) {
                setState(() => _selectedRole = selection.first);
              },
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _handleContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // Step 2: Personal info
  Widget _buildStep2() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tell us your name and email',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),

            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    _avatarBytes != null
                        ? CircleAvatar(
                            radius: 48,
                            backgroundImage: MemoryImage(_avatarBytes!),
                          )
                        : Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primary,
                        child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _firstNameController,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'First name',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _lastNameController,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Last name',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isLoading ? null : _handleCreateAccount,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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