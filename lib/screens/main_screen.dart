import 'package:flutter/material.dart';
import 'package:job_platform_frontend/screens/cv_builder_screen.dart';
import '../server.dart';
import '../auth.dart';
import '../user.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_layout.dart';
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
import 'calendar.dart';

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

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  Widget _buildBody() {
    final user = widget.auth.user;
    if (user == null) return const SizedBox.shrink();
    final isCandidate = user is Candidate;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: switch (_selectedIndex) {
        1 => ConversationsScreen(auth: widget.auth, server: widget.server, searchQuery: _searchQuery),
        2 => SocialScreen(auth: widget.auth, server: widget.server, searchQuery: _searchQuery),
        3 => AiInterviewsScreen(server: widget.server, auth: widget.auth),
        _ => isCandidate
            ? CandidateHomeScreen(auth: widget.auth, server: widget.server, searchQuery: _searchQuery)
            : EmployerHomeScreen(auth: widget.auth, server: widget.server, searchQuery: _searchQuery),
      },
    );
  }

  PreferredSizeWidget _buildAppBar({bool showMenuButton = false}) {
    final user = widget.auth.user;
    final isCandidate = user is Candidate;
    final searchHints = [
      isCandidate ? 'Search job postings' : 'Search your job postings',
      'Search conversations',
      'Search posts',
      'AI Interviews',
    ];
    return AppBar(
      leading: showMenuButton ? Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ) : null,
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) => setState(() => _searchQuery = value.trim()),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: searchHints[_selectedIndex],
          hintStyle: const TextStyle(color: AppTheme.textSecondary),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
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
            ),
            child: UserAvatar(
              avatarUrl: user?.avatarUrl,
              displayName: user?.fullName ?? '',
              radius: 18,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Common drawer items (extra items not in bottom nav) ─────────
  List<Widget> _buildExtraDrawerItems(bool isCandidate, {bool closeDrawer = false}) {
    return [
      _SidebarNavItem(
        icon: Icons.rate_review_outlined,
        selectedIcon: Icons.rate_review,
        label: 'Reviews',
        index: -1,
        selectedIndex: -2,
        onTap: () {
          if (closeDrawer) Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ReviewsScreen(auth: widget.auth, server: widget.server)),
          );
        },
      ),
      _SidebarNavItem(
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        label: 'Calendar',
        index: -1,
        selectedIndex: -2,
        onTap: () {
          if (closeDrawer) Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => CalendarScreen(auth: widget.auth, server: widget.server)),
          );
        },
      ),
      _SidebarNavItem(
        icon: Icons.bar_chart_rounded,
        selectedIcon: Icons.bar_chart,
        label: 'Market Stats',
        index: -1,
        selectedIndex: -2,
        onTap: () {
          if (closeDrawer) Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => StatsScreen(auth: widget.auth, server: widget.server)),
          );
        },
      ),
      if (isCandidate) ...[
        _SidebarNavItem(
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment,
          label: 'My Applications',
          index: -1,
          selectedIndex: -2,
          onTap: () {
            if (closeDrawer) Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CandidateApplicationsScreen(auth: widget.auth, server: widget.server)),
            );
          },
        ),
        _SidebarNavItem(
          icon: Icons.description_outlined,
          selectedIcon: Icons.description,
          label: 'CV Builder',
          index: -1,
          selectedIndex: -2,
          onTap: () {
            if (closeDrawer) Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CvBuilderScreen(server: widget.server, auth: widget.auth)),
            );
          },
        ),
      ],
    ];
  }

  // ─── Mobile drawer content (only extra items, no duplicates) ─────
  Widget _buildMobileDrawerContent(User user, bool isCandidate) {
    return Column(
      children: [
        // Logo area
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.divider)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(Icons.work_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'JobPlatform',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // Only extra items (no main nav items - they're in bottom nav)
        const SizedBox(height: 8),
        ..._buildExtraDrawerItems(isCandidate, closeDrawer: true),
        const Spacer(),
        const Divider(color: AppTheme.divider, height: 1),
        _SidebarNavItem(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings,
          label: 'Server Settings',
          index: -1,
          selectedIndex: -2,
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ServerSettingsScreen(server: widget.server)),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.error),
            title: Text('Log out', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.error)),
            onTap: () {
              Navigator.of(context).pop();
              _handleLogout(context);
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
        // User avatar at bottom
        Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.divider)),
          ),
          child: Row(
            children: [
              UserAvatar(avatarUrl: user.avatarUrl, displayName: user.fullName, radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user.fullName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Desktop sidebar content (with main nav + extra items) ───────
  Widget _buildDesktopSidebarContent(User user, bool isCandidate) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Logo area
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.accent],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(Icons.work_outline, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'JobPlatform',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Main nav items
          const SizedBox(height: 8),
          ..._navItems.map((item) => _SidebarNavItem(
            icon: item.$1,
            selectedIcon: item.$2,
            label: item.$3,
            index: item.$4,
            selectedIndex: _selectedIndex,
            onTap: () => _onDestinationSelected(item.$4),
          )),
          const Divider(color: AppTheme.divider, height: 1),
          // Extra items
          ..._buildExtraDrawerItems(isCandidate),
          const Divider(color: AppTheme.divider, height: 1),
          _SidebarNavItem(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings,
            label: 'Server Settings',
            index: -1,
            selectedIndex: -2,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ServerSettingsScreen(server: widget.server)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.error),
            title: Text('Log out', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.error)),
            onTap: () => _handleLogout(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          const SizedBox(height: 16),
          // User avatar at bottom
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: Row(
              children: [
                UserAvatar(avatarUrl: user.avatarUrl, displayName: user.fullName, radius: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Desktop sidebar (240px) ──────────────────────────────────────
  Widget _buildDesktopSidebar(User user, bool isCandidate) {
    return Container(
      width: 240,
      color: AppTheme.surface,
      child: _buildDesktopSidebarContent(user, isCandidate),
    );
  }

  static const _navItems = [
    (Icons.home_outlined, Icons.home, 'Home', 0),
    (Icons.message_outlined, Icons.message, 'Messages', 1),
    (Icons.people_outlined, Icons.people, 'Social', 2),
    (Icons.smart_toy_outlined, Icons.smart_toy, 'AI', 3),
  ];

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final isCandidate = user is Candidate;

    return ResponsiveLayout(
      // ── Mobile: bottom nav + hamburger drawer ────────────────────
      mobile: Scaffold(
        appBar: _buildAppBar(showMenuButton: true),
        drawer: Drawer(
          backgroundColor: AppTheme.surface,
          child: SafeArea(
            child: _buildMobileDrawerContent(user, isCandidate),
          ),
        ),
        body: _buildBody(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.message_outlined), selectedIcon: Icon(Icons.message), label: 'Messages'),
            NavigationDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: 'Social'),
            NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: 'AI'),
          ],
        ),
      ),
      // ── Tablet: navigation rail ───────────────────────────────────
      tablet: Scaffold(
        appBar: _buildAppBar(),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(Icons.work_outline, color: Colors.white, size: 20),
                ),
              ),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Home')),
                NavigationRailDestination(icon: Icon(Icons.message_outlined), selectedIcon: Icon(Icons.message), label: Text('Messages')),
                NavigationRailDestination(icon: Icon(Icons.people_outlined), selectedIcon: Icon(Icons.people), label: Text('Social')),
                NavigationRailDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: Text('AI')),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppTheme.divider),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      // ── Desktop: persistent sidebar ──────────────────────────────
      desktop: Scaffold(
        body: Row(
          children: [
            _buildDesktopSidebar(user!, isCandidate),
            const VerticalDivider(width: 1, thickness: 1, color: AppTheme.divider),
            Expanded(
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(child: _buildBody()),
                ],
              ),
            ),
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
  final IconData selectedIcon;
  final String label;
  final int index;
  final int selectedIndex;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == selectedIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive
            ? AppTheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: ListTile(
          leading: Icon(
            isActive ? selectedIcon : icon,
            color: isActive ? AppTheme.primary : AppTheme.textSecondary,
            size: 22,
          ),
          title: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isActive ? AppTheme.primary : AppTheme.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          minLeadingWidth: 24,
        ),
      ),
    );
  }
}
