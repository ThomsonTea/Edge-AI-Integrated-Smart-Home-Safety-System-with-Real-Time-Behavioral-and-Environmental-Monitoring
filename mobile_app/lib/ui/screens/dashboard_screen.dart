import 'package:flutter/material.dart';

import '../../routing/routes.dart';
import '../../theme/app_spacing.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../widgets/critical_alerts_summary_card.dart';
import '../widgets/environment_snapshot_card.dart';
import '../widgets/latest_detection_card.dart';
import '../widgets/screen_header.dart';
import '../widgets/system_health_card.dart';
import '../widgets/todays_activity_card.dart';

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
      onRefresh: _viewModel.refreshDashboard,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _DashboardHeader(
            isLoading: _viewModel.isLoading,
            onRefresh: _viewModel.refreshDashboard,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_viewModel.errorMessage != null)
            _DashboardError(
              message: _viewModel.errorMessage!,
              onRetry: _viewModel.refreshDashboard,
            )
          else ...[
            if (_viewModel.isEmpty) const _DashboardEmptyState(),
            SystemHealthCard(summary: _viewModel.summary),
            const SizedBox(height: AppSpacing.lg),
            CriticalAlertsSummaryCard(
              criticalCount: _viewModel.summary.criticalAlertCount,
              unacknowledgedCriticalCount:
                  _viewModel.summary.unacknowledgedCriticalCount,
              onTap:
                  widget.onViewAlerts ??
                  () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.notificationCenter),
            ),
            const SizedBox(height: AppSpacing.lg),
            TodaysActivityCard(summary: _viewModel.summary),
            const SizedBox(height: AppSpacing.lg),
            EnvironmentSnapshotCard(
              snapshot: _viewModel.sensorSnapshot,
              isLoading: _viewModel.isSensorLoading,
              errorMessage: _viewModel.sensorErrorMessage,
            ),
            const SizedBox(height: AppSpacing.lg),
            LatestDetectionCard(
              event: _viewModel.summary.latestDetection,
              onOpenEvent: (eventId) => Navigator.of(
                context,
              ).pushNamed(AppRoutes.eventDetail, arguments: eventId),
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
    return Row(
      children: [
        const Expanded(
          child: ScreenHeader(
            title: 'System Overview',
            subtitle: 'Current state of the smart home security system',
            icon: Icons.dashboard_outlined,
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
                child: Text('No system activity has been recorded yet.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
