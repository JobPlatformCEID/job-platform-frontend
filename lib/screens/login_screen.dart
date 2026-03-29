import 'package:flutter/material.dart';
import '../server.dart';
import '../user.dart';
import 'server_settings_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  final Server server;
  final User user;

  const LoginScreen({super.key, required this.server, required this.user});

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
      await widget.user.login(username, password);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => HomeScreen(server: widget.server, user: widget.user),
          ),
          (_) => false,
        );
      }
    } on ServerException catch (e) {
      setState(() => _error = e.statusCode == 401
          ? 'Wrong username or password.'
          : 'Server error (${e.statusCode}). Try again later.');
    } catch (e) {
      setState(() => _error = 'Could not connect to the server.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ServerSettingsScreen(server: widget.server),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
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
              Icon(
                Icons.work_outline,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome Back',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Login to find your next opportunity',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 48),

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
                onSubmitted: (_) => _handleLogin(),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outlined),
                ),
              ),
              const SizedBox(height: 16),

              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Log In'),
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