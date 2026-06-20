import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../domain/models/ai_event.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _EventDetailHeader(
          event: event,
          icon: _eventIcon(event.eventType),
          color: _eventIconColor(event.eventType, context),
        ),
        const SizedBox(height: AppSpacing.lg),
        _EventSnapshot(imagePath: event.imagePath),
        const SizedBox(height: AppSpacing.lg),
        if (_viewModel.errorMessage != null) ...[
          _InlineDetailError(message: _viewModel.errorMessage!),
          const SizedBox(height: AppSpacing.md),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  label: 'Recognition',
                  value: event.recognitionSummary,
                ),
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
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!event.isAcknowledged)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _viewModel.isAcknowledging
                  ? null
                  : _viewModel.acknowledgeEvent,
              icon: _viewModel.isAcknowledging
                  ? const SizedBox(
                      width: AppSpacing.lg,
                      height: AppSpacing.lg,
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
      'blacklisted_person' => Icons.block,
      'person_detected' => Icons.person_search,
      'fire_alert' => Icons.local_fire_department,
      'gas_alert' => Icons.gas_meter,
      'sensor_alert' => Icons.sensors,
      'system_error' => Icons.error_outline,
      'fall_detected' => Icons.emergency,
      'prolonged_inactivity' => Icons.personal_injury,
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
      'prolonged_inactivity' => _dangerColor(context),
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

class _EventDetailHeader extends StatelessWidget {
  final AiEvent event;
  final IconData icon;
  final Color color;

  const _EventDetailHeader({
    required this.event,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.displayType,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    event.recognitionSummary,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Image.network(
          imageUrl,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _SnapshotFallback(message: 'Snapshot could not be loaded');
          },
        ),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
              'Unable to load event detail',
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

class _InlineDetailError extends StatelessWidget {
  final String message;

  const _InlineDetailError({required this.message});

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
