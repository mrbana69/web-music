import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF0A0A0C);
  static const Color surface = Color(0xFF141418);
  static const Color surfaceElevated = Color(0xFF1C1C24);
  static const Color card = Color(0xFF181820);
  
  static const Color primaryAccent = Color(0xFFFA2D48);
  static const Color primaryAccentLight = Color(0xFFFF6B00);
  static const Color secondaryAccent = Color(0xFF7928CA);
  
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textMuted = Color(0xFF636366);

  static final Color border = Colors.white.withOpacity(0.08);
  static final Color borderLight = Colors.white.withOpacity(0.14);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryAccent, primaryAccentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF22222C), Color(0xFF16161D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x28FFFFFF), Color(0x0CFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryAccent,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: primaryAccentLight,
        surface: surface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: primaryAccent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
