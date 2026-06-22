import 'package:flutter/material.dart';

import '../../domain/models/ai_event.dart';
import '../../routing/routes.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../widgets/alert_date_filter_bar.dart';
import '../widgets/alert_filter_bar.dart';
import '../widgets/alert_search_field.dart';
import '../widgets/alert_statistics_strip.dart';
import '../widgets/alert_summary_banner.dart';
import '../widgets/grouped_alert_list.dart';
import '../widgets/screen_header.dart';

class NotificationCenterScreen extends StatefulWidget {
  final bool showAppBar;

  const NotificationCenterScreen({super.key, this.showAppBar = false});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationViewModel _viewModel = NotificationViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.loadNotifications();
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
    final content = _buildContent();

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Security Events')),
      body: content,
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.events.isEmpty) {
      return const _NotificationLoadingState();
    }

    if (_viewModel.errorMessage != null && _viewModel.events.isEmpty) {
      return _NotificationErrorState(
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.loadNotifications,
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.refreshNotifications,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          ScreenHeader(
            title: 'Security Events',
            subtitle:
                '${_viewModel.filteredEvents.length} shown from '
                '${_viewModel.events.length} detection records',
            icon: Icons.security_outlined,
            trailing: _viewModel.isLoading
                ? const SizedBox(
                    width: AppSpacing.xl,
                    height: AppSpacing.xl,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          if (_viewModel.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            _InlineNotificationError(message: _viewModel.errorMessage!),
          ],
          const SizedBox(height: AppSpacing.lg),
          AlertSummaryBanner(
            criticalCount: _viewModel.criticalCount,
            unacknowledgedCount: _viewModel.unacknowledgedCount,
          ),
          const SizedBox(height: AppSpacing.lg),
          AlertStatisticsStrip(
            unknownPersonsToday: _viewModel.unknownPersonsTodayCount,
            fallsToday: _viewModel.fallsTodayCount,
            knownVisitsToday: _viewModel.knownVisitsTodayCount,
            criticalAlertsToday: _viewModel.criticalTodayCount,
            onUnknownTodayTap: _viewModel.applyUnknownTodayFilter,
            onFallsTodayTap: _viewModel.applyFallsTodayFilter,
            onKnownVisitsTodayTap: _viewModel.applyKnownVisitsTodayFilter,
            onCriticalTodayTap: _viewModel.applyCriticalTodayFilter,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SearchAndDateFilterRow(
            searchField: AlertSearchField(
              value: _viewModel.searchQuery,
              onChanged: _viewModel.setSearchQuery,
            ),
            dateLabel: _viewModel.selectedDateFilterLabel,
            onDatePressed: _showDateFilterSheet,
          ),
          const SizedBox(height: AppSpacing.md),
          AlertFilterBar(
            filters: _viewModel.filters,
            selectedFilter: _viewModel.selectedFilter,
            onSelected: _viewModel.setFilter,
          ),
          const SizedBox(height: AppSpacing.md),
          _AcknowledgeVisibleAction(
            count: _viewModel.visibleUnacknowledgedCount,
            includesCritical: _viewModel.visibleUnacknowledgedIncludesCritical,
            isLoading: _viewModel.isAcknowledgingVisible,
            onPressed: _confirmAcknowledgeVisible,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_viewModel.events.isEmpty)
            const _EmptyNotificationState()
          else if (_viewModel.filteredEvents.isEmpty)
            const _EmptyFilteredNotificationState()
          else
            _AlertCenterSections(
              viewModel: _viewModel,
              onEventTap: _openEventDetail,
            ),
        ],
      ),
    );
  }

  void _openEventDetail(AiEvent event) {
    Navigator.of(context).pushNamed(AppRoutes.eventDetail, arguments: event.id);
  }

  Future<void> _showDateFilterSheet() async {
    final selected = await showModalBottomSheet<EventDateFilter>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by date',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final filter in _viewModel.dateFilters)
                  ListTile(
                    leading: Icon(
                      filter == EventDateFilter.custom
                          ? Icons.date_range_outlined
                          : Icons.calendar_today_outlined,
                    ),
                    title: Text(
                      filter == EventDateFilter.custom
                          ? 'Custom Range'
                          : filter.label,
                    ),
                    trailing: _viewModel.selectedDateFilter == filter
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.of(context).pop(filter),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) return;

    if (selected == EventDateFilter.custom) {
      await _showCustomDateRangePicker();
      return;
    }

    _viewModel.setDateFilter(selected);
  }

  Future<void> _showCustomDateRangePicker() async {
    final now = DateTime.now();
    final initialStart =
        _viewModel.customStartDate ?? now.subtract(const Duration(days: 7));
    final initialEnd = _viewModel.customEndDate ?? now;

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Select Security Events date range',
    );

    if (range == null) return;

    _viewModel.setCustomDateRange(range.start, range.end);
  }

  Future<void> _confirmAcknowledgeVisible() async {
    final count = _viewModel.visibleUnacknowledgedCount;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Acknowledge $count visible alerts?'),
          content: Text(
            _viewModel.visibleUnacknowledgedIncludesCritical
                ? 'This includes critical alerts.'
                : 'Only currently visible unacknowledged alerts will be acknowledged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Acknowledge'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _viewModel.acknowledgeVisibleEvents();
    }
  }
}

