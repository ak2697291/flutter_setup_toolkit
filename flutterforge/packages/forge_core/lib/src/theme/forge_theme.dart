import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ForgeTheme — Material 3 theming helpers.
///
/// Usage:
/// ```dart
/// theme: ForgeTheme.buildLight(primaryColor: Color(0xFF6200EA)),
/// darkTheme: ForgeTheme.buildDark(primaryColor: Color(0xFF6200EA)),
/// ```
class ForgeTheme {
  ForgeTheme._();

  static ThemeData buildLight({
    Color primaryColor = const Color(0xFF6200EA),
    String fontFamily = 'Roboto',
    double borderRadius = 12.0,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      surface: const Color(0xFFF8F9FA),
    );
    return _build(
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      borderRadius: borderRadius,
    ).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      cardColor: Colors.white,
    );
  }

  static ThemeData buildDark({
    Color primaryColor = const Color(0xFF6200EA),
    String fontFamily = 'Roboto',
    double borderRadius = 12.0,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF0A0E21),
      surfaceContainerHighest: const Color(0xFF12172D),
    );
    return _build(
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      borderRadius: borderRadius,
    ).copyWith(
      scaffoldBackgroundColor: const Color(0xFF0A0E21),
      cardColor: const Color(0xFF12172D),
    );
  }

  static ThemeData _build({
    required ColorScheme colorScheme,
    required String fontFamily,
    required double borderRadius,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: colorScheme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      ),
    );
  }
}

extension ForgeThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textStyles => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}