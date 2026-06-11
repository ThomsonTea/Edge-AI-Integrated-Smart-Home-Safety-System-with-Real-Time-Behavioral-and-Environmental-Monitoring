import 'package:flutter/material.dart';

import '../../domain/models/ai_event.dart';
import '../../routing/routes.dart';
import '../../viewmodels/event_history_viewmodel.dart';
import '../widgets/ai_event_list.dart';

class EventHistoryScreen extends StatefulWidget {
  final bool showAppBar;

  const EventHistoryScreen({super.key, this.showAppBar = false});

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen> {
  static const List<_EventTypeFilterOption> _eventTypeOptions = [
    _EventTypeFilterOption(value: 'person_detected', label: 'Person Detected'),
    _EventTypeFilterOption(value: 'known_person', label: 'Known Person'),
    _EventTypeFilterOption(value: 'unknown_person', label: 'Unknown Person'),
    _EventTypeFilterOption(value: 'sensor_alert', label: 'Sensor Alert'),
    _EventTypeFilterOption(value: 'fall_detected', label: 'Fall Detected'),
    _EventTypeFilterOption(value: 'camera_offline', label: 'Camera Offline'),
  ];

  final EventHistoryViewModel _viewModel = EventHistoryViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.loadEvents();
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

  void _handleEventTap(AiEvent event) {
    Navigator.of(context).pushNamed(AppRoutes.eventDetail, arguments: event.id);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialStart = _viewModel.startDate ?? now;
    final initialEnd = _viewModel.endDate ?? now;

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );

    if (range == null) return;

    await _viewModel.applyFilters(
      eventType: _viewModel.selectedEventType,
      startDate: DateTime(range.start.year, range.start.month, range.start.day),
      endDate: DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
        999,
      ),
      acknowledgementStatus: _viewModel.selectedAcknowledgementStatus,
    );
  }

  Future<void> _applyEventType(String? eventType) {
    return _viewModel.applyFilters(
      eventType: eventType,
      startDate: _viewModel.startDate,
      endDate: _viewModel.endDate,
      acknowledgementStatus: _viewModel.selectedAcknowledgementStatus,
    );
  }

  Future<void> _applyAcknowledgementStatus(String value) {
    final status = switch (value) {
      'new' => false,
      'acknowledged' => true,
      _ => null,
    };

    return _viewModel.applyFilters(
      eventType: _viewModel.selectedEventType,
      startDate: _viewModel.startDate,
      endDate: _viewModel.endDate,
      acknowledgementStatus: status,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Event History')),
      body: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_viewModel.isLoading && _viewModel.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null && _viewModel.events.isEmpty) {
      return _EventErrorState(
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.loadEvents,
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.refreshEvents,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Event History (${_viewModel.events.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (_viewModel.isRefreshing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _EventFilterPanel(
            eventTypeOptions: _eventTypeOptions,
            selectedEventType: _viewModel.selectedEventType,
            startDate: _viewModel.startDate,
            endDate: _viewModel.endDate,
            selectedAcknowledgementStatus:
                _viewModel.selectedAcknowledgementStatus,
            onEventTypeChanged: _applyEventType,
            onDateRangePressed: _pickDateRange,
            onAcknowledgementChanged: _applyAcknowledgementStatus,
            onClearFilters: _viewModel.clearFilters,
          ),
          if (_viewModel.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              'Error: ${_viewModel.errorMessage}',
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 12),
          if (_viewModel.events.isEmpty)
            const _EmptyEventState()
          else
            AiEventList(events: _viewModel.events, onEventTap: _handleEventTap),
        ],
      ),
    );
  }
}

class _EventFilterPanel extends StatelessWidget {
  final List<_EventTypeFilterOption> eventTypeOptions;
  final String? selectedEventType;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? selectedAcknowledgementStatus;
  final ValueChanged<String?> onEventTypeChanged;
  final VoidCallback onDateRangePressed;
  final ValueChanged<String> onAcknowledgementChanged;
  final VoidCallback onClearFilters;

  const _EventFilterPanel({
    required this.eventTypeOptions,
    required this.selectedEventType,
    required this.startDate,
    required this.endDate,
    required this.selectedAcknowledgementStatus,
    required this.onEventTypeChanged,
    required this.onDateRangePressed,
    required this.onAcknowledgementChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: selectedEventType,
          decoration: const InputDecoration(
            labelText: 'Event type',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All event types'),
            ),
            ...eventTypeOptions.map(
              (option) => DropdownMenuItem<String?>(
                value: option.value,
                child: Text(option.label),
              ),
            ),
          ],
          onChanged: onEventTypeChanged,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onDateRangePressed,
          icon: const Icon(Icons.date_range),
          label: Text(_dateRangeLabel),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _acknowledgementValue,
          decoration: const InputDecoration(
            labelText: 'Status',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All statuses')),
            DropdownMenuItem(value: 'new', child: Text('New')),
            DropdownMenuItem(
              value: 'acknowledged',
              child: Text('Acknowledged'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            onAcknowledgementChanged(value);
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onClearFilters,
            icon: const Icon(Icons.clear),
            label: const Text('Clear filters'),
          ),
        ),
      ],
    );
  }

  String get _acknowledgementValue {
    return switch (selectedAcknowledgementStatus) {
      true => 'acknowledged',
      false => 'new',
      null => 'all',
    };
  }

  String get _dateRangeLabel {
    if (startDate == null || endDate == null) {
      return 'All dates';
    }

    return '${_formatDate(startDate!)} - ${_formatDate(endDate!)}';
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class _EventTypeFilterOption {
  final String value;
  final String label;

  const _EventTypeFilterOption({required this.value, required this.label});
}

class _EventErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EventErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Error: $message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyEventState extends StatelessWidget {
  const _EmptyEventState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.35,
      child: const Center(
        child: Text('No events found', textAlign: TextAlign.center),
      ),
    );
  }
}
