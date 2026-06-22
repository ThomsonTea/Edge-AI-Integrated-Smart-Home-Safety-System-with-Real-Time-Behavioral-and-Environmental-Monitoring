import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class AlertStatisticsStrip extends StatelessWidget {
  final int unknownPersonsToday;
  final int fallsToday;
  final int knownVisitsToday;
  final int criticalAlertsToday;
  final VoidCallback onUnknownTodayTap;
  final VoidCallback onFallsTodayTap;
  final VoidCallback onKnownVisitsTodayTap;
  final VoidCallback onCriticalTodayTap;

  const AlertStatisticsStrip({
    super.key,
    required this.unknownPersonsToday,
    required this.fallsToday,
    required this.knownVisitsToday,
    required this.criticalAlertsToday,
    required this.onUnknownTodayTap,
    required this.onFallsTodayTap,
    required this.onKnownVisitsTodayTap,
    required this.onCriticalTodayTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.85,
      children: [
        _StatCard(
          icon: Icons.warning_amber_rounded,
          label: 'Unknown',
          value: unknownPersonsToday.toString(),
          color: _warningColor(context),
          onTap: onUnknownTodayTap,
        ),
        _StatCard(
          icon: Icons.emergency_outlined,
          label: 'Falls',
          value: fallsToday.toString(),
          color: _dangerColor(context),
          onTap: onFallsTodayTap,
        ),
        _StatCard(
          icon: Icons.person_outline,
          label: 'Known Visits',
          value: knownVisitsToday.toString(),
          color: _safeColor(context),
          onTap: onKnownVisitsTodayTap,
        ),
        _StatCard(
          icon: Icons.priority_high_rounded,
          label: 'Critical',
          value: criticalAlertsToday.toString(),
          color: _dangerColor(context),
          onTap: onCriticalTodayTap,
        ),
      ],
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
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
