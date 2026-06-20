import 'package:flutter/material.dart';

import '../../domain/models/dashboard_summary.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../widgets/dashboard_filter_bar.dart';
import '../widgets/dashboard_quick_actions.dart';
import '../widgets/event_trend_chart.dart';
import '../widgets/event_type_summary.dart';
import '../widgets/latest_critical_event_card.dart';
import '../widgets/summary_status_card.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onViewCamera;
  final VoidCallback? onViewAlerts;
  final bool canManageUsers;

  const DashboardScreen({
    super.key,
    this.onViewCamera,
    this.onViewAlerts,
    this.canManageUsers = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _viewModel = DashboardViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.initializeDashboard();
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
    return RefreshIndicator(
      onRefresh: _viewModel.loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _DashboardHeader(
            isLoading: _viewModel.isLoading,
            onRefresh: _viewModel.loadSummary,
          ),
          const SizedBox(height: AppSpacing.lg),
          DashboardFilterBar(
            selectedTimeFilter: _viewModel.selectedTimeFilter,
            selectedEventType: _viewModel.selectedEventType,
            onTimeFilterChanged: _viewModel.setTimeFilter,
            onEventTypeChanged: _viewModel.setEventTypeFilter,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_viewModel.errorMessage != null)
            _DashboardError(
              message: _viewModel.errorMessage!,
              onRetry: _viewModel.loadSummary,
            )
          else ...[
            if (_viewModel.isEmpty) const _DashboardEmptyState(),
            _SummaryGrid(summary: _viewModel.summary),
            const SizedBox(height: AppSpacing.lg),
            EventTrendChart(points: _viewModel.summary.eventTrend),
            const SizedBox(height: AppSpacing.lg),
            EventTypeSummary(counts: _viewModel.summary.eventTypeCounts),
            const SizedBox(height: AppSpacing.lg),
            LatestCriticalEventCard(
              event: _viewModel.summary.latestCriticalEvent,
              onOpenEvent: (eventId) => Navigator.of(
                context,
              ).pushNamed(AppRoutes.eventDetail, arguments: eventId),
            ),
            const SizedBox(height: AppSpacing.lg),
            DashboardQuickActions(
              onViewCamera:
                  widget.onViewCamera ??
                  () => Navigator.of(context).pushNamed(AppRoutes.cameraFeed),
              onViewEventHistory:
                  widget.onViewAlerts ??
                  () => Navigator.of(context).pushNamed(AppRoutes.alertHistory),
              onUserAccessManagement: widget.canManageUsers
                  ? () => Navigator.of(context).pushNamed(AppRoutes.userAccess)
                  : null,
              onAiSettings: () =>
                  Navigator.of(context).pushNamed(AppRoutes.aiSettings),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onRefresh;

  const _DashboardHeader({required this.isLoading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Security Command Center',
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Security overview, alerts, and quick actions',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: isLoading ? null : onRefresh,
          color: colorScheme.primary,
          icon: isLoading
              ? const SizedBox(
                  width: AppSpacing.xl,
                  height: AppSpacing.xl,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final DashboardSummary summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;
        final itemWidth = isWide
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: itemWidth,
              child: SummaryStatusCard(
                icon: Icons.verified_user,
                title: 'System Status',
                value: _statusLabel(summary.systemStatus),
                color: _statusColor(context, summary.systemStatus),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: SummaryStatusCard(
                icon: Icons.videocam,
                title: 'Camera Status',
                value: _statusLabel(summary.cameraStatus),
                color: summary.cameraStatus == 'online'
                    ? _safeColor(context)
                    : _warningColor(context),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: SummaryStatusCard(
                icon: Icons.person,
                title: 'Known Persons Today',
                value: summary.knownPersonTodayCount.toString(),
                color: _safeColor(context),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: SummaryStatusCard(
                icon: Icons.person_search,
                title: 'Unknown Persons Today',
                value: summary.unknownPersonTodayCount.toString(),
                color: _warningColor(context),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: SummaryStatusCard(
                icon: Icons.notifications_active,
                title: 'Unacknowledged Alerts',
                value: summary.unacknowledgedCount.toString(),
                color: summary.unacknowledgedCount > 0
                    ? _dangerColor(context)
                    : _safeColor(context),
              ),
            ),
          ],
        );
      },
    );
  }

  String _statusLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _statusColor(BuildContext context, String status) {
    return switch (status) {
      'normal' => _safeColor(context),
      'online' => _safeColor(context),
      'attention_required' => _warningColor(context),
      'critical_alert' => _dangerColor(context),
      'camera_offline' => _dangerColor(context),
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  Color _safeColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.successDark
        : AppColors.success;
  }

  Color _warningColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.warningDark
        : AppColors.warning;
  }

  Color _dangerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.dangerDark
        : AppColors.danger;
  }
}

class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({required this.message, required this.onRetry});

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
            Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Unable to load dashboard summary',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'No dashboard activity found for the selected filters.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
