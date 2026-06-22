import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/models/analytics_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class EventTrendChart extends StatelessWidget {
  final List<EventTrendPoint> points;
  final Set<String> selectedEventTypes;

  const EventTrendChart({
    super.key,
    required this.points,
    required this.selectedEventTypes,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelIndexes = _visibleLabelIndexes(points.length);
    final chartPoints = points
        .where(
          (point) => selectedEventTypes.any(
            (eventType) => point.countFor(eventType) > 0,
          ),
        )
        .toList();

    if (points.isEmpty || chartPoints.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Text(
          'No selected security event trends in this range.',
          style: AppTextStyles.body.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final maxY = _maxY(points);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: AppSpacing.chartHeight + AppSpacing.xl,
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
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => colorScheme.inverseSurface,
                  getTooltipItems: (spots) => [
                    if (spots.isNotEmpty)
                      LineTooltipItem(
                        _tooltipForPoint(context, spots.first.x.toInt()),
                        AppTextStyles.caption.copyWith(
                          color: colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
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
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (!labelIndexes.contains(index) ||
                          index < 0 ||
                          index >= points.length) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          _axisLabelForPoint(points[index]),
                          style: AppTextStyles.caption.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                for (final eventType in selectedEventTypes)
                  _line(
                    points,
                    eventType,
                    _colorForEventType(context, eventType),
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
            for (final eventType in selectedEventTypes)
              _LegendDot(
                label: _labelForEventType(eventType),
                color: _colorForEventType(context, eventType),
              ),
          ],
        ),
      ],
    );
  }

  LineChartBarData _line(
    List<EventTrendPoint> values,
    String eventType,
    Color color,
  ) {
    return LineChartBarData(
      spots: [
        for (var index = 0; index < values.length; index++)
          FlSpot(
            index.toDouble(),
            values[index].countFor(eventType).toDouble(),
          ),
      ],
      color: color,
      barWidth: 2.5,
      isCurved: true,
      preventCurveOverShooting: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  double _maxY(List<EventTrendPoint> values) {
    var maxValue = 1;
    for (final point in values) {
      for (final eventType in selectedEventTypes) {
        final value = point.countFor(eventType);
        if (value > maxValue) maxValue = value;
      }
    }

    return maxValue + 1;
  }

  Set<int> _visibleLabelIndexes(int length) {
    if (length <= 0) return const {};
    if (length <= 7) {
      return {for (var index = 0; index < length; index++) index};
    }

    final desiredLabels = length <= 24 ? 5 : 6;
    final step = ((length - 1) / (desiredLabels - 1)).ceil();
    final indexes = <int>{0, length - 1};

    for (var index = 0; index < length; index += step) {
      indexes.add(index);
    }

    return indexes;
  }

  String _axisLabelForPoint(EventTrendPoint point) {
    final timestamp = point.timestamp;
    if (timestamp == null) return point.label;

    if (points.length == 24) {
      final hour = timestamp.toLocal().hour.toString().padLeft(2, '0');
      return '$hour:00';
    }

    if (points.length > 7) {
      return _shortDate(timestamp);
    }

    return point.label;
  }

  String _tooltipForPoint(BuildContext context, int index) {
    if (index < 0 || index >= points.length) return '';

    final point = points[index];
    final buffer = StringBuffer(_tooltipTitle(context, point));

    for (final eventType in selectedEventTypes) {
      final count = point.countFor(eventType);
      if (count <= 0) continue;
      buffer.write('\n${_labelForEventType(eventType)}: $count');
    }

    if (buffer.toString().trim() == _tooltipTitle(context, point)) {
      buffer.write('\nNo selected events');
    }

    return buffer.toString();
  }

  String _tooltipTitle(BuildContext context, EventTrendPoint point) {
    final timestamp = point.timestamp;
    if (timestamp == null) return point.label;

    final localTimestamp = timestamp.toLocal();
    final localizations = MaterialLocalizations.of(context);

    if (points.length == 24) {
      final date = localizations.formatMediumDate(localTimestamp);
      final time = localizations.formatTimeOfDay(
        TimeOfDay.fromDateTime(localTimestamp),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
      return '$date, $time';
    }

    return localizations.formatMediumDate(localTimestamp);
  }

  String _shortDate(DateTime timestamp) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final localTimestamp = timestamp.toLocal();
    return '${localTimestamp.day} ${months[localTimestamp.month - 1]}';
  }

  Color _colorForEventType(BuildContext context, String eventType) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (eventType) {
      'known_person' => AppColors.success,
      'unknown_person' => AppColors.warning,
      'fall_detected' => colorScheme.error,
      'prolonged_inactivity' => AppColors.danger,
      'gas_alert' => AppColors.warningDark,
      'high_temperature' => AppColors.dangerDark,
      'sensor_offline' => colorScheme.primary,
      _ => colorScheme.primary,
    };
  }

  String _labelForEventType(String eventType) {
    return switch (eventType) {
      'known_person' => 'Known Person',
      'unknown_person' => 'Unknown Person',
      'fall_detected' => 'Fall',
      'prolonged_inactivity' => 'Inactivity',
      'gas_alert' => 'Gas',
      'high_temperature' => 'High Temp',
      'sensor_offline' => 'Sensor Offline',
      _ => eventType,
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
