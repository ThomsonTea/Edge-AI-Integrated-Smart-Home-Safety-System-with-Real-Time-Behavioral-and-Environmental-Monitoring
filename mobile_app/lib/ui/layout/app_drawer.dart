import 'package:flutter/material.dart';
import '../../routing/routes.dart';
import '../../theme/app_spacing.dart';

class AppDrawer extends StatelessWidget {
  final Future<void> Function() onLogout;
  final bool canManageUsers;

  const AppDrawer({
    super.key,
    required this.onLogout,
    this.canManageUsers = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.55),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  child: const Icon(Icons.shield_outlined),
                ),
                const SizedBox(height: AppSpacing.md),
                Text("System Control Panel", style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text("Smart Security System", style: textTheme.bodySmall),
              ],
            ),
          ),

          const _DrawerSectionTitle("Core Security"),
          _DrawerItem(
            icon: Icons.history,
            label: "Alert History",
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.alertHistory);
            },
          ),

          _DrawerItem(
            icon: Icons.notifications,
            label: "Notifications",
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.notificationCenter);
            },
          ),

          const Divider(),

          const _DrawerSectionTitle("System Management"),
          if (canManageUsers)
            _DrawerItem(
              icon: Icons.group,
              label: "User Access Management",
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.userAccess);
              },
            ),

          _DrawerItem(
            icon: Icons.settings,
            label: "Camera Configuration",
            onTap: () {},
          ),

          _DrawerItem(
            icon: Icons.smart_toy,
            label: "AI Engine Settings",
            onTap: () {},
          ),

          _DrawerItem(
            icon: Icons.network_check,
            label: "Diagnostics",
            onTap: () {},
          ),

          const Divider(),

          const _DrawerSectionTitle("User & Preferences"),
          _DrawerItem(
            icon: Icons.person,
            label: "Profile",
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.profile);
            },
          ),

          _DrawerItem(
            icon: Icons.logout,
            label: "Logout",
            isDestructive: true,
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

class _DrawerSectionTitle extends StatelessWidget {
  final String label;

  const _DrawerSectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
      ),
      minLeadingWidth: AppSpacing.xl,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      onTap: onTap,
    );
  }
}
