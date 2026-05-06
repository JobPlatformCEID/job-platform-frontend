import 'package:flutter/material.dart';
import '../server_api.dart';
import '../auth.dart';
import 'server_settings_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final Server server;
  final Auth auth;

  const WelcomeScreen({super.key, required this.server, required this.auth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServerSettingsScreen(server: server),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Settings',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.work_outline,
                size: 96,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              Text(
                'Welcome to the platform',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LoginScreen(
                          server: server,
                          auth: auth,
                        ),
                      ),
                    );
                  },
                  child: const Text('Login with username'),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RegisterScreen(
                          server: server,
                          auth: auth,
                        ),
                      ),
                    );
                  },
                  child: const Text('Register a new account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}