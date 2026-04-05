import 'package:flutter/material.dart';
import '../server.dart';
import '../auth.dart';
import '../user.dart';
import 'server_settings_screen.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'candidate_home_screen.dart';
import 'employer_home_screen.dart';

class HomeScreen extends StatefulWidget {
  final Server server;
  final Auth auth;

  const HomeScreen({super.key, required this.server, required this.auth});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _handleLogout(BuildContext context) async {
    await widget.auth.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => WelcomeScreen(server: widget.server, auth: widget.auth)),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user!;
    final isCandidate = user is Candidate;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value.trim()),
          decoration: InputDecoration(
            hintText: isCandidate ? 'Search job postings' : 'Search your job postings',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
          ),
        ),
        actions: [
          // Profile avatar button
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProfileScreen(auth: widget.auth)),
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
          ? CandidateHomeScreen(
              auth: widget.auth,
              server: widget.server,
              searchQuery: _searchQuery,
            )
          : EmployerHomeScreen(
              auth: widget.auth,
              server: widget.server,
              searchQuery: _searchQuery,
            ),
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
                  MaterialPageRoute(builder: (_) => ServerSettingsScreen(server: widget.server)),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}