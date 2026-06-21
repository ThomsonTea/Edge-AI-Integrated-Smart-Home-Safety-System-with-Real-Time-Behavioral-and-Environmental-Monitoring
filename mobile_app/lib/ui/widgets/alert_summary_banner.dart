import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class AlertSummaryBanner extends StatelessWidget {
  final int criticalCount;
  final int unacknowledgedCount;
  final DateTime? lastAlertTime;

  const AlertSummaryBanner({
    super.key,
    required this.criticalCount,
    required this.unacknowledgedCount,
    required this.lastAlertTime,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCritical = criticalCount > 0;
    final accent = hasCritical ? _dangerColor(context) : colorScheme.primary;
    final background = hasCritical
        ? accent.withValues(alpha: 0.12)
        : colorScheme.primaryContainer.withValues(alpha: 0.55);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.14),
                  foregroundColor: accent,
                  child: Icon(
                    hasCritical
                        ? Icons.warning_amber_rounded
                        : Icons.shield_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    hasCritical ? 'Critical alerts active' : 'Security status',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Critical Alerts',
                    value: criticalCount.toString(),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Unacknowledged',
                    value: unacknowledgedCount.toString(),
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Last Alert',
                    value: _relativeTime(lastAlertTime),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _dangerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.dangerDark
        : AppColors.danger;
  }

  String _relativeTime(DateTime? timestamp) {
    if (timestamp == null) return 'None';

    final difference = DateTime.now().difference(timestamp.toLocal());
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    return '${difference.inDays} d ago';
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.sectionTitle.copyWith(
            color: colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
