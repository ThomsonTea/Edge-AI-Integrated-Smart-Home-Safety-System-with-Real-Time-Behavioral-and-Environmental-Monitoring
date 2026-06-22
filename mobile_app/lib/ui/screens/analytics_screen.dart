import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/analytics_viewmodel.dart';
import '../widgets/event_statistics_chart.dart';
import '../widgets/event_trend_chart.dart';
import '../widgets/screen_header.dart';
import '../widgets/sensor_trend_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  final bool showAppBar;

  const AnalyticsScreen({super.key, this.showAppBar = false});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _viewModel = AnalyticsViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.loadAnalytics();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      onRefresh: _viewModel.loadAnalytics,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const ScreenHeader(
            title: 'Analytics',
            subtitle: 'Sensor trends and security event statistics',
            icon: Icons.insights_outlined,
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionSelector(
            selectedSection: _viewModel.selectedSection,
            onSectionSelected: _viewModel.setSelectedSection,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_viewModel.selectedSection == AnalyticsSection.sensorTrends)
            _AnalyticsSection(
              title: 'Sensor Trends',
              subtitle: 'Temperature, humidity, and gas over time',
              selectedRange: _viewModel.sensorRange,
              isLoading: _viewModel.isSensorLoading,
              errorMessage: _viewModel.sensorError,
              onRangeSelected: _viewModel.setSensorRange,
              onRetry: _viewModel.loadSensorAnalytics,
              controls: _SensorMetricSelector(
                selectedMetrics: _viewModel.selectedSensorMetrics,
                onMetricToggled: _viewModel.toggleSensorMetric,
              ),
              child: SensorTrendChart(
                points: _viewModel.sensorAnalytics.points,
                selectedMetrics: _viewModel.selectedSensorMetrics,
              ),
            )
          else
            _AnalyticsSection(
              title: 'Security Event Statistics',
              subtitle: 'Event counts by type',
              selectedRange: _viewModel.eventRange,
              isLoading: _viewModel.isEventLoading,
              errorMessage: _viewModel.eventError,
              onRangeSelected: _viewModel.setEventRange,
              onRetry: _viewModel.loadEventAnalytics,
              controls: _EventFilterControls(
                selectedViewMode: _viewModel.selectedEventViewMode,
                selectedCategory: _viewModel.selectedEventCategory,
                selectedEventTypes: _viewModel.selectedEventTypes,
                onViewModeSelected: _viewModel.setEventViewMode,
                onCategorySelected: _viewModel.setEventCategory,
                onEventTypeToggled: _viewModel.toggleEventType,
              ),
              child: _viewModel.selectedEventViewMode == EventViewMode.trend
                  ? EventTrendChart(
                      points: _viewModel.eventTrendAnalytics.points,
                      selectedEventTypes: _viewModel.selectedEventTypes,
                    )
                  : EventStatisticsChart(
                      counts: _viewModel.filteredEventCounts,
                    ),
            ),
        ],
      ),
    );

    if (!widget.showAppBar) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: content,
    );
  }
}

class _AnalyticsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String selectedRange;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<String> onRangeSelected;
  final VoidCallback onRetry;
  final Widget? controls;
  final Widget child;

  const _AnalyticsSection({
    required this.title,
    required this.subtitle,
    required this.selectedRange,
    required this.isLoading,
    required this.errorMessage,
    required this.onRangeSelected,
    required this.onRetry,
    this.controls,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _RangeChips(
              selectedRange: selectedRange,
              onRangeSelected: onRangeSelected,
            ),
            if (controls != null) ...[
              const SizedBox(height: AppSpacing.md),
              controls!,
            ],
            const SizedBox(height: AppSpacing.md),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (errorMessage != null)
              _AnalyticsError(message: errorMessage!, onRetry: onRetry)
            else
              child,
          ],
        ),
      ),
    );
  }
}

class _SectionSelector extends StatelessWidget {
  final AnalyticsSection selectedSection;
  final ValueChanged<AnalyticsSection> onSectionSelected;

