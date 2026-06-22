import 'package:flutter/material.dart';

import '../../domain/models/ai_event.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/notification_viewmodel.dart';
import 'alert_card.dart';

class GroupedAlertList extends StatelessWidget {
  final List<AlertGroup> groups;
  final AlertSeverity Function(String eventType) severityFor;
  final bool Function(AiEvent event) isAcknowledging;
  final bool Function(AiEvent event) isDeleting;
  final bool canDeleteEvents;
  final ValueChanged<AiEvent> onEventTap;
  final ValueChanged<AiEvent> onAcknowledge;
  final ValueChanged<AiEvent> onDelete;

  const GroupedAlertList({
    super.key,
    required this.groups,
    required this.severityFor,
    required this.isAcknowledging,
    required this.isDeleting,
    required this.canDeleteEvents,
    required this.onEventTap,
    required this.onAcknowledge,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          Text(
            group.title,
            style: AppTextStyles.sectionTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final event in group.events) ...[
            AlertCard(
              event: event,
              severity: severityFor(event.eventType),
              isAcknowledging: isAcknowledging(event),
              isDeleting: isDeleting(event),
              canDelete: canDeleteEvents,
              onTap: () => onEventTap(event),
              onAcknowledge: () => onAcknowledge(event),
              onDelete: () => onDelete(event),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
