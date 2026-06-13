import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../viewmodels/camera_feed_viewmodel.dart';
import '../widgets/camera_widget.dart';

class CameraFeedScreen extends StatefulWidget {
  final bool showAppBar;

  const CameraFeedScreen({super.key, this.showAppBar = false});

  @override
  State<CameraFeedScreen> createState() => _CameraFeedScreenState();
}

class _CameraFeedScreenState extends State<CameraFeedScreen> {
  final CameraFeedViewModel _viewModel = CameraFeedViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.loadCameraSession();
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final content = RefreshIndicator(
      onRefresh: _viewModel.loadCameraSession,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Camera Feed', style: textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: AppSpacing.md,
                          color: _viewModel.jwtToken == null
                              ? _warningColor(context)
                              : _safeColor(context),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _viewModel.jwtToken == null
                                ? 'Waiting for secure session'
                                : 'Secure live stream ready',
                            style: textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh camera session',
                onPressed: _viewModel.isLoading
                    ? null
                    : _viewModel.loadCameraSession,
                color: colorScheme.primary,
                icon: _viewModel.isLoading
                    ? const SizedBox(
                        width: AppSpacing.xl,
                        height: AppSpacing.xl,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_viewModel.errorMessage != null) ...[
            _CameraStatusBanner(message: _viewModel.errorMessage!),
            const SizedBox(height: AppSpacing.lg),
          ],
          CameraWidget(jwtToken: _viewModel.jwtToken),
        ],
      ),
    );

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Camera Feed')),
      body: content,
    );
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
}

class _CameraStatusBanner extends StatelessWidget {
  final String message;

  const _CameraStatusBanner({required this.message});

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
                message,
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
