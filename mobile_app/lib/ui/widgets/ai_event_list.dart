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
    final confidence = event.confidenceScore == null
        ? 'Confidence unavailable'
        : '${event.confidenceScore!.toStringAsFixed(2)}% confidence';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          event.isAcknowledged ? Icons.check_circle : Icons.warning,
          color: event.isAcknowledged ? Colors.green : Colors.orange,
        ),
        title: Text(event.eventType),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(_formatTimestamp(event.timestamp)),
            Text(confidence),
            if (event.imagePath != null && event.imagePath!.isNotEmpty)
              Text('Image: ${event.imagePath}'),
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
}
