import 'package:flutter/material.dart';
import 'routing/router.dart';
import 'routing/routes.dart';

void main() {
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({Key? key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      initialRoute: AppRoutes.login,

      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}