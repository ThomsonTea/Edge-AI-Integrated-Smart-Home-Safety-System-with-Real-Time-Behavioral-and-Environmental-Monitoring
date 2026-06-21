import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../viewmodels/camera_feed_viewmodel.dart';
import '../widgets/camera_widget.dart';
import '../widgets/screen_header.dart';

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

    final content = RefreshIndicator(
      onRefresh: _viewModel.loadCameraSession,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: ScreenHeader(
                  title: 'Camera Feed',
                  subtitle: _viewModel.jwtToken == null
                      ? 'Waiting for secure session'
                      : 'Secure live stream ready',
                  icon: Icons.videocam_outlined,
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
          const SizedBox(height: AppSpacing.lg),
          const _FutureImplementationCard(),
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
}

class _FutureImplementationCard extends StatelessWidget {
  const _FutureImplementationCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              color: colorScheme.primary,
              size: AppSpacing.xl,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Future Implementation',
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Multi-camera monitoring support is planned for future system expansion.',
                    style: AppTextStyles.body.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
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
