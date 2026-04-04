import 'package:flutter/material.dart';
import '../server.dart';
import '../auth.dart';
import 'server_settings_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatelessWidget {
  final Server server;
  final Auth auth;

  const HomeScreen({super.key, required this.server, required this.auth});

  Future<void> _handleLogout(BuildContext context) async {
    await auth.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => WelcomeScreen(server: server, auth: auth)),
        (_) => false,
      );
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
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome back, ${auth.user!.username}!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Your next opportunity is waiting.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 48),
              OutlinedButton(
                onPressed: () => _handleLogout(context),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}