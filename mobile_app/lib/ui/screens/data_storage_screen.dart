import 'package:flutter/material.dart';

import '../../domain/models/retention_settings.dart';
import '../../theme/app_spacing.dart';
import '../../viewmodels/retention_settings_viewmodel.dart';
import '../widgets/screen_header.dart';

class DataStorageScreen extends StatefulWidget {
  const DataStorageScreen({super.key});

  @override
  State<DataStorageScreen> createState() => _DataStorageScreenState();
}

class _DataStorageScreenState extends State<DataStorageScreen> {
  final RetentionSettingsViewModel _viewModel = RetentionSettingsViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onUpdate);
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onUpdate);
    _viewModel.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settings = _viewModel.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Data & Storage')),
      body: settings == null
          ? _buildUnavailableState()
          : RefreshIndicator(
              onRefresh: _viewModel.load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const ScreenHeader(
                    title: 'Data & Storage',
                    subtitle:
                        'Control how long security evidence and sensor history are kept',
                    icon: Icons.storage_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_viewModel.errorMessage != null ||
                      _viewModel.successMessage != null) ...[
                    _MessageCard(
                      error: _viewModel.errorMessage,
                      success: _viewModel.successMessage,
                      onDismiss: _viewModel.clearMessages,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  _RetentionPeriodsCard(
                    settings: settings,
                    enabled: !_viewModel.isSaving && !_viewModel.isCleaning,
                    onChanged: _viewModel.updateDraft,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ProtectionCard(
                    settings: settings,
                    enabled: !_viewModel.isSaving && !_viewModel.isCleaning,
                    onChanged: _viewModel.updateDraft,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _CleanupCard(
                    isCleaning: _viewModel.isCleaning,
                    enabled: !_viewModel.isSaving,
                    onCleanup: _confirmCleanup,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: _viewModel.isSaving || _viewModel.isCleaning
                        ? null
                        : _save,
                    icon: _viewModel.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _viewModel.isSaving ? 'Saving...' : 'Save Settings',
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUnavailableState() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storage_outlined, size: 42),
            const SizedBox(height: AppSpacing.md),
            Text(
              _viewModel.errorMessage ?? 'Retention settings are unavailable',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              onPressed: _viewModel.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final success = await _viewModel.save();
    if (!mounted) return;
    final message = success
        ? _viewModel.successMessage
        : _viewModel.errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _confirmCleanup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Run cleanup now?'),
        content: const Text(
          'Expired data will be permanently removed using the currently saved '
          'server settings. Unsaved changes on this screen are not used.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Run Cleanup'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _viewModel.cleanup();
    if (!mounted) return;
    final message = _viewModel.successMessage ?? _viewModel.errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _RetentionPeriodsCard extends StatelessWidget {
  final RetentionSettings settings;
  final bool enabled;
  final ValueChanged<RetentionSettings> onChanged;

  const _RetentionPeriodsCard({
    required this.settings,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Retention periods',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Older records are removed by the daily cleanup process.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            _DaysDropdown(
              label: 'Security events',
              value: settings.eventRetentionDays,
              enabled: enabled,
              onChanged: (value) =>
                  onChanged(settings.copyWith(eventRetentionDays: value)),
            ),
            const SizedBox(height: AppSpacing.md),
            _DaysDropdown(
              label: 'Sensor readings',
              value: settings.sensorRetentionDays,
              enabled: enabled,
              onChanged: (value) =>
                  onChanged(settings.copyWith(sensorRetentionDays: value)),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatically remove old images'),
              subtitle: const Text(
                'Event details remain available after an expired image is removed.',
              ),
              value: settings.autoDeleteImages,
              onChanged: enabled
                  ? (value) =>
                        onChanged(settings.copyWith(autoDeleteImages: value))
                  : null,
            ),
            if (settings.autoDeleteImages) ...[
              const SizedBox(height: AppSpacing.sm),
              _DaysDropdown(
                label: 'Alert images',
                value: settings.imageRetentionDays,
                enabled: enabled,
                onChanged: (value) =>
                    onChanged(settings.copyWith(imageRetentionDays: value)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  final RetentionSettings settings;
  final bool enabled;
  final ValueChanged<RetentionSettings> onChanged;

  const _ProtectionCard({
    required this.settings,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                'Protected evidence',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SwitchListTile.adaptive(
              title: const Text('Keep unacknowledged events'),
              subtitle: const Text(
                'Preserve alerts that have not been reviewed.',
              ),
              secondary: const Icon(Icons.mark_email_unread_outlined),
              value: settings.preserveUnacknowledged,
              onChanged: enabled
                  ? (value) => onChanged(
                      settings.copyWith(preserveUnacknowledged: value),
                    )
                  : null,
            ),
            SwitchListTile.adaptive(
              title: const Text('Keep critical events'),
              subtitle: const Text(
                'Preserve critical safety and security evidence.',
              ),
              secondary: const Icon(Icons.gpp_maybe_outlined),
              value: settings.preserveCritical,
              onChanged: enabled
                  ? (value) =>
                        onChanged(settings.copyWith(preserveCritical: value))
                  : null,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'Pinned events are always protected regardless of these settings.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CleanupCard extends StatelessWidget {
  final bool isCleaning;
  final bool enabled;
  final VoidCallback onCleanup;

  const _CleanupCard({
    required this.isCleaning,
    required this.enabled,
    required this.onCleanup,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
        leading: const Icon(Icons.cleaning_services_outlined),
        title: const Text('Manual cleanup'),
        subtitle: const Text(
          'Remove data that has already passed its saved retention period.',
        ),
        trailing: FilledButton.tonal(
          onPressed: enabled && !isCleaning ? onCleanup : null,
          child: isCleaning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Clean Now'),
        ),
      ),
    );
  }
}

class _DaysDropdown extends StatelessWidget {
  static const _standardDays = [7, 30, 90, 180, 365, 730, 3650];
  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _DaysDropdown({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final values = {..._standardDays, value}.toList()..sort();
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final days in values)
          DropdownMenuItem(value: days, child: Text(_label(days))),
      ],
      onChanged: enabled
          ? (next) => next == null ? null : onChanged(next)
          : null,
    );
  }

  String _label(int days) {
    if (days == 3650) return '10 years';
    if (days % 365 == 0) return '${days ~/ 365} year${days == 365 ? '' : 's'}';
    return '$days days';
  }
}

class _MessageCard extends StatelessWidget {
  final String? error;
  final String? success;
  final VoidCallback onDismiss;

  const _MessageCard({
    required this.error,
    required this.success,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isError = error != null;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: isError ? colors.errorContainer : colors.primaryContainer,
      borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
      child: ListTile(
        leading: Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
        ),
        title: Text(error ?? success ?? ''),
        trailing: IconButton(
          onPressed: onDismiss,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}
