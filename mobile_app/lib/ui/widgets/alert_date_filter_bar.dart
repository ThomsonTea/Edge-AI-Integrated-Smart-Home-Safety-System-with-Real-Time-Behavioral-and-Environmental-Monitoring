import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../viewmodels/notification_viewmodel.dart';

class AlertDateFilterBar extends StatelessWidget {
  final List<EventDateFilter> filters;
  final EventDateFilter selectedFilter;
  final String selectedLabel;
  final ValueChanged<EventDateFilter> onSelected;
  final VoidCallback onCustomSelected;

  const AlertDateFilterBar({
    super.key,
    required this.filters,
    required this.selectedFilter,
    required this.selectedLabel,
    required this.onSelected,
    required this.onCustomSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            FilterChip(
              label: Text(
                filter == EventDateFilter.custom ? selectedLabel : filter.label,
              ),
              selected: selectedFilter == filter,
              onSelected: (_) {
                if (filter == EventDateFilter.custom) {
                  onCustomSelected();
                } else {
                  onSelected(filter);
                }
              },
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