  const _SectionSelector({
    required this.selectedSection,
    required this.onSectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        ChoiceChip(
          label: const Text('Sensor Trends'),
          selected: selectedSection == AnalyticsSection.sensorTrends,
          onSelected: (_) => onSectionSelected(AnalyticsSection.sensorTrends),
        ),
        ChoiceChip(
          label: const Text('Security Events'),
          selected: selectedSection == AnalyticsSection.securityEvents,
          onSelected: (_) => onSectionSelected(AnalyticsSection.securityEvents),
        ),
      ],
    );
  }
}

class _SensorMetricSelector extends StatelessWidget {
  final Set<SensorMetric> selectedMetrics;
  final ValueChanged<SensorMetric> onMetricToggled;

  const _SensorMetricSelector({
    required this.selectedMetrics,
    required this.onMetricToggled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Show',
          style: AppTextStyles.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final metric in SensorMetric.values)
              FilterChip(
                label: Text(_labelForMetric(metric)),
                selected: selectedMetrics.contains(metric),
                onSelected: (_) => onMetricToggled(metric),
              ),
          ],
        ),
      ],
    );
  }

  String _labelForMetric(SensorMetric metric) {
    return switch (metric) {
      SensorMetric.temperature => 'Temperature',
      SensorMetric.humidity => 'Humidity',
      SensorMetric.gas => 'Gas',
    };
  }
}

class _RangeChips extends StatelessWidget {
  final String selectedRange;
  final ValueChanged<String> onRangeSelected;

  const _RangeChips({
    required this.selectedRange,
    required this.onRangeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final range in analyticsRanges)
          ChoiceChip(
            label: Text(_labelForRange(range)),
            selected: selectedRange == range,
            onSelected: (_) => onRangeSelected(range),
          ),
      ],
    );
  }

  String _labelForRange(String range) {
    return switch (range) {
      '24h' => 'Last 24 Hours',
      '7d' => 'Last 7 Days',
      '30d' => 'Last 30 Days',
      _ => range,
    };
  }
}

class _EventFilterControls extends StatelessWidget {
  final EventViewMode selectedViewMode;
  final EventCategory selectedCategory;
  final Set<String> selectedEventTypes;
  final ValueChanged<EventViewMode> onViewModeSelected;
  final ValueChanged<EventCategory> onCategorySelected;
  final ValueChanged<String> onEventTypeToggled;

  const _EventFilterControls({
    required this.selectedViewMode,
    required this.selectedCategory,
    required this.selectedEventTypes,
    required this.onViewModeSelected,
    required this.onCategorySelected,
    required this.onEventTypeToggled,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'View',
          style: AppTextStyles.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChip(
              label: const Text('Trend'),
              selected: selectedViewMode == EventViewMode.trend,
              onSelected: (_) => onViewModeSelected(EventViewMode.trend),
            ),
            ChoiceChip(
              label: const Text('Distribution'),
              selected: selectedViewMode == EventViewMode.distribution,
              onSelected: (_) => onViewModeSelected(EventViewMode.distribution),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Category',
          style: AppTextStyles.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final category in EventCategory.values)
              ChoiceChip(
                label: Text(_labelForCategory(category)),
                selected: selectedCategory == category,
                onSelected: (_) => onCategorySelected(category),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Event Types',
          style: AppTextStyles.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final eventType in analyticsEventTypes)
              FilterChip(
                label: Text(_labelForEventType(eventType)),
                selected: selectedEventTypes.contains(eventType),
                onSelected: (_) => onEventTypeToggled(eventType),
              ),
          ],
        ),
      ],
    );
  }

  String _labelForCategory(EventCategory category) {
    return switch (category) {
      EventCategory.all => 'All',
      EventCategory.people => 'People',
      EventCategory.safety => 'Safety',
      EventCategory.environment => 'Environment',
    };
  }

  String _labelForEventType(String eventType) {
    return switch (eventType) {
      'known_person' => 'Known Person',
      'unknown_person' => 'Unknown Person',
      'fall_detected' => 'Fall Detection',
      'prolonged_inactivity' => 'Inactivity',
      'gas_alert' => 'Gas Alert',
      'high_temperature' => 'High Temperature',
      'sensor_offline' => 'Sensor Offline',
      _ => eventType,
    };
  }
}

class _AnalyticsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AnalyticsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Unable to load analytics',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          style: AppTextStyles.caption.copyWith(color: colorScheme.error),
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}
