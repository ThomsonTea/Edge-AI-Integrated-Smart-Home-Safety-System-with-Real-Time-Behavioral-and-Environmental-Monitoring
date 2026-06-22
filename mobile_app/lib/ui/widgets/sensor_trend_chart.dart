import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/models/analytics_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/analytics_viewmodel.dart';

class SensorTrendChart extends StatelessWidget {
  final List<SensorTrendPoint> points;
  final Set<SensorMetric> selectedMetrics;

  const SensorTrendChart({
    super.key,
    required this.points,
    required this.selectedMetrics,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chartPoints = points
        .where(
          (point) => selectedMetrics.any(
            (metric) => _valueForMetric(point, metric) != null,
          ),
        )
        .toList();

    if (chartPoints.isEmpty) {
      return const _ChartEmptyState(
        message: 'No selected sensor readings in this range.',
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
                for (final metric in SensorMetric.values)
                  if (selectedMetrics.contains(metric))
                    _line(
                      chartPoints,
                      (point) => _valueForMetric(point, metric),
                      _colorForMetric(context, metric),
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
            for (final metric in SensorMetric.values)
              if (selectedMetrics.contains(metric))
                _LegendDot(
                  label: _labelForMetric(metric),
                  color: _colorForMetric(context, metric),
                ),
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
      final candidates = selectedMetrics
          .map((metric) => _valueForMetric(point, metric))
          .whereType<double>();
      for (final value in candidates) {
        if (value > maxValue) maxValue = value;
      }
    }
    return maxValue * 1.15;
  }

  double? _valueForMetric(SensorTrendPoint point, SensorMetric metric) {
    return switch (metric) {
      SensorMetric.temperature => point.temperature,
      SensorMetric.humidity => point.humidity,
      SensorMetric.gas => point.gas?.toDouble(),
    };
  }

  Color _colorForMetric(BuildContext context, SensorMetric metric) {
    return switch (metric) {
      SensorMetric.temperature => Theme.of(context).colorScheme.primary,
      SensorMetric.humidity => AppColors.success,
      SensorMetric.gas => AppColors.warning,
    };
  }

  String _labelForMetric(SensorMetric metric) {
    return switch (metric) {
      SensorMetric.temperature => 'Temperature',
      SensorMetric.humidity => 'Humidity',
      SensorMetric.gas => 'Gas',
    };
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
