import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../viewmodels/dashboard_viewmodel.dart';

class DashboardFilterBar extends StatelessWidget {
  final String selectedTimeFilter;
  final String selectedEventType;
  final ValueChanged<String> onTimeFilterChanged;
  final ValueChanged<String> onEventTypeChanged;

  const DashboardFilterBar({
    super.key,
    required this.selectedTimeFilter,
    required this.selectedEventType,
    required this.onTimeFilterChanged,
    required this.onEventTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: selectedTimeFilter,
              decoration: const InputDecoration(
                labelText: 'Time',
                prefixIcon: Icon(Icons.schedule),
              ),
              items: DashboardViewModel.timeFilterOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.value,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onTimeFilterChanged(value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: selectedEventType,
              decoration: const InputDecoration(
                labelText: 'Event Type',
                prefixIcon: Icon(Icons.tune),
              ),
              items: DashboardViewModel.eventTypeFilterOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.value,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onEventTypeChanged(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
