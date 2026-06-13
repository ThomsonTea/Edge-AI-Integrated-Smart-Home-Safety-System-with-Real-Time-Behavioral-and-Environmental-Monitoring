import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../../config/app_config.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class CameraWidget extends StatelessWidget {
  final String? jwtToken;

  const CameraWidget({super.key, required this.jwtToken});

  @override
  Widget build(BuildContext context) {
    final token = jwtToken?.trim();
    final colorScheme = Theme.of(context).colorScheme;
    final dangerColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dangerDark
        : AppColors.danger;

    return Container(
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: colorScheme.outline),
      ),
      clipBehavior: Clip.hardEdge,
      child: token == null || token.isEmpty || token == 'null'
          ? const _CameraMessage(
              icon: Icons.lock_outline,
              title: 'Camera Locked',
              message: 'Sign in again to view the secure camera feed.',
            )
          : Mjpeg(
              isLive: true,
              stream: '${AppConfig.apiBaseUrl}/camera/video_feed',
              headers: {'Authorization': 'Bearer $token'},
              error: (context, error, stack) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _CameraMessage(
                      icon: Icons.videocam_off_outlined,
                      iconColor: dangerColor,
                      title: 'Camera Offline',
                      message: error.toString(),
                    ),
                  ),
                );
              },
              loading: (context) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Connecting to Secure Feed...',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _CameraMessage extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String message;

  const _CameraMessage({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: iconColor ?? colorScheme.primary,
                size: AppSpacing.xxl,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
