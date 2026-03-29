import 'package:flutter/material.dart';
import '../server.dart';
import '../user.dart';
import 'server_settings_screen.dart';
import 'welcome_screen.dart';
import 'job_detail_screen.dart';
import 'build_profile_screen.dart';
import 'call_screen.dart';

class HomeScreen extends StatefulWidget {
  final Server server;
  final User user;

  const HomeScreen({super.key, required this.server, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Placeholder jobs — will come from API later
  final List<Map<String, dynamic>> _jobs = [
    {
      'id': 1,
      'title': 'Flutter Developer',
      'company': 'Tech Solutions SA',
      'location': 'Athens, Greece',
      'salary': '2500 - 3500',
      'remote': false,
      'description': 'We are looking for an experienced Flutter developer...',
      'requirements': 'Dart, Flutter, REST APIs, 2+ years experience',
      'posted': '12/03/2026',
    },
    {
      'id': 2,
      'title': 'Backend Engineer',
      'company': 'Startup Hub',
      'location': 'Remote',
      'salary': '3000 - 4500',
      'remote': true,
      'description': 'Join our backend team working on Django REST APIs...',
      'requirements': 'Python, Django, PostgreSQL, Docker',
      'posted': '15/03/2026',
    },
    {
      'id': 3,
      'title': 'UI/UX Designer',
      'company': 'Creative Agency',
      'location': 'Thessaloniki, Greece',
      'salary': '1800 - 2500',
      'remote': false,
      'description': 'Design beautiful user interfaces for our clients...',
      'requirements': 'Figma, Adobe XD, 3+ years experience',
      'posted': '18/03/2026',
    },
    {
      'id': 4,
      'title': 'DevOps Engineer',
      'company': 'Cloud Corp',
      'location': 'Remote',
      'salary': '4000 - 5500',
      'remote': true,
      'description': 'Manage our cloud infrastructure and CI/CD pipelines...',
      'requirements': 'AWS, Docker, Kubernetes, CI/CD',
      'posted': '20/03/2026',
    },
    {
      'id': 5,
      'title': 'Data Scientist',
      'company': 'Analytics Co',
      'location': 'Athens, Greece',
      'salary': '3500 - 5000',
      'remote': false,
      'description': 'Analyze large datasets and build ML models...',
      'requirements': 'Python, TensorFlow, SQL, Statistics',
      'posted': '22/03/2026',
    },
  ];

  List<Map<String, dynamic>> get _filteredJobs {
    if (_searchQuery.isEmpty) return _jobs;
    return _jobs.where((job) {
      return job['title'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
             job['company'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
             job['location'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _handleLogout(BuildContext context) async {
    await widget.user.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => WelcomeScreen(server: widget.server, user: widget.user),
        ),
        (_) => false,
      );
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter Jobs', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            const Text('Location type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['All', 'Remote', 'On-site'].map((label) =>
                FilterChip(
                  label: Text(label),
                  selected: false,
                  onSelected: (_) {},
                ),
              ).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Salary range (EUR)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Any', '< 2000', '2000-4000', '4000+'].map((label) =>
                FilterChip(
                  label: Text(label),
                  selected: false,
                  onSelected: (_) {},
                ),
              ).toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobsTab() {
    return Column(
      children: [
        // Search bar + filter row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search job postings',
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
              ),
              const SizedBox(width: 8),
              // Profile avatar button (top right in mockup)
              GestureDetector(
                onTap: () => setState(() => _currentTab = 2),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Jobs list
        Expanded(
          child: _filteredJobs.isEmpty
              ? const Center(child: Text('No jobs found.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredJobs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final job = _filteredJobs[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      title: Text(
                        job['title'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(job['company']),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(width: 2),
                              Text(
                                job['location'],
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              if (job['remote'] == true) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Remote',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JobDetailScreen(
                            job: job,
                            server: widget.server,
                            user: widget.user,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Filter button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: OutlinedButton.icon(
              onPressed: _showFilterSheet,
              icon: const Icon(Icons.tune),
              label: const Text('Filter'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesTab() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.message_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Messages coming soon', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSocialTab() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Social feed coming soon', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildJobsTab(),
      _buildMessagesTab(),
      _buildSocialTab(),
    ];

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: _currentTab == 0
          ? AppBar(
              // hamburger menu on left — built-in via drawer
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ServerSettingsScreen(server: widget.server),
                    ),
                  ),
                ),
              ],
            )
          : AppBar(
              title: Text(_currentTab == 1 ? 'Messages' : 'Social'),
            ),
      body: tabs[_currentTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.message_outlined), selectedIcon: Icon(Icons.message), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Social'),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              widget.user.getUsername() ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(widget.user.getRole()?.name ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.work_outline),
            title: const Text('My Job Applications'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: const Text('Get Verified'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Reviews'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Market Statistics'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.video_call_outlined),
            title: const Text('Join Test Call'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    roomId: '1',
                    currentUsername: widget.user.getUsername() ?? 'Guest', // <-- FIXED
                    server: widget.server, // <-- FIXED
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}