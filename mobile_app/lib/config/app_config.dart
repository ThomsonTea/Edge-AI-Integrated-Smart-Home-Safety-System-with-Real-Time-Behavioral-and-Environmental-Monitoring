abstract final class AppConfig {
  static const String serverBaseUrl = 'https://api.philous.me';
  static const String apiBaseUrl = '$serverBaseUrl/api/dev';
  static const String jwtTokenKey = 'jwt_token';

  static String get wsBaseUrl {
    if (apiBaseUrl.startsWith('https://')) {
      return apiBaseUrl.replaceFirst('https://', 'wss://');
    }

    if (apiBaseUrl.startsWith('http://')) {
      return apiBaseUrl.replaceFirst('http://', 'ws://');
    }

    return apiBaseUrl;
  }
}
