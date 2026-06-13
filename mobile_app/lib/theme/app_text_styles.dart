import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  static const TextStyle title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static TextTheme textTheme(Color primaryText, Color secondaryText) {
    return TextTheme(
      headlineSmall: title.copyWith(color: primaryText),
      titleLarge: sectionTitle.copyWith(color: primaryText),
      titleMedium: sectionTitle.copyWith(color: primaryText),
      titleSmall: body.copyWith(
        color: primaryText,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: body.copyWith(color: primaryText),
      bodyMedium: body.copyWith(color: primaryText),
      bodySmall: caption.copyWith(color: secondaryText),
      labelLarge: body.copyWith(
        color: primaryText,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: caption.copyWith(
        color: primaryText,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: caption.copyWith(color: secondaryText),
    );
  }
}
