import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class CriticalAlertsSummaryCard extends StatelessWidget {
  final int criticalCount;
  final int unacknowledgedCriticalCount;
  final VoidCallback onTap;

  const CriticalAlertsSummaryCard({
    super.key,
    required this.criticalCount,
    required this.unacknowledgedCriticalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dangerColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dangerDark
        : AppColors.danger;
    final hasAlerts = criticalCount > 0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: dangerColor.withValues(alpha: 0.12),
                foregroundColor: dangerColor,
                child: Icon(
                  hasAlerts
                      ? Icons.warning_amber_rounded
                      : Icons.verified_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Critical Alerts', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      hasAlerts
                          ? '$criticalCount Critical Alerts'
                          : 'No active critical alerts',
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    unacknowledgedCriticalCount.toString(),
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: hasAlerts ? dangerColor : null,
                    ),
                  ),
                  Text(
                    'Unacknowledged',
                    style: AppTextStyles.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
