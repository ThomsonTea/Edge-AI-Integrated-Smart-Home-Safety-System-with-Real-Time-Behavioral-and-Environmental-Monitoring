import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/models/analytics_models.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class EventStatisticsChart extends StatelessWidget {
  final List<EventCount> counts;

  const EventStatisticsChart({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    final activeCounts = counts.where((item) => item.count > 0).toList();
    final colorScheme = Theme.of(context).colorScheme;

    if (counts.isEmpty || activeCounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'No security events in this range.',
          style: AppTextStyles.body.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final maxY = activeCounts
        .map((item) => item.count)
        .fold<int>(
          1,
          (previous, current) => current > previous ? current : previous,
        )
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: AppSpacing.chartHeight,
          child: BarChart(
            BarChartData(
              maxY: maxY + 1,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: colorScheme.outlineVariant, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: AppTextStyles.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              barGroups: [
                for (var index = 0; index < activeCounts.length; index++)
                  BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: activeCounts[index].count.toDouble(),
                        width: 14,
                        borderRadius: BorderRadius.circular(AppSpacing.xs),
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            for (final item in activeCounts)
              Text(
                '${_labelForEventType(item.eventType)}: ${item.count}',
                style: AppTextStyles.caption.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _labelForEventType(String eventType) {
    return eventType
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
