import 'package:flutter/material.dart';

class AppTheme {
  // Dyanmic Color can break and does break frequently: we need a fallback option.
  static ThemeData lightTheme(ColorScheme? lightScheme) {
    ColorScheme scheme;
    if (lightScheme != null && lightScheme.primary != lightScheme.secondary) {
      scheme = lightScheme;
    } else {
      scheme = ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: const Color.fromARGB(255, 195, 58, 83));
    }
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
    );
  }

  static ThemeData darkTheme(ColorScheme? darkScheme) {
    ColorScheme scheme;
    if (darkScheme != null && darkScheme.primary != darkScheme.secondary) {
      scheme = darkScheme;
    } else {
      scheme = ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color.fromARGB(255, 195, 58, 83));
    }
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
    );
  }
}
