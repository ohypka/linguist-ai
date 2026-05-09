import 'package:flutter/material.dart';

class AppTheme {
  // Main app gradient (reuse across UI)
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,

    // Global background
    scaffoldBackgroundColor: const Color(0xFF0F172A),

    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(fontSize: 16),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, // keep gradient visible
      elevation: 0,
      centerTitle: true,
    ),
  );
}