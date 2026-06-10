import '../domain/models/ai_event.dart';
import 'event_service.dart';

class AlertService {
  final EventService _eventService;

  AlertService({EventService? eventService})
    : _eventService = eventService ?? EventService();

  Future<List<AiEvent>> fetchAlerts() => _eventService.fetchEvents();
}
