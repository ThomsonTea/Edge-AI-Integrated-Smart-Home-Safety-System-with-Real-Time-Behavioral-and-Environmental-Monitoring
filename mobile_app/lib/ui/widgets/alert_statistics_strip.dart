import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class AlertStatisticsStrip extends StatelessWidget {
  final int unknownPersonsToday;
  final int fallsToday;
  final int knownVisitsToday;
  final int criticalAlertsToday;

  const AlertStatisticsStrip({
    super.key,
    required this.unknownPersonsToday,
    required this.fallsToday,
    required this.knownVisitsToday,
    required this.criticalAlertsToday,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _StatCard(
            icon: Icons.warning_amber_rounded,
            label: 'Unknown Today',
            value: unknownPersonsToday.toString(),
            color: _warningColor(context),
          ),
          _StatCard(
            icon: Icons.emergency_outlined,
            label: 'Falls Today',
            value: fallsToday.toString(),
            color: _dangerColor(context),
          ),
          _StatCard(
            icon: Icons.person_outline,
            label: 'Known Visits',
            value: knownVisitsToday.toString(),
            color: _safeColor(context),
          ),
          _StatCard(
            icon: Icons.priority_high_rounded,
            label: 'Critical Today',
            value: criticalAlertsToday.toString(),
            color: _dangerColor(context),
          ),
        ],
      ),
    );
  }

  Color _safeColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.successDark
        : AppColors.success;
  }

  Color _warningColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.warningDark
        : AppColors.warning;
  }

  Color _dangerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.dangerDark
        : AppColors.danger;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 144,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const Spacer(),
          Text(
            value,
            style: AppTextStyles.sectionTitle.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
