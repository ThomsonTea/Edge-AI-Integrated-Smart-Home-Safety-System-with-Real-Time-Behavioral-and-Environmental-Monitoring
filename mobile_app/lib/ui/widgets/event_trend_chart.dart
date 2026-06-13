import 'package:flutter/material.dart';

import '../../domain/models/dashboard_summary.dart';
import '../../theme/app_spacing.dart';

class EventTrendChart extends StatelessWidget {
  final List<EventTrendPoint> points;

  const EventTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (points.isEmpty) {
      return const _EmptyChart();
    }

    final maxCount = points
        .map((point) => point.count)
        .fold<int>(0, (max, count) => count > max ? count : max);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Events Over Time',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: AppSpacing.chartHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: points
                        .map(
                          (point) => Expanded(
                            child: _TrendBar(
                              point: point,
                              maxCount: maxCount == 0 ? 1 : maxCount,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  final EventTrendPoint point;
  final int maxCount;

  const _TrendBar({required this.point, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    final heightFactor = point.count == 0 ? 0.04 : point.count / maxCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            point.count.toString(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Flexible(
            child: FractionallySizedBox(
              heightFactor: heightFactor.clamp(0.04, 1.0),
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _shortLabel(point.label),
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _shortLabel(String value) {
    if (value.length >= 10) {
      return value.substring(5);
    }

    return value;
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Events Over Time',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text('No event trend data for the selected filters.'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
