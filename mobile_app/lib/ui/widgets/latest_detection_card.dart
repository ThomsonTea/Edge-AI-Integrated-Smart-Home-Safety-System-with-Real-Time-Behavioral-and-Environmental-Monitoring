import 'package:flutter/material.dart';

import '../../domain/models/ai_event.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class LatestDetectionCard extends StatelessWidget {
  final AiEvent? event;
  final ValueChanged<int> onOpenEvent;

  const LatestDetectionCard({
    super.key,
    required this.event,
    required this.onOpenEvent,
  });

  @override
  Widget build(BuildContext context) {
    final currentEvent = event;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: currentEvent == null ? null : () => onOpenEvent(currentEvent.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: currentEvent == null
              ? const _NoDetectionContent()
              : _DetectionContent(event: currentEvent),
        ),
      ),
    );
  }
}

class _NoDetectionContent extends StatelessWidget {
  const _NoDetectionContent();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.onSurfaceVariant,
          child: const Icon(Icons.visibility_off_outlined),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Latest Detection', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'No detections recorded yet',
                style: AppTextStyles.body.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetectionContent extends StatelessWidget {
  final AiEvent event;

  const _DetectionContent({required this.event});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Icon(_eventIcon(event.eventType)),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Latest Detection', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(event.displayType, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _details,
                style: AppTextStyles.caption.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      ],
    );
  }

  String get _details {
    final pieces = <String>[];
    final person = event.profileName?.trim();
    final premise = event.premiseName?.trim();

    if (person != null && person.isNotEmpty) {
      pieces.add(person);
    } else if (event.eventType == 'known_person') {
      pieces.add('Known person');
    }

    if (premise != null && premise.isNotEmpty) {
      pieces.add(premise);
    }

    pieces.add(_timeAgo(event.timestamp));
    return pieces.join(' • ');
  }

  IconData _eventIcon(String eventType) {
    return switch (eventType) {
      'known_person' => Icons.person_outline,
      'unknown_person' => Icons.person_search_outlined,
      'fall_detected' => Icons.emergency_outlined,
      'prolonged_inactivity' => Icons.personal_injury_outlined,
      'fire_alert' => Icons.local_fire_department_outlined,
      'gas_alert' => Icons.gas_meter_outlined,
      'camera_offline' => Icons.videocam_off_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  String _timeAgo(DateTime? timestamp) {
    if (timestamp == null) return 'No timestamp';

    final elapsed = DateTime.now().difference(timestamp.toLocal());

    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} minutes ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours} hours ago';
    return '${elapsed.inDays} days ago';
  }
}
