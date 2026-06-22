import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/analytics_viewmodel.dart';
import '../widgets/event_statistics_chart.dart';
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
          const SizedBox(height: AppSpacing.lg),
          _AnalyticsSection(
            title: 'Sensor Trends',
            subtitle: 'Temperature, humidity, and gas over time',
            selectedRange: _viewModel.sensorRange,
            isLoading: _viewModel.isSensorLoading,
            errorMessage: _viewModel.sensorError,
            onRangeSelected: _viewModel.setSensorRange,
            onRetry: _viewModel.loadSensorAnalytics,
            child: SensorTrendChart(points: _viewModel.sensorAnalytics.points),
          ),
          const SizedBox(height: AppSpacing.lg),
          _AnalyticsSection(
            title: 'Security Event Statistics',
            subtitle: 'Event counts by type',
            selectedRange: _viewModel.eventRange,
            isLoading: _viewModel.isEventLoading,
            errorMessage: _viewModel.eventError,
            onRangeSelected: _viewModel.setEventRange,
            onRetry: _viewModel.loadEventAnalytics,
            child: EventStatisticsChart(
              counts: _viewModel.eventAnalytics.counts,
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
  final Widget child;

  const _AnalyticsSection({
    required this.title,
    required this.subtitle,
    required this.selectedRange,
    required this.isLoading,
    required this.errorMessage,
    required this.onRangeSelected,
    required this.onRetry,
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
