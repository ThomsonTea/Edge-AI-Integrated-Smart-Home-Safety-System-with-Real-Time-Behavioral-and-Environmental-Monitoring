import 'package:url_launcher/url_launcher.dart';

class PhoneCallService {
  Future<void> openDialer(String phoneNumber) async {
    final normalized = phoneNumber.trim();
    if (normalized.isEmpty) {
      throw Exception('Phone number is unavailable.');
    }

    final uri = Uri(scheme: 'tel', path: normalized);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw Exception('No phone application is available on this device.');
    }
  }
}
