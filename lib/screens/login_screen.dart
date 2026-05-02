import 'package:flutter/material.dart';
import '../auth.dart';
import '../server.dart';
import '../theme/app_theme.dart';
import 'server_settings_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  final Server server;
  final Auth auth;

  const LoginScreen({super.key, required this.server, required this.auth});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.auth.login(username, password);
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
        builder: (_) => MainScreen(server: widget.server, auth: widget.auth)
      ),
      (_) => false,
    );
  }

  String _friendlyError(ServerException exception) {
    switch (exception.statusCode) {
      case 401:
        return 'Wrong username or password.';
      default:
        return 'Server error (${exception.statusCode}). Try again later.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServerSettingsScreen(server: widget.server),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            tooltip: 'Server Settings',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Log in with username',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),

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
                onSubmitted: (_) => _handleLogin(),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: Icon(Icons.lock_outlined, color: AppTheme.textSecondary),
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
                onPressed: _isLoading ? null : _handleLogin,
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
                    : const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
