import 'package:flutter/material.dart';

import '../../domain/models/ai_event.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class LatestCriticalEventCard extends StatelessWidget {
  final AiEvent? event;
  final ValueChanged<int> onOpenEvent;

  const LatestCriticalEventCard({
    super.key,
    required this.event,
    required this.onOpenEvent,
  });

  @override
  Widget build(BuildContext context) {
    final criticalEvent = event;
    final dangerColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dangerDark
        : AppColors.danger;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.priority_high, color: dangerColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Latest Critical Event',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (criticalEvent == null)
              Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text('No critical events found for this premise.'),
                  ),
                ],
              )
            else ...[
              Text(
                criticalEvent.displayType,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Time: ${_formatTimestamp(criticalEvent.timestamp)}'),
              Text('Confidence: ${criticalEvent.confidenceDisplay}'),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => onOpenEvent(criticalEvent.id),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Event Detail'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'No timestamp';

    final local = timestamp.toLocal().toString();
    return local.length > 16 ? local.substring(0, 16) : local;
  }
}
