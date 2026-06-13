import 'package:flutter/material.dart';
import 'routing/router.dart';
import 'routing/routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: AppRouter.navigatorKey,

      initialRoute: AppRoutes.login,

      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
