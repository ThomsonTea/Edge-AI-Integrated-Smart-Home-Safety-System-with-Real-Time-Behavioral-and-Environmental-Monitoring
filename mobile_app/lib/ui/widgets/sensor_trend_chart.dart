import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/models/analytics_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class SensorTrendChart extends StatelessWidget {
  final List<SensorTrendPoint> points;

  const SensorTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chartPoints = points
        .where(
          (point) =>
              point.temperature != null ||
              point.humidity != null ||
              point.gas != null,
        )
        .toList();

    if (chartPoints.isEmpty) {
      return const _ChartEmptyState(
        message: 'No sensor readings in this range.',
      );
    }

    final maxY = _maxY(chartPoints);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: AppSpacing.chartHeight,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
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
                    reservedSize: 36,
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
              lineBarsData: [
                _line(
                  chartPoints,
                  (point) => point.temperature,
                  colorScheme.primary,
                ),
                _line(
                  chartPoints,
                  (point) => point.humidity,
                  AppColors.success,
                ),
                _line(
                  chartPoints,
                  (point) => point.gas?.toDouble(),
                  AppColors.warning,
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
            _LegendDot(label: 'Temperature', color: colorScheme.primary),
            const _LegendDot(label: 'Humidity', color: AppColors.success),
            const _LegendDot(label: 'Gas', color: AppColors.warning),
          ],
        ),
      ],
    );
  }

  LineChartBarData _line(
    List<SensorTrendPoint> values,
    double? Function(SensorTrendPoint point) selector,
    Color color,
  ) {
    final spots = <FlSpot>[];
    for (var index = 0; index < values.length; index++) {
      final value = selector(values[index]);
      if (value != null) {
        spots.add(FlSpot(index.toDouble(), value));
      }
    }

    return LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 2.5,
      isCurved: true,
      preventCurveOverShooting: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  double _maxY(List<SensorTrendPoint> values) {
    var maxValue = 10.0;
    for (final point in values) {
      final candidates = [
        point.temperature,
        point.humidity,
        point.gas?.toDouble(),
      ].whereType<double>();
      for (final value in candidates) {
        if (value > maxValue) maxValue = value;
      }
    }
    return maxValue * 1.15;
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSpacing.sm,
          height: AppSpacing.sm,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  final String message;

  const _ChartEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        message,
        style: AppTextStyles.body.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
