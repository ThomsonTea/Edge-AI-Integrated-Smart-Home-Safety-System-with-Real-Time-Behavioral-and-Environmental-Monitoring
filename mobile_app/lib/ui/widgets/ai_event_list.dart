import 'package:flutter/material.dart';

import '../../domain/models/ai_event.dart';

class AiEventList extends StatelessWidget {
  final List<AiEvent> events;
  final ValueChanged<AiEvent>? onEventTap;

  const AiEventList({super.key, required this.events, this.onEventTap});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('No alerts found')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
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
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          _eventIcon(event.eventType),
          color: event.isAcknowledged
              ? Colors.green
              : _eventIconColor(event.eventType, context),
        ),
        title: Text(event.displayType),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(event.recognitionSummary),
            Text('Premise: ${event.premiseDisplay}'),
            Text(_formatTimestamp(event.timestamp)),
            Text(event.confidenceDisplay),
            if (event.imagePath != null && event.imagePath!.isNotEmpty)
              const Text('Snapshot available'),
          ],
        ),
        trailing: event.isAcknowledged ? const Text('Done') : const Text('New'),
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
      'person_detected' => Icons.person_search,
      'sensor_alert' => Icons.sensors,
      'fall_detected' => Icons.emergency,
      'camera_offline' => Icons.videocam_off,
      _ => Icons.notifications,
    };
  }

  Color _eventIconColor(String eventType, BuildContext context) {
    return switch (eventType) {
      'known_person' => Colors.green,
      'unknown_person' => Colors.orange,
      'sensor_alert' => Colors.red,
      'fall_detected' => Colors.red,
      'camera_offline' => Colors.grey,
      _ => Theme.of(context).colorScheme.primary,
    };
  }
}
