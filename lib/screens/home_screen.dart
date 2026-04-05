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
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(auth: auth)),
            ),
            icon: const Icon(Icons.person_outlined),
            tooltip: 'My Profile',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ServerSettingsScreen(server: server)),
            ),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Server Settings',
          ),
          IconButton(
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
          ),
        ],
      ),
      body: auth.user is Candidate
          ? CandidateHomeScreen(auth: auth, server: server)
          : EmployerHomeScreen(auth: auth, server: server),
    );
  }
}