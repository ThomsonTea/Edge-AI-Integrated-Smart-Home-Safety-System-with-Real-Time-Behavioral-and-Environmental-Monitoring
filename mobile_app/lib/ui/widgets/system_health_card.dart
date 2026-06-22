import 'package:flutter/material.dart';

import '../../domain/models/dashboard_summary.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class SystemHealthCard extends StatelessWidget {
  final DashboardSummary summary;

  const SystemHealthCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('System Health', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.md),
            _HealthRow(
              icon: Icons.dns_outlined,
              label: 'Backend',
              value: summary.backendOnline ? 'Online' : 'Offline',
              state: summary.backendOnline
                  ? _HealthState.success
                  : _HealthState.danger,
            ),
            _HealthRow(
              icon: Icons.videocam_outlined,
              label: 'Camera',
              value: summary.cameraOnline
                  ? 'Online'
                  : _titleCase(summary.cameraStatus),
              state: summary.cameraOnline
                  ? _HealthState.success
                  : _HealthState.warning,
            ),
            _HealthRow(
              icon: Icons.memory_outlined,
              label: 'AI Detection',
              value: summary.aiDetectionActive ? 'Active' : 'Inactive',
              state: summary.aiDetectionActive
                  ? _HealthState.success
                  : _HealthState.warning,
            ),
            _HealthRow(
              icon: Icons.sensors_outlined,
              label: 'Sensor Node',
              value: _sensorStatusLabel(summary.sensorStatus),
              state: _sensorHealthState(summary.sensorStatus),
            ),
          ],
        ),
      ),
    );
  }

  static String _sensorStatusLabel(String status) {
    final normalized = status.trim().toLowerCase();

    if (normalized == 'connected') return 'Online';
    if (normalized == 'disconnected') return 'Offline';
    if (normalized == 'disabled') return 'Disabled';
    if (normalized == 'connecting' || normalized == 'unknown') {
      return 'Connecting';
    }

    return _titleCase(status);
  }

  static _HealthState _sensorHealthState(String status) {
    final normalized = status.trim().toLowerCase();

    return switch (normalized) {
      'connected' => _HealthState.success,
      'disconnected' => _HealthState.danger,
      'disabled' => _HealthState.neutral,
      'connecting' || 'unknown' => _HealthState.warning,
      _ => _HealthState.warning,
    };
  }

  static String _titleCase(String value) {
    return value
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

enum _HealthState { success, warning, danger, neutral }

class _HealthRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final _HealthState state;

  const _HealthRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTextStyles.body)),
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                value,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _stateColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return switch (state) {
      _HealthState.success =>
        brightness == Brightness.dark
            ? AppColors.successDark
            : AppColors.success,
      _HealthState.warning =>
        brightness == Brightness.dark
            ? AppColors.warningDark
            : AppColors.warning,
      _HealthState.danger =>
        brightness == Brightness.dark ? AppColors.dangerDark : AppColors.danger,
      _HealthState.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }
}
