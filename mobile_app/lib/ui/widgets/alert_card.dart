import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../domain/models/ai_event.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/notification_viewmodel.dart';

class AlertCard extends StatelessWidget {
  final AiEvent event;
  final AlertSeverity severity;
  final bool isAcknowledging;
  final bool isDeleting;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onAcknowledge;
  final VoidCallback? onDelete;

  const AlertCard({
    super.key,
    required this.event,
    required this.severity,
    required this.isAcknowledging,
    this.isDeleting = false,
    this.canDelete = false,
    required this.onTap,
    required this.onAcknowledge,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final severityColor = _severityColor(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: severityColor.withValues(alpha: 0.12),
                    foregroundColor: severityColor,
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
                                style: AppTextStyles.body.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _Badge(label: _severityLabel, color: severityColor),
                            const SizedBox(width: AppSpacing.xs),
                            PopupMenuButton<_AlertCardAction>(
                              tooltip: 'Event actions',
                              onSelected: (action) {
                                switch (action) {
                                  case _AlertCardAction.viewDetails:
                                    onTap();
                                    break;
                                  case _AlertCardAction.acknowledge:
                                    onAcknowledge();
                                    break;
                                  case _AlertCardAction.delete:
                                    onDelete?.call();
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: _AlertCardAction.viewDetails,
                                  child: ListTile(
                                    leading: Icon(Icons.open_in_new_outlined),
                                    title: Text('View Details'),
                                  ),
                                ),
                                if (!event.isAcknowledged)
                                  PopupMenuItem(
                                    value: _AlertCardAction.acknowledge,
                                    enabled: !isAcknowledging,
                                    child: const ListTile(
                                      leading: Icon(Icons.check_circle_outline),
                                      title: Text('Acknowledge'),
                                    ),
                                  ),
                                if (canDelete)
                                  PopupMenuItem(
                                    value: _AlertCardAction.delete,
                                    enabled: !isDeleting,
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.delete_outline,
                                        color: colorScheme.error,
                                      ),
                                      title: Text(
                                        isDeleting ? 'Deleting...' : 'Delete',
                                        style: TextStyle(
                                          color: colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _contextLine,
                          style: AppTextStyles.caption.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Premise: ${event.premiseDisplay}',
                          style: AppTextStyles.caption.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_thumbnailUrl != null) ...[
                    _SnapshotThumbnail(url: _thumbnailUrl!),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _MetaChip(
                          icon: Icons.schedule,
                          label: _formatTimestamp(event.timestamp),
                        ),
                        _MetaChip(
                          icon: Icons.analytics_outlined,
                          label: event.confidenceDisplay,
                        ),
                        _Badge(
                          label: event.isAcknowledged
                              ? 'Acknowledged'
                              : 'Unacknowledged',
                          color: event.isAcknowledged
                              ? _safeColor(context)
                              : severityColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!event.isAcknowledged) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: isAcknowledging ? null : onAcknowledge,
                    icon: isAcknowledging
                        ? const SizedBox(
                            width: AppSpacing.lg,
                            height: AppSpacing.lg,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Acknowledge'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _contextLine {
    final profile = event.profileName?.trim();
    if (profile != null && profile.isNotEmpty) {
      return 'Profile: $profile';
    }

    if (event.eventType == 'unknown_person') {
      return 'Unregistered person detected';
    }

    return event.recognitionSummary;
  }

  String get _severityLabel {
    return switch (severity) {
      AlertSeverity.critical => 'Critical',
      AlertSeverity.warning => 'Warning',
      AlertSeverity.info => 'Info',
    };
  }

  String? get _thumbnailUrl {
    final path = event.imagePath?.trim();
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '${AppConfig.serverBaseUrl}$path';
    return '${AppConfig.serverBaseUrl}/$path';
  }

  IconData _eventIcon(String eventType) {
    return switch (eventType) {
      'known_person' => Icons.person,
      'unknown_person' => Icons.warning_amber,
      'fall_detected' => Icons.emergency_outlined,
      'prolonged_inactivity' => Icons.personal_injury_outlined,
      'fire_alert' => Icons.local_fire_department_outlined,
      'gas_alert' => Icons.gas_meter_outlined,
      'system_error' => Icons.error_outline,
      'camera_offline' => Icons.videocam_off_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  Color _severityColor(BuildContext context) {
    return switch (severity) {
      AlertSeverity.critical => _dangerColor(context),
      AlertSeverity.warning => _warningColor(context),
      AlertSeverity.info => Theme.of(context).colorScheme.primary,
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

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'No timestamp';
    final local = timestamp.toLocal();
    final value = local.toString();
    return value.length > 16 ? value.substring(0, 16) : value;
  }
}

enum _AlertCardAction { viewDetails, acknowledge, delete }

class _SnapshotThumbnail extends StatelessWidget {
  final String url;

  const _SnapshotThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 72,
            height: 72,
            color: colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSpacing.lg, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

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
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
