import 'package:flutter/material.dart';
import '../server.dart';
import '../auth.dart';
import '../user.dart';
import 'server_settings_screen.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'candidate_home_screen.dart';
import 'employer_home_screen.dart';

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
    final user = auth.user!;
    final isCandidate = user is Candidate;

    return Scaffold(
      appBar: AppBar(
        // Hamburger menu — provided automatically by Scaffold when drawer is set
        actions: [
          // Profile avatar button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProfileScreen(auth: auth)),
              ),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.person_outline,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, user, isCandidate),
      body: isCandidate
          ? CandidateHomeScreen(auth: auth, server: server)
          : EmployerHomeScreen(auth: auth, server: server),
    );
  }

  Widget _buildDrawer(BuildContext context, User user, bool isCandidate) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drawer header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person_outline,
                      size: 28,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    user.username,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const Divider(),

            // Role-specific items
            if (isCandidate) ...[
              // TODO: Add My job applications here when server supports it
            ],

            // Settings
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Server Settings'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ServerSettingsScreen(server: server)),
                );
              },
            ),

            // Spacer pushes logout to the bottom
            const Spacer(),
            const Divider(),

            // Logout
            ListTile(
              leading: Icon(
                Icons.logout,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Log out',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => _handleLogout(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}