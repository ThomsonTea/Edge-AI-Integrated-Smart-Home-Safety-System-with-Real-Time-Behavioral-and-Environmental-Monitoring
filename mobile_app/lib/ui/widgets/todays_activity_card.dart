import 'package:flutter/material.dart';

import '../../domain/models/dashboard_summary.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class TodaysActivityCard extends StatelessWidget {
  final DashboardSummary summary;

  const TodaysActivityCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final safeColor = brightness == Brightness.dark
        ? AppColors.successDark
        : AppColors.success;
    final warningColor = brightness == Brightness.dark
        ? AppColors.warningDark
        : AppColors.warning;
    final dangerColor = brightness == Brightness.dark
        ? AppColors.dangerDark
        : AppColors.danger;
    final infoColor = Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Activity", style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            _ActivityRow(
              icon: Icons.person_outline,
              label: 'Known Person',
              value: summary.knownPersonTodayCount,
              color: safeColor,
            ),
            _ActivityRow(
              icon: Icons.person_search_outlined,
              label: 'Unknown Person',
              value: summary.unknownPersonTodayCount,
              color: warningColor,
            ),
            _ActivityRow(
              icon: Icons.emergency_outlined,
              label: 'Fall Alerts',
              value: summary.fallTodayCount,
              color: dangerColor,
            ),
            _ActivityRow(
              icon: Icons.sensors_outlined,
              label: 'Environment Alerts',
              value: summary.environmentAlertTodayCount,
              color: infoColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _ActivityRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(value.toString(), style: AppTextStyles.sectionTitle),
        ],
      ),
    );
  }
}
