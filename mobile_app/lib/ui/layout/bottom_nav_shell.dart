import 'package:flutter/material.dart';

import '../../routing/routes.dart';
import '../../theme/app_spacing.dart';
import '../../viewmodels/session_viewmodel.dart';
import '../screens/analytics_screen.dart';
import '../screens/camera_feed_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/notification_center_screen.dart';
import '../screens/profile_screen.dart';
import 'app_drawer.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  final SessionViewModel _sessionViewModel = SessionViewModel();
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _sessionViewModel.addListener(_onSessionUpdate);
    _sessionViewModel.startSession();
  }

  @override
  void dispose() {
    _sessionViewModel.removeListener(_onSessionUpdate);
    _sessionViewModel.disposeSession();
    _sessionViewModel.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onSessionUpdate() {
    if (!mounted) return;

    setState(() {});

    if (!_sessionViewModel.isAuthExpired) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _handleLogout() async {
    await _sessionViewModel.logout();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  void _onTap(int value) {
    _goToPage(value);
  }

  void _openPage(_MainPageId id) {
    final pages = _buildMainPages();
    final index = pages.indexWhere((page) => page.id == id);
    if (index == -1) return;
    _goToPage(index);
  }

  void _goToPage(int index) {
    if (index == _index) return;

    setState(() => _index = index);

    if (!_pageController.hasClients) return;

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _syncIndexWithPageCount(int pageCount) {
    if (_index < pageCount) return;

    _index = pageCount - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(_index);
    });
  }

  List<_MainPage> _buildMainPages() {
    return [
      _MainPage(
        id: _MainPageId.dashboard,
        screen: DashboardScreen(
          key: const PageStorageKey('dashboard'),
          onViewCamera: () => _openPage(_MainPageId.camera),
          onViewAlerts: () => _openPage(_MainPageId.events),
          canManageUsers: _sessionViewModel.canManageUsers,
        ),
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: "Dashboard",
        ),
      ),
      const _MainPage(
        id: _MainPageId.events,
        screen: NotificationCenterScreen(key: PageStorageKey('events')),
        item: BottomNavigationBarItem(
          icon: Icon(Icons.security_outlined),
          activeIcon: Icon(Icons.security),
          label: "Events",
        ),
      ),
      const _MainPage(
        id: _MainPageId.camera,
        screen: CameraFeedScreen(key: PageStorageKey('camera')),
        item: BottomNavigationBarItem(
          icon: Icon(Icons.videocam_outlined),
          activeIcon: Icon(Icons.videocam),
          label: "Camera",
        ),
      ),
      const _MainPage(
        id: _MainPageId.analytics,
        screen: AnalyticsScreen(key: PageStorageKey('analytics')),
        item: BottomNavigationBarItem(
          icon: Icon(Icons.insights_outlined),
          activeIcon: Icon(Icons.insights),
          label: "Analytics",
        ),
      ),
      _MainPage(
        id: _MainPageId.profile,
        screen: ProfileScreen(
          key: const PageStorageKey('profile'),
          onLogout: _handleLogout,
        ),
        item: const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: "Profile",
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pages = _buildMainPages();
    _syncIndexWithPageCount(pages.length);

    return Scaffold(
      drawer: AppDrawer(
        onLogout: _handleLogout,
        canManageUsers: _sessionViewModel.canManageUsers,
      ),

      appBar: AppBar(
        title: const Text("Smart Security System"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Icon(Icons.shield_outlined, color: colorScheme.primary),
          ),
        ],
      ),

      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          if (_index == index) return;
          setState(() => _index = index);
        },
        children: [for (final page in pages) page.screen],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTap,
        items: [for (final page in pages) page.item],
      ),
    );
  }
}

enum _MainPageId { dashboard, events, camera, analytics, profile }

class _MainPage {
  final _MainPageId id;
  final Widget screen;
  final BottomNavigationBarItem item;

  const _MainPage({required this.id, required this.screen, required this.item});
}
