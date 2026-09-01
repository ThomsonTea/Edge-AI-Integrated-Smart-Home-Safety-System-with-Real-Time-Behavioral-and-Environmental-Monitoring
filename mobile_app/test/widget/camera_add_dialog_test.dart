import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/domain/models/security_camera.dart';
import 'package:smart_home_security_system/services/camera_service.dart';
import 'package:smart_home_security_system/services/token_service.dart';
import 'package:smart_home_security_system/theme/app_theme.dart';
import 'package:smart_home_security_system/ui/screens/camera_feed_screen.dart';
import 'package:smart_home_security_system/viewmodels/camera_feed_viewmodel.dart';

class _CameraServiceStub extends CameraService {
  final List<SecurityCamera> cameras;
  Map<String, dynamic>? addedPayload;
  Map<String, dynamic>? updatedPayload;

  _CameraServiceStub({this.cameras = const []});

  @override
  Future<List<SecurityCamera>> fetchCameras() async => cameras;

  @override
  Future<void> addCamera(Map<String, dynamic> payload) async {
    addedPayload = payload;
  }

  @override
  Future<void> updateCamera(int id, Map<String, dynamic> payload) async {
    updatedPayload = payload;
  }
}

class _TokenServiceStub extends TokenService {
  @override
  Future<String?> getToken() async =>
      'eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJyb2xlIjoib3duZXIifQ.signature';

  @override
  Future<String?> getCurrentUserRole() async => 'owner';
}

void main() {
  testWidgets('add camera dialog renders and remains interactive on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final viewModel = CameraFeedViewModel(
      tokenService: _TokenServiceStub(),
      cameraService: _CameraServiceStub(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: CameraFeedScreen(viewModel: viewModel)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Connecting to Secure Feed...'), findsNothing);

    await tester.tap(find.byTooltip('Add camera'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Add Camera'),
      ),
      findsOneWidget,
    );
    expect(find.text('Camera IP address *'), findsOneWidget);
    expect(find.text('ONVIF port *'), findsOneWidget);
    expect(find.text('Stream URL (optional)'), findsOneWidget);
    expect(find.text('Add camera'), findsOneWidget);
    expect(find.textContaining('Tapo'), findsNothing);
    expect(find.text('Scan'), findsNothing);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('camera can be added with a direct RTSP URL', (tester) async {
    final service = _CameraServiceStub();
    final viewModel = CameraFeedViewModel(
      tokenService: _TokenServiceStub(),
      cameraService: service,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: CameraFeedScreen(viewModel: viewModel)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add camera'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Camera IP address *'),
      '192.168.1.50',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Stream URL (optional)'),
      'rtsp://192.168.1.50:554/stream1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Camera name *'),
      'Front door',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Camera username *'),
      'camera-user',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Camera password *'),
      'camera-password',
    );
    await tester.tap(find.text('Add camera'));
    await tester.pumpAndSettle();

    expect(service.addedPayload, isNotNull);
    expect(
      service.addedPayload!['stream_url'],
      'rtsp://192.168.1.50:554/stream1',
    );
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('camera can be edited without replacing its saved password', (
    tester,
  ) async {
    final service = _CameraServiceStub(
      cameras: const [
        SecurityCamera(
          id: 7,
          name: 'Living Room',
          location: 'Ground Floor',
          connectionStatus: 'online',
          streamUrl: 'rtsp://192.168.1.50:554/stream1',
          username: 'camera-user',
          enabled: true,
          detectionEnabled: true,
          snapshotEnabled: true,
          confidenceThreshold: .7,
        ),
      ],
    );
    final viewModel = CameraFeedViewModel(
      tokenService: _TokenServiceStub(),
      cameraService: service,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: CameraFeedScreen(viewModel: viewModel)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit camera'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Camera'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(service.updatedPayload, isNotNull);
    expect(service.updatedPayload!['name'], 'Living Room');
    expect(service.updatedPayload!.containsKey('password'), isFalse);
    expect(find.byType(Dialog), findsNothing);
  });
}
