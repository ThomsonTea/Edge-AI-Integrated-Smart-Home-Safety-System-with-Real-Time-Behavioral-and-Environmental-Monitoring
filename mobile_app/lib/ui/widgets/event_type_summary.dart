import 'package:flutter/material.dart';

import '../../domain/models/dashboard_summary.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class EventTypeSummary extends StatelessWidget {
  final EventTypeCounts counts;

  const EventTypeSummary({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final safeColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.successDark
        : AppColors.success;
    final warningColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.warningDark
        : AppColors.warning;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Event Type Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _CountRow(
              label: 'Known Person',
              count: counts.knownPerson,
              color: safeColor,
            ),
            _CountRow(
              label: 'Unknown Person',
              count: counts.unknownPerson,
              color: warningColor,
            ),
            _CountRow(label: 'Other Alerts', count: counts.other),
          ],
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  final String label;
  final int count;
  final Color? color;

  const _CountRow({required this.label, required this.count, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            size: AppSpacing.md,
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
          Text(count.toString(), style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
