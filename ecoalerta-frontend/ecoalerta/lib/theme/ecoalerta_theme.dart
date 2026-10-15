import 'package:flutter/material.dart';

class EcoAlertaColors {
  EcoAlertaColors._();

  static const forest = Color(0xFF1B5E20);
  static const primary = Color(0xFF2E7D32);
  static const leaf = Color(0xFF43A047);
  static const fresh = Color(0xFF4CAF50);
  static const background = Color(0xFFEAF4EA);
  static const surface = Color(0xFFF7FBF7);
  static const warning = Color(0xFFFFC107);
  static const danger = Color(0xFFC62828);
}

class EcoAlertaTheme {
  EcoAlertaTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: EcoAlertaColors.primary,
      brightness: Brightness.light,
      primary: EcoAlertaColors.primary,
      secondary: EcoAlertaColors.leaf,
      surface: EcoAlertaColors.surface,
      error: EcoAlertaColors.danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: EcoAlertaColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: EcoAlertaColors.fresh,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EcoAlertaColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EcoAlertaColors.primary, width: 2),
        ),
      ),
    );
  }
}
