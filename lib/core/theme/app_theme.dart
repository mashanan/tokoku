import 'package:flutter/material.dart';

/// App-wide theme. The seed color and typography are placeholders until the
/// Figma design system is ready.
abstract final class AppTheme {
  static const Color _seedColor = Color(0xFF2563EB);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness);
    OutlineInputBorder fieldBorder([BorderSide side = BorderSide.none]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: side);

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      // Labels sit above fields (see LabeledField), so fields are plain filled
      // boxes that show a border only while focused or invalid.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: fieldBorder(),
        enabledBorder: fieldBorder(),
        disabledBorder: fieldBorder(),
        focusedBorder: fieldBorder(BorderSide(color: colorScheme.primary, width: 1.5)),
        errorBorder: fieldBorder(BorderSide(color: colorScheme.error)),
        focusedErrorBorder: fieldBorder(BorderSide(color: colorScheme.error, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
