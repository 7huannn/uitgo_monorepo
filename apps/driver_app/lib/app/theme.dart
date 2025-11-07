import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

ThemeData buildLightTheme() {
  final base = ThemeData.light();
  return base.copyWith(
    useMaterial3: true,
    colorScheme: base.colorScheme.copyWith(
      primary: const Color(0xFF0D47A1),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE3F2FD),
      onPrimaryContainer: const Color(0xFF0D47A1),
      secondary: const Color(0xFF1976D2),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFBBDEFB),
      onSecondaryContainer: const Color(0xFF0D47A1),
      surface: Colors.white,
      onSurface: const Color(0xFF212121),
      surfaceContainerHighest: const Color(0xFFF5F5F5),
      error: const Color(0xFFD32F2F),
      onError: Colors.white,
      outline: const Color(0xFFE0E0E0),
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF0D47A1),
      iconTheme: IconThemeData(color: Color(0xFF0D47A1)),
      titleTextStyle: TextStyle(
        color: Color(0xFF0D47A1),
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF5F6368)),
      hintStyle: const TextStyle(color: Color(0xFFB0BEC5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0D47A1),
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0D47A1),
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Color(0xFF1B1B1F),
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Color(0xFF4A4D52),
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: Color(0xFF81868C),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE0E0E0),
      thickness: 1,
    ),
  );
}
