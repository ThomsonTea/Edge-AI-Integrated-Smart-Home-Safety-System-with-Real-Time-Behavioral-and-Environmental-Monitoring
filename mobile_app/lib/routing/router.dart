import 'package:flutter/material.dart';

import '../ui/layout/bottom_nav_shell.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/user_access_screen.dart';

import 'routes.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {

      case AppRoutes.login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );

      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => const BottomNavShell(),
        );

      case AppRoutes.userAccess:
        return MaterialPageRoute(
          builder: (_) => const UserAccessScreen(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(
              child: Text('Route not found'),
            ),
          ),
        );
    }
  }
}