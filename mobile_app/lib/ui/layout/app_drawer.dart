import 'package:flutter/material.dart';
import '../../routing/routes.dart';

class AppDrawer extends StatelessWidget {
  final Future<void> Function() onLogout;

  const AppDrawer({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            child: Text("System Control Panel", style: TextStyle(fontSize: 18)),
          ),

          // CORE SECURITY
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text("Alert History"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.alertHistory);
            },
          ),

          // FAMILY
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text("User Access Management"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.userAccess);
            },
          ),

          ListTile(
            leading: const Icon(Icons.face_retouching_natural),
            title: const Text("Face Registration"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.faceRegistration);
            },
          ),

          const Divider(),

          // SYSTEM MANAGEMENT
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Camera Configuration"),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text("AI Engine Settings"),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.network_check),
            title: const Text("Diagnostics"),
            onTap: () {},
          ),

          const Divider(),

          // USER SETTINGS
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text("Notifications"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.notificationCenter);
            },
          ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: () async {
              Navigator.pop(context);
              await onLogout();
            },
          ),
        ],
      ),
    );
  }
}
