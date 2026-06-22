import 'package:flutter/material.dart';

import '../../domain/models/sensor_snapshot.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class EnvironmentSnapshotCard extends StatelessWidget {
  final SensorSnapshot snapshot;
  final bool isLoading;
  final String? errorMessage;

  const EnvironmentSnapshotCard({
    super.key,
    required this.snapshot,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: const Icon(Icons.eco_outlined),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Environment Snapshot',
                    style: AppTextStyles.sectionTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (isLoading)
                    const _EnvironmentLoadingState()
                  else if (!snapshot.isConnected ||
                      !snapshot.hasCompleteReadings)
                    _EnvironmentOfflineState(errorMessage: errorMessage)
                  else
                    _EnvironmentReadings(snapshot: snapshot),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvironmentLoadingState extends StatelessWidget {
  const _EnvironmentLoadingState();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: AppSpacing.xl,
          height: AppSpacing.xl,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Loading sensor data...',
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EnvironmentOfflineState extends StatelessWidget {
  final String? errorMessage;

  const _EnvironmentOfflineState({this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.sensors_off_outlined, color: colorScheme.error),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Sensor Offline',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Last Updated: Unavailable',
          style: AppTextStyles.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Unable to refresh sensor data.',
            style: AppTextStyles.caption.copyWith(color: colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _EnvironmentReadings extends StatelessWidget {
  final SensorSnapshot snapshot;

  const _EnvironmentReadings({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ReadingTile(
                icon: Icons.thermostat_outlined,
                label: 'Temperature',
                value: '${_formatDecimal(snapshot.temperature)}°C',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ReadingTile(
                icon: Icons.water_drop_outlined,
                label: 'Humidity',
                value: '${_formatDecimal(snapshot.humidity)}%',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ReadingTile(
                icon: Icons.air_outlined,
                label: 'Gas Level',
                value: snapshot.gas?.toString() ?? '-',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ReadingTile(
                icon: Icons.sensors_outlined,
                label: 'Sensor Status',
                value: _formatStatus(snapshot.status),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _ReadingTile(
                icon: Icons.schedule_outlined,
                label: 'Last Updated',
                value: _relativeTime(snapshot.lastUpdated),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDecimal(double? value) {
    if (value == null) return '-';
    final rounded = value.toStringAsFixed(1);
    return rounded.endsWith('.0') ? value.toStringAsFixed(0) : rounded;
  }

  String _relativeTime(DateTime? value) {
    if (value == null) return 'Unavailable';

    final now = DateTime.now();
    final localValue = value.toLocal();
    final difference = now.difference(localValue);

    if (difference.inSeconds < 5) return 'Just now';
    if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  String _formatStatus(String status) {
    final normalized = status.trim().replaceAll('_', ' ');
    if (normalized.isEmpty) return 'Unknown';

    return normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }
}

class _ReadingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadingTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.sectionTitle.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
