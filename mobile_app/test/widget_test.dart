import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/main.dart';
import 'package:smart_home_security_system/routing/router.dart';
import 'package:smart_home_security_system/routing/routes.dart';
import 'package:smart_home_security_system/ui/layout/bottom_nav_shell.dart';
import 'package:smart_home_security_system/ui/screens/user_access_screen.dart';

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

Future<dynamic> _handleSecureStorage(MethodCall call) async {
  switch (call.method) {
    case 'containsKey':
      return false;
    case 'read':
      return null;
    case 'readAll':
      return <String, String>{};
    case 'delete':
    case 'deleteAll':
    case 'write':
      return null;
    default:
      return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, _handleSecureStorage);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets('renders the login screen first', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartHomeApp());

    expect(find.text('Smart Home Login'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('bottom navigation exposes repaired main sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BottomNavShell()));
    await tester.pump();

    expect(find.text('Smart Security System'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Alerts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Error:'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Camera'));
    await tester.pump();
    expect(find.text('Camera Feed'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pump();
    expect(find.text('Profile'), findsWidgets);
  });

  testWidgets('drawer alert history opens event history route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        onGenerateRoute: AppRouter.generateRoute,
        home: BottomNavShell(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alert History'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.textContaining('Error:'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Smart Security System'), findsOneWidget);
  });

  testWidgets('event detail route accepts an event id argument', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: AppRoutes.eventDetail,
        onGenerateRoute: AppRouter.generateRoute,
        onGenerateInitialRoutes: _eventDetailInitialRoutes,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Event Detail'), findsOneWidget);
    expect(find.textContaining('Error:'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('user management route renders the registration form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: AppRoutes.userAccess,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('User Access Management'), findsOneWidget);
    expect(find.text('Register New User'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Phone Number'), findsOneWidget);
    expect(find.text('Register User'), findsOneWidget);
  });

  testWidgets('user management shows a standard back button when pushed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.generateRoute,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.userAccess);
                  },
                  child: const Text('Open users'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open users'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('User Access Management'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Back to dashboard'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();

    expect(find.text('Open users'), findsOneWidget);
  });

  testWidgets('user management has a dashboard exit when shown as root', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: UserAccessScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('User Access Management'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
    expect(find.byTooltip('Back to dashboard'), findsOneWidget);
  });
}

List<Route<dynamic>> _eventDetailInitialRoutes(String initialRoute) {
  return [
    AppRouter.generateRoute(
      const RouteSettings(name: AppRoutes.eventDetail, arguments: 1),
    ),
  ];
}
