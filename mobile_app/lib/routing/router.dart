import 'package:flutter/material.dart';

import '../ui/layout/bottom_nav_shell.dart';
import '../ui/screens/analytics_screen.dart';
import '../ui/screens/auth_gate_screen.dart';
import '../ui/screens/event_detail_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/notification_center_screen.dart';
import '../ui/screens/profile_screen.dart';
import '../ui/screens/user_access_screen.dart';

import 'routes.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.authGate:
        return MaterialPageRoute(builder: (_) => const AuthGateScreen());

      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const BottomNavShell());

      case AppRoutes.notificationCenter:
        return MaterialPageRoute(
          builder: (_) => const NotificationCenterScreen(showAppBar: true),
        );

      case AppRoutes.analytics:
        return MaterialPageRoute(
          builder: (_) => const AnalyticsScreen(showAppBar: true),
        );

      case AppRoutes.eventDetail:
        final eventId = _eventIdFromArguments(settings.arguments);

        if (eventId == null) {
          return MaterialPageRoute(
            builder: (_) =>
                const Scaffold(body: Center(child: Text('Event not found'))),
          );
        }

        return MaterialPageRoute(
          builder: (_) => EventDetailScreen(eventId: eventId),
        );

      case AppRoutes.userAccess:
        return MaterialPageRoute(builder: (_) => const UserAccessScreen());

      case AppRoutes.profile:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const ProfileScreen(),
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }

  static int? _eventIdFromArguments(Object? arguments) {
    if (arguments is int && arguments > 0) {
      return arguments;
    }

    if (arguments is String) {
      final parsed = int.tryParse(arguments);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    return null;
  }
}
