import 'package:flutter/material.dart';

import '../../routing/routes.dart';
import '../../theme/app_spacing.dart';
import '../../viewmodels/session_viewmodel.dart';
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
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _sessionViewModel.addListener(_onSessionUpdate);
    _sessionViewModel.startSession();
  }

  @override
  void dispose() {
    _sessionViewModel.removeListener(_onSessionUpdate);
    _sessionViewModel.disposeSession();
    _sessionViewModel.dispose();
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
    setState(() => _index = value);
  }

  void _openTab(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screens = [
      DashboardScreen(
        onViewCamera: () => _openTab(2),
        onViewAlerts: () => _openTab(1),
        canManageUsers: _sessionViewModel.canManageUsers,
      ),
      const NotificationCenterScreen(),
      const CameraFeedScreen(),
      ProfileScreen(onLogout: _handleLogout),
    ];

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

      body: screens[_index],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security_outlined),
            activeIcon: Icon(Icons.security),
            label: "Events",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam_outlined),
            activeIcon: Icon(Icons.videocam),
            label: "Camera",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
