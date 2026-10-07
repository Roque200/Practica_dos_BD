import 'package:flutter/material.dart';

class ThemeApp {
  static const Color semilla = Color(0xFF2E7D32);

  static ThemeData claro() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: semilla),
      useMaterial3: true,
    );
  }

  static ThemeData oscuro() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: semilla,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }
}
