import 'package:flutter/material.dart';

import '../../domain/models/ai_event.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AiEventList extends StatelessWidget {
  final List<AiEvent> events;
  final ValueChanged<AiEvent>? onEventTap;

  const AiEventList({super.key, required this.events, this.onEventTap});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: Text('No alerts found')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        return AiEventListItem(
          event: events[index],
          onTap: onEventTap == null ? null : () => onEventTap!(events[index]),
        );
      },
    );
  }
}

class AiEventListItem extends StatelessWidget {
  final AiEvent event;
  final VoidCallback? onTap;

  const AiEventListItem({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final eventColor = event.isAcknowledged
        ? _safeColor(context)
        : _eventIconColor(event.eventType, context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: eventColor.withValues(alpha: 0.12),
                foregroundColor: eventColor,
                child: Icon(_eventIcon(event.eventType)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.displayType,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        _EventStatusChip(
                          label: event.isAcknowledged ? 'Done' : 'New',
                          color: event.isAcknowledged
                              ? _safeColor(context)
                              : eventColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(event.recognitionSummary),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Premise: ${event.premiseDisplay}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      _formatTimestamp(event.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      event.confidenceDisplay,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (event.imagePath != null &&
                        event.imagePath!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: AppSpacing.lg,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Snapshot available',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'No timestamp';

    final local = timestamp.toLocal();
    final value = local.toString();
    return value.length > 16 ? value.substring(0, 16) : value;
  }

  IconData _eventIcon(String eventType) {
    return switch (eventType) {
      'known_person' => Icons.person,
      'unknown_person' => Icons.warning_amber,
      'blacklisted_person' => Icons.block,
      'person_detected' => Icons.person_search,
      'fire_alert' => Icons.local_fire_department,
      'gas_alert' => Icons.gas_meter,
      'sensor_alert' => Icons.sensors,
      'system_error' => Icons.error_outline,
      'fall_detected' => Icons.emergency,
      'camera_offline' => Icons.videocam_off,
      _ => Icons.notifications,
    };
  }

  Color _eventIconColor(String eventType, BuildContext context) {
    return switch (eventType) {
      'known_person' => _safeColor(context),
      'unknown_person' => _warningColor(context),
      'blacklisted_person' => _dangerColor(context),
      'fire_alert' => _dangerColor(context),
      'gas_alert' => _dangerColor(context),
      'sensor_alert' => _dangerColor(context),
      'system_error' => _dangerColor(context),
      'fall_detected' => _dangerColor(context),
      'camera_offline' => _warningColor(context),
      _ => Theme.of(context).colorScheme.primary,
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

class _EventStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _EventStatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
