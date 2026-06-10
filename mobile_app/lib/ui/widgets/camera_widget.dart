import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../../config/app_config.dart';

class CameraWidget extends StatelessWidget {
  final String? jwtToken;

  const CameraWidget({super.key, required this.jwtToken});

  @override
  Widget build(BuildContext context) {
    final token = jwtToken?.trim();

    return Container(
      height: 240,
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      clipBehavior: Clip.hardEdge,
      child: token == null || token.isEmpty || token == 'null'
          ? const _CameraMessage(
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
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Camera Offline\n$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
              loading: (context) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.redAccent),
                      SizedBox(height: 10),
                      Text(
                        'Connecting to Secure Feed...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _CameraMessage extends StatelessWidget {
  final String title;
  final String message;

  const _CameraMessage({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
