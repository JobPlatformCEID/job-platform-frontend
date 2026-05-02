import 'package:flutter/material.dart';
import '../server.dart';
import '../auth.dart';
import '../theme/app_theme.dart';
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
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
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
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: const Icon(Icons.work_outline, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),

              Text(
                'Welcome to the platform',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Find your dream job or hire top talent',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Login with username', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Register a new account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}