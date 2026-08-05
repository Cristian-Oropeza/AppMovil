import 'package:flutter/material.dart';

class AppTheme {
  // Un azul/verde (teal/cyan) que transmite finanzas y confianza
  static const Color _seedColor = Color(0xFF00897B); // Teal 600

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
    );
  }
}
