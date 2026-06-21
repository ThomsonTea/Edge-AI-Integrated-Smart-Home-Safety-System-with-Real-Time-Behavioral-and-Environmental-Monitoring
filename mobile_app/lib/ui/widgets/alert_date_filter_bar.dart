import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

class AlertDateFilterButton extends StatelessWidget {
  final String label;
  final bool showLabel;
  final VoidCallback onPressed;

  const AlertDateFilterButton({
    super.key,
    required this.label,
    this.showLabel = true,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!showLabel) {
      return Tooltip(
        message: label,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(AppSpacing.sm),
            minimumSize: const Size(48, 48),
          ),
          child: const Icon(Icons.calendar_month_outlined),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}
