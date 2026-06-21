import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../viewmodels/notification_viewmodel.dart';

class AlertFilterBar extends StatelessWidget {
  final List<AlertFilter> filters;
  final AlertFilter selectedFilter;
  final ValueChanged<AlertFilter> onSelected;

  const AlertFilterBar({
    super.key,
    required this.filters,
    required this.selectedFilter,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            FilterChip(
              label: Text(filter.label),
              selected: selectedFilter == filter,
              onSelected: (_) => onSelected(filter),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
