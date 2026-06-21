import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

class DashboardQuickActions extends StatelessWidget {
  final VoidCallback onViewCamera;
  final VoidCallback onViewSecurityEvents;
  final VoidCallback? onUserAccessManagement;
  final VoidCallback onAiSettings;

  const DashboardQuickActions({
    super.key,
    required this.onViewCamera,
    required this.onViewSecurityEvents,
    this.onUserAccessManagement,
    required this.onAiSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _ActionButton(
              icon: Icons.videocam,
              label: 'View Camera',
              onPressed: onViewCamera,
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionButton(
              icon: Icons.security,
              label: 'View Security Events',
              onPressed: onViewSecurityEvents,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (onUserAccessManagement != null) ...[
              _ActionButton(
                icon: Icons.manage_accounts,
                label: 'User Access Management',
                onPressed: onUserAccessManagement!,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            _ActionButton(
              icon: Icons.settings_suggest,
              label: 'AI Settings',
              onPressed: onAiSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
