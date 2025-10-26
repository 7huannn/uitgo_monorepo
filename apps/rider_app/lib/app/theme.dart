import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  final base = ThemeData.light();
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: const Color(0xFF1E88E5),
      secondary: const Color(0xFF26A69A),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ),
  );
}
