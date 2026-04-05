import 'package:flutter/material.dart';
import '../server.dart';
import '../user.dart';
import 'server_settings_screen.dart';
import 'welcome_screen.dart';
import 'view_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final Server server;
  final User user;

  const HomeScreen({super.key, required this.server, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final data = await widget.user.fetchAvatar();
      if (mounted) {
        setState(() {
          _avatarUrl = data['avatar_url'] as String?;
        });
      }
    } catch (_) {
      // Falls back to initials on error — _avatarUrl stays null
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await widget.user.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => WelcomeScreen(server: widget.server, user: widget.user)),
        (_) => false,
      );
    }
  }

  //Note: rendering is done left to right

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          // the settings button
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServerSettingsScreen(server: widget.server),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Settings',
          ),

          // the users profile
          Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ViewProfileScreen(
                      server: widget.server,
                      user: widget.user,
                      avatarUrl: _avatarUrl,
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                child: _avatarUrl == null
                    ? Text(
                        (widget.user.getUsername() ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      )
                    : null,
              ),
            ),
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
                'Welcome back, ${widget.user.getUsername()}!',
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