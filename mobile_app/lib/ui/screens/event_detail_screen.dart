import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../domain/models/ai_event.dart';
import '../../viewmodels/event_detail_viewmodel.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final EventDetailViewModel _viewModel = EventDetailViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.loadEvent(id: widget.eventId);
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
    final event = _viewModel.event;

    return Scaffold(
      appBar: AppBar(title: const Text('Event Detail')),
      body: _buildBody(event),
    );
  }

  Widget _buildBody(AiEvent? event) {
    if (_viewModel.isLoading && event == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null && event == null) {
      return _EventDetailErrorState(
        message: _viewModel.errorMessage!,
        onRetry: () => _viewModel.loadEvent(id: widget.eventId),
      );
    }

    if (event == null) {
      return const Center(child: Text('Event not found'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(
              _eventIcon(event.eventType),
              color: _eventIconColor(event.eventType, context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                event.displayType,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          event.recognitionSummary,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 12),
        _EventSnapshot(imagePath: event.imagePath),
        const SizedBox(height: 16),
        if (_viewModel.errorMessage != null) ...[
          Text(
            'Error: ${_viewModel.errorMessage}',
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 12),
        ],
        _DetailRow(label: 'Recognition', value: event.recognitionSummary),
        if (!event.isUnknownPerson &&
            (event.profileName != null || event.profileId != null))
          _DetailRow(
            label: event.isKnownPerson ? 'Known Person' : 'Profile',
            value: event.profileDisplay,
          ),
        if (event.isUnknownPerson)
          const _DetailRow(
            label: 'Result',
            value: 'Unregistered person detected',
          ),
        _DetailRow(label: 'Premise', value: event.premiseDisplay),
        _DetailRow(
          label: 'Timestamp',
          value: _formatTimestamp(event.timestamp),
        ),
        _DetailRow(label: 'Confidence', value: event.confidenceDisplay),
        _DetailRow(
          label: 'Status',
          value: event.isAcknowledged ? 'Acknowledged' : 'New',
        ),
        const SizedBox(height: 20),
        if (!event.isAcknowledged)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _viewModel.isAcknowledging
                  ? null
                  : _viewModel.acknowledgeEvent,
              icon: _viewModel.isAcknowledging
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _viewModel.isAcknowledging
                    ? 'Acknowledging...'
                    : 'Acknowledge Event',
              ),
            ),
          ),
      ],
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'No timestamp';

    return timestamp.toLocal().toString();
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

class _EventSnapshot extends StatelessWidget {
  final String? imagePath;

  const _EventSnapshot({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final path = imagePath;

    if (path == null || path.isEmpty) {
      return const _SnapshotFallback(message: 'No snapshot available');
    }

    final imageUrl = _resolveImageUrl(path);
    final uri = Uri.tryParse(imageUrl);
    final canLoadNetworkImage =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    if (!canLoadNetworkImage) {
      return _SnapshotFallback(message: 'Snapshot path: $path');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _SnapshotFallback(message: 'Snapshot could not be loaded');
        },
      ),
    );
  }

  String _resolveImageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    if (path.startsWith('/storage')) {
      return '${AppConfig.serverBaseUrl}$path';
    }

    if (path.startsWith('storage/')) {
      return '${AppConfig.serverBaseUrl}/$path';
    }

    return path;
  }
}

class _SnapshotFallback extends StatelessWidget {
  final String message;

  const _SnapshotFallback({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _EventDetailErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EventDetailErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Error: $message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
