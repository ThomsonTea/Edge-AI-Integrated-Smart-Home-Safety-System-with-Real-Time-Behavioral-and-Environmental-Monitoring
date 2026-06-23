import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/domain/models/analytics_models.dart';
import 'package:smart_home_security_system/viewmodels/analytics_viewmodel.dart';

void main() {
  test('defaults to sensor trends with temperature and humidity selected', () {
    final viewModel = AnalyticsViewModel();

    expect(viewModel.selectedSection, AnalyticsSection.sensorTrends);
    expect(viewModel.selectedSensorMetrics, {
      SensorMetric.temperature,
      SensorMetric.humidity,
    });
    expect(viewModel.selectedSensorMetrics.contains(SensorMetric.gas), isFalse);
  });

  test('updates selected analytics section', () {
    final viewModel = AnalyticsViewModel();

    viewModel.setSelectedSection(AnalyticsSection.securityEvents);

    expect(viewModel.selectedSection, AnalyticsSection.securityEvents);
  });

  test('toggles sensor metrics but keeps at least one selected', () {
    final viewModel = AnalyticsViewModel();

    viewModel.toggleSensorMetric(SensorMetric.gas);
    expect(viewModel.selectedSensorMetrics.contains(SensorMetric.gas), isTrue);

    viewModel.toggleSensorMetric(SensorMetric.temperature);
    viewModel.toggleSensorMetric(SensorMetric.humidity);
    viewModel.toggleSensorMetric(SensorMetric.gas);

    expect(viewModel.selectedSensorMetrics, {SensorMetric.gas});
  });

  test('defaults to all event category and all analytics event types', () {
    final viewModel = AnalyticsViewModel();

    expect(viewModel.selectedEventViewMode, EventViewMode.trend);
    expect(viewModel.selectedEventCategory, EventCategory.all);
    expect(viewModel.selectedEventTypes, analyticsEventTypes.toSet());
  });

  test('updates selected event view mode', () {
    final viewModel = AnalyticsViewModel();

    viewModel.setEventViewMode(EventViewMode.distribution);

    expect(viewModel.selectedEventViewMode, EventViewMode.distribution);
  });

  test('selecting event category selects only mapped event types', () {
    final viewModel = AnalyticsViewModel();

    viewModel.setEventCategory(EventCategory.securityEvents);
    expect(viewModel.selectedEventTypes, {
      'known_person',
      'unknown_person',
      'fall_detected',
      'prolonged_inactivity',
    });

    viewModel.setEventCategory(EventCategory.systemEvents);
    expect(viewModel.selectedEventTypes, {
      'gas_alert',
      'high_temperature',
      'sensor_offline',
    });
  });

  test('event categories expose security and system groups without fire', () {
    expect(EventCategory.values, [
      EventCategory.all,
      EventCategory.securityEvents,
      EventCategory.systemEvents,
    ]);
    expect(analyticsEventTypes.contains('fire_alert'), isFalse);
    expect(analyticsEventTypes.contains('fire_risk'), isFalse);
  });

  test('system events category includes sensor related event types', () {
    final viewModel = AnalyticsViewModel();

    viewModel.setEventCategory(EventCategory.systemEvents);

    expect(viewModel.selectedEventTypes, {
      'gas_alert',
      'high_temperature',
      'sensor_offline',
    });
  });

  test('manual event type toggle keeps at least one selected', () {
    final viewModel = AnalyticsViewModel();

    viewModel.setEventCategory(EventCategory.securityEvents);
    viewModel.toggleEventType('known_person');
    expect(viewModel.selectedEventTypes, {
      'unknown_person',
      'fall_detected',
      'prolonged_inactivity',
    });

    viewModel.toggleEventType('unknown_person');
    expect(viewModel.selectedEventTypes, {
      'fall_detected',
      'prolonged_inactivity',
    });

    viewModel.toggleEventType('gas_alert');
    expect(viewModel.selectedEventTypes, {
      'fall_detected',
      'prolonged_inactivity',
      'gas_alert',
    });
  });

  test('filtered event counts returns only selected event types', () {
    final viewModel = AnalyticsViewModel();

    final analytics = EventAnalytics(
      range: '7d',
      counts: const [
        EventCount(eventType: 'known_person', count: 2),
        EventCount(eventType: 'unknown_person', count: 3),
        EventCount(eventType: 'gas_alert', count: 4),
      ],
    );

    viewModel.setEventCategory(EventCategory.securityEvents);
    viewModel.debugSetEventAnalyticsForTest(analytics);

    expect(viewModel.filteredEventCounts.map((count) => count.eventType), [
      'known_person',
      'unknown_person',
    ]);
  });
}
