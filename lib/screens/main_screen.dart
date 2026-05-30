import 'package:flutter/material.dart';
import 'package:job_platform_frontend/screens/cv_builder_screen.dart';
import '../server_api.dart';
import '../auth.dart';
import '../user.dart';
import '../widgets/responsive.dart';
import '../widgets/user_avatar.dart';
import 'server_settings_screen.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'candidate_home_screen.dart';
import 'employer_home_screen.dart';
import 'reviews_screen.dart';
import 'social_screen.dart';
import 'conversations_screen.dart';
import 'candidate_applications_screen.dart';
import 'ai_interviews_screen.dart';
import 'stats_screen.dart';
import 'calendar_screen.dart';

class MainScreen extends StatefulWidget {
  final Server server;
  final Auth auth;

  const MainScreen({super.key, required this.server, required this.auth});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _handleLogout(BuildContext context) async {
    await widget.auth.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => WelcomeScreen(server: widget.server, auth: widget.auth)),
        (_) => false,
      );
    }
  }

  Future<void> _loadUserData() async {
    try {
      await widget.auth.user?.fetchMe();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    if (user == null) return const Scaffold(body: SizedBox.shrink());

    final isCandidate = user is Candidate;

    if (Responsive.isDesktop(context)) {
      return _buildDesktopLayout(context, user!, isCandidate);
    }
    return _buildMobileLayout(context, user!, isCandidate);
  }

  // Desktop: persistent sidebar + content area
  Widget _buildDesktopLayout(BuildContext context, User user, bool isCandidate) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: _scaffoldKey,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar
          Container(
            width: 250,
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                // Logo / brand
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colorScheme.primary, colorScheme.tertiary],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.work_outline, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'JobBless',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // User profile card
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProfileScreen(auth: widget.auth)),
                    ).then((_) => setState(() {})),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          UserAvatar(avatarUrl: user.avatarUrl, displayName: user.fullName, radius: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.fullName, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                Text(isCandidate ? 'Candidate' : 'Employer', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 18, color: colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),

                const Divider(indent: 16, endIndent: 16),

                // Main nav items
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _SidebarNavItem(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home,
                        label: 'Home',
                        selected: _selectedIndex == 0,
                        onTap: () => _selectTab(0),
                      ),
                      _SidebarNavItem(
                        icon: Icons.message_outlined,
                        selectedIcon: Icons.message,
                        label: 'Messages',
                        selected: _selectedIndex == 1,
                        onTap: () => _selectTab(1),
                      ),
                      _SidebarNavItem(
                        icon: Icons.people_outlined,
                        selectedIcon: Icons.people,
                        label: 'Social',
                        selected: _selectedIndex == 2,
                        onTap: () => _selectTab(2),
                      ),

                      const Divider(indent: 16, endIndent: 16),

                      // Secondary nav items (from drawer)
                      _SidebarNavItem(
                        icon: Icons.rate_review_outlined,
                        label: 'Reviews',
                        onTap: () => _pushScreen(ReviewsScreen(auth: widget.auth, server: widget.server)),
                      ),
                      _SidebarNavItem(
                        icon: Icons.calendar_month_outlined,
                        label: 'Calendar',
                        onTap: () => _pushScreen(CalendarScreen(auth: widget.auth, server: widget.server)),
                      ),
                      _SidebarNavItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Market Stats',
                        onTap: () => _pushScreen(StatsScreen(auth: widget.auth, server: widget.server)),
                      ),

                      if (isCandidate) ...[
                        const Divider(indent: 16, endIndent: 16),
                        _SidebarNavItem(
                          icon: Icons.assignment_outlined,
                          label: 'My Applications',
                          onTap: () => _pushScreen(CandidateApplicationsScreen(auth: widget.auth, server: widget.server)),
                        ),
                        _SidebarNavItem(
                          icon: Icons.smart_toy_outlined,
                          label: 'Mock AI Interviews',
                          onTap: () => _pushScreen(AiInterviewsScreen(server: widget.server, auth: widget.auth)),
                        ),
                      ],
                    ],
                  ),
                ),

                // Bottom section
                const Divider(),
                _SidebarNavItem(
                  icon: Icons.settings_outlined,
                  label: 'Server Settings',
                  onTap: () => _pushScreen(ServerSettingsScreen(server: widget.server)),
                ),
                _SidebarNavItem(
                  icon: Icons.logout,
                  label: 'Log out',
                  iconColor: colorScheme.error,
                  labelColor: colorScheme.error,
                  onTap: () => _handleLogout(context),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          Expanded(
            flex: 5,
            child: Column(
              children: [
                // Desktop top bar with search
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: _searchHint(isCandidate),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearSearch,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.opaque,
                    child: _buildContent(isCandidate),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, User user, bool isCandidate) {
    return Scaffold(
      onDrawerChanged: (isOpened) => _searchFocusNode.unfocus(),
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: _searchHint(isCandidate),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  )
                : null,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProfileScreen(auth: widget.auth)),
              ).then((_) => setState(() {})),
              child: UserAvatar(
                avatarUrl: user.avatarUrl,
                displayName: user.fullName,
                radius: 18,
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context, user, isCandidate),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: _buildContent(isCandidate),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => _selectTab(index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.message_outlined), selectedIcon: Icon(Icons.message), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: 'Social'),
        ],
      ),
    );
  }

  
  Widget _buildContent(bool isCandidate) {
    return switch (_selectedIndex) {
      1 => ConversationsScreen(auth: widget.auth, server: widget.server, searchQuery: _searchQuery.trim()),
      2 => SocialScreen(auth: widget.auth, server: widget.server, searchQuery: _searchQuery.trim()),
      _ => isCandidate
          ? CandidateHomeScreen(auth: widget.auth, server: widget.server, searchQuery: _searchQuery.trim())
          : EmployerHomeScreen(auth: widget.auth, server: widget.server, searchQuery: _searchQuery.trim()),
    };
  }

  String _searchHint(bool isCandidate) {
    final hints = [
      isCandidate ? 'Search job postings' : 'Search your job postings',
      'Search conversations',
      'Search posts',
    ];
    return hints[_selectedIndex.clamp(0, 2)];
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  void _pushScreen(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildDrawer(BuildContext context, User user, bool isCandidate) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  UserAvatar(avatarUrl: user.avatarUrl, displayName: user.fullName, radius: 24),
                  const SizedBox(width: 16),
                  Text(user.fullName, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.rate_review_outlined),
              title: const Text('Reviews'),
              onTap: () {
                Navigator.of(context).pop();
                _pushScreen(ReviewsScreen(auth: widget.auth, server: widget.server));
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Calendar'),
              onTap: () {
                Navigator.of(context).pop();
                _pushScreen(CalendarScreen(auth: widget.auth, server: widget.server));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded),
              title: const Text('Market Stats'),
              onTap: () {
                Navigator.of(context).pop();
                _pushScreen(StatsScreen(auth: widget.auth, server: widget.server));
              },
            ),
            if (isCandidate) ...[
              ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text('My job applications'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pushScreen(CandidateApplicationsScreen(auth: widget.auth, server: widget.server));
                },
              ),
              ListTile(
                leading: const Icon(Icons.smart_toy_outlined),
                title: const Text('Mock AI Interviews'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pushScreen(AiInterviewsScreen(server: widget.server, auth: widget.auth));
                },
              ),
            ],
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Server Settings'),
              onTap: () {
                Navigator.of(context).pop();
                _pushScreen(ServerSettingsScreen(server: widget.server));
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: Text('Log out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
    _searchFocusNode.dispose();
    super.dispose();
  }
}

class _SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _SidebarNavItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.selected = false,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? (selected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant);
    final effectiveLabelColor = labelColor ?? (selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected ? (selectedIcon ?? icon) : icon,
                  size: 20,
                  color: effectiveIconColor,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: effectiveLabelColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}