class _SearchAndDateFilterRow extends StatelessWidget {
  final Widget searchField;
  final String dateLabel;
  final VoidCallback onDatePressed;

  const _SearchAndDateFilterRow({
    required this.searchField,
    required this.dateLabel,
    required this.onDatePressed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: searchField),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: compact ? 48 : 132,
                maxWidth: compact ? 56 : 168,
              ),
              child: AlertDateFilterButton(
                label: dateLabel,
                showLabel: !compact,
                onPressed: onDatePressed,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AcknowledgeVisibleAction extends StatelessWidget {
  final int count;
  final bool includesCritical;
  final bool isLoading;
  final VoidCallback onPressed;

  const _AcknowledgeVisibleAction({
    required this.count,
    required this.includesCritical,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  includesCritical
                      ? Icons.warning_amber_rounded
                      : Icons.done_all_outlined,
                  color: includesCritical
                      ? colorScheme.error
                      : colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    count == 0
                        ? 'No visible alerts need acknowledgement'
                        : '$count visible alerts unacknowledged',
                    style: AppTextStyles.caption.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: count == 0 || isLoading ? null : onPressed,
                icon: isLoading
                    ? const SizedBox(
                        width: AppSpacing.lg,
                        height: AppSpacing.lg,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all),
                label: const Text('Acknowledge Visible'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCenterSections extends StatelessWidget {
  final NotificationViewModel viewModel;
  final ValueChanged<AiEvent> onEventTap;

  const _AlertCenterSections({
    required this.viewModel,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final recentGroups = viewModel.groupedRecentActivity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recentGroups.isNotEmpty) ...[
          Text(
            'Timeline',
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GroupedAlertList(
            groups: recentGroups,
            severityFor: viewModel.severityFor,
            isAcknowledging: viewModel.isAcknowledging,
            onEventTap: onEventTap,
            onAcknowledge: viewModel.acknowledgeEvent,
          ),
        ],
      ],
    );
  }
}

class _InlineNotificationError extends StatelessWidget {
  final String message;

  const _InlineNotificationError({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.errorContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Error: $message',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationLoadingState extends StatelessWidget {
  const _NotificationLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _NotificationErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NotificationErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Unable to load security events',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
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

class _EmptyNotificationState extends StatelessWidget {
  const _EmptyNotificationState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.35,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No security events',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your home is currently secure.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFilteredNotificationState extends StatelessWidget {
  const _EmptyFilteredNotificationState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.3,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_alt_off_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No matching alerts',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Try a different filter or search term.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
