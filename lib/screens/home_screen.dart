import 'package:flutter/material.dart';
import '../server.dart';
import '../user.dart';
import 'server_settings_screen.dart';
import 'welcome_screen.dart';
import 'view_profile_screen.dart';

class HomeScreen extends StatelessWidget {
  final Server server;
  final User user;

  const HomeScreen({super.key, required this.server, required this.user});

  Future<void> _handleLogout(BuildContext context) async {
    await user.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => WelcomeScreen(server: server, user: user)),
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
                  builder: (_) => ServerSettingsScreen(server: server),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Settings',
          ),

          // the users profile
          Padding(
            padding: const EdgeInsets.all(8) ,
            child : GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ViewProfileScreen(server: server , user: user),
                  ),
                );
              },

              child : CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  //display the first letter of the users name this is temporary in the future this will be changed to users profile pic 
                  ( user.getUsername() ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
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
                'Welcome back, ${user.getUsername()}!',
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