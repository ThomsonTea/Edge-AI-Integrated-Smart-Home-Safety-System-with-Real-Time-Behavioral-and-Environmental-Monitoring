import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import 'event_service.dart';
import 'notification_service.dart';
import 'token_service.dart';

typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

class NotificationWebSocketService {
  NotificationWebSocketService({
    TokenService? tokenService,
    EventService? eventService,
    NotificationService? notificationService,
    WebSocketChannelFactory? channelFactory,
  }) : _tokenService = tokenService ?? TokenService(),
       _eventService = eventService ?? EventService(),
       _notificationService =
           notificationService ?? NotificationService.instance,
       _channelFactory = channelFactory ?? IOWebSocketChannel.connect;

  static final NotificationWebSocketService instance =
      NotificationWebSocketService();

  final TokenService _tokenService;
  final EventService _eventService;
  final NotificationService _notificationService;
  final WebSocketChannelFactory _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  DateTime? _sessionStartedAt;
  bool _hasEstablishedBaseline = false;
  bool _shouldReconnect = false;
  bool _isConnecting = false;

  @visibleForTesting
  bool get shouldReconnect => _shouldReconnect;

  Future<void> start() async {
    _sessionStartedAt ??= DateTime.now().toUtc();
    _shouldReconnect = true;
    await _notificationService.initialize();
    await _establishNotificationBaseline();
    await _connect();
    unawaited(recoverMissedEvents());
  }

  Future<void> stop() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _sessionStartedAt = null;
    _hasEstablishedBaseline = false;
  }

  Future<void> recoverMissedEvents({int limit = 20}) async {
    try {
      final payloads = await _eventService.fetchRecentNotificationPayloads(
        limit: limit,
      );

      for (final payload in payloads.reversed) {
        if (_wasCreatedAfterSessionStart(payload)) {
          await _notificationService.showAiEventNotification(payload);
        }
      }
    } catch (error) {
      debugPrint('Failed to recover missed notifications: $error');
    }
  }

  Future<void> _connect() async {
    if (_isConnecting || !_shouldReconnect) {
      return;
    }

    _isConnecting = true;

    try {
      final token = await _tokenService.getToken();

      if (token == null || token.isEmpty || token == 'null') {
        _stopForAuthFailure('Missing notification WebSocket token.');
        return;
      }

      final uri = Uri.parse(
        '${AppConfig.wsBaseUrl}/ws/notifications',
      ).replace(queryParameters: {'token': token.trim()});

      _channel = _channelFactory(uri);
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (error) {
          debugPrint('Notification WebSocket error: $error');
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (error) {
      debugPrint('Notification WebSocket connection failed: $error');
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message.toString());

      if (decoded is Map<String, dynamic>) {
        if (_wasCreatedAfterSessionStart(decoded)) {
          unawaited(_notificationService.showAiEventNotification(decoded));
        }
      }
    } catch (error) {
      debugPrint('Invalid notification payload: $error');
    }
  }

  void _handleDisconnect() {
    final closeCode = _channel?.closeCode;
    final closeReason = _channel?.closeReason;
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    if (_isAuthClose(closeCode, closeReason)) {
      _stopForAuthFailure(
        'Notification WebSocket auth closed: ${closeReason ?? closeCode}',
      );
      return;
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _reconnectTimer != null) {
      return;
    }

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      unawaited(_connect());
      unawaited(recoverMissedEvents(limit: 10));
    });
  }

  Future<void> _establishNotificationBaseline() async {
    if (_hasEstablishedBaseline) {
      return;
    }

    _hasEstablishedBaseline = true;

    try {
      final payloads = await _eventService.fetchRecentNotificationPayloads(
        limit: 100,
      );

      for (final payload in payloads) {
        if (!_wasCreatedAfterSessionStart(payload)) {
          await _notificationService.markAiEventSeen(payload);
        }
      }
    } catch (error) {
      debugPrint('Failed to establish notification baseline: $error');
    }
  }

  bool _wasCreatedAfterSessionStart(Map<String, dynamic> payload) {
    final sessionStartedAt = _sessionStartedAt;

    if (sessionStartedAt == null) {
      return false;
    }

    final rawTimestamp = payload['timestamp']?.toString();
    if (rawTimestamp == null || rawTimestamp.isEmpty) {
      return false;
    }

    final timestamp = DateTime.tryParse(rawTimestamp)?.toUtc();
    if (timestamp == null) {
      return false;
    }

    return !timestamp.isBefore(sessionStartedAt);
  }

  bool _isAuthClose(int? closeCode, String? closeReason) {
    return closeCode == 1008 ||
        closeReason == 'token_expired' ||
        closeReason == 'auth_failed';
  }

  void _stopForAuthFailure(String message) {
    debugPrint(message);
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
}
