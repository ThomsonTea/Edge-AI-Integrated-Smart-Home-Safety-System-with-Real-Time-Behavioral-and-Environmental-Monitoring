import 'package:flutter/material.dart';

import '../ui/layout/bottom_nav_shell.dart';
import '../ui/screens/event_detail_screen.dart';
import '../ui/screens/event_history_screen.dart';
import '../ui/screens/face_registration_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/user_access_screen.dart';

import 'routes.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const BottomNavShell());

      case AppRoutes.alertHistory:
        return MaterialPageRoute(
          builder: (_) => const EventHistoryScreen(showAppBar: true),
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

      case AppRoutes.faceRegistration:
        return MaterialPageRoute(
          builder: (_) => const FaceRegistrationScreen(),
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
