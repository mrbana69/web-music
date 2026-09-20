import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Material 3 Dark Tonal Surfaces (ViMusic & Preluded Slate) ---
  static const Color background = Color(0xFF09090D);
  static const Color surface = Color(0xFF111116);
  static const Color surfaceContainerLowest = Color(0xFF060609);
  static const Color surfaceContainerLow = Color(0xFF0E0E13);
  static const Color surfaceContainer = Color(0xFF15151B);
  static const Color surfaceContainerHigh = Color(0xFF1C1C24);
  static const Color surfaceContainerHighest = Color(0xFF24242E);
  static const Color surfaceElevated = Color(0xFF1A1A22);
  static const Color card = Color(0xFF14141A);

  // --- Brand Accents ---
  static const Color primaryAccent = Color(0xFFFA2D48); // Vibrant Coral Red
  static const Color primaryAccentLight = Color(0xFFFF5E62);
  static const Color primaryContainer = Color(0xFF420E15);
  static const Color onPrimaryContainer = Color(0xFFFFD9DC);

  static const Color secondaryAccent = Color(0xFFFF8A00); // Warm Amber
  static const Color tertiaryAccent = Color(0xFF9D4EDD); // Electric Violet

  // --- Typography Colors ---
  static const Color textPrimary = Color(0xFFF6F6F8);
  static const Color textSecondary = Color(0xFFA0A0AC);
  static const Color textMuted = Color(0xFF6B6B78);

  // --- Borders & Outlines ---
  static final Color border = Colors.white.withOpacity(0.08);
  static final Color borderLight = Colors.white.withOpacity(0.14);
  static final Color outlineVariant = Colors.white.withOpacity(0.12);

  // --- Gradients ---
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFA2D48), Color(0xFFFF5E62)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ambientHeroGradient = LinearGradient(
    colors: [Color(0xFFFA2D48), Color(0xFF7928CA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1C1C24), Color(0xFF121218)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0x1FFFFFFF), Color(0x08FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static bool isTesting = false;

  // --- Font Helper Methods (Syne for Headings/Display, Inter for Body/Sub) ---
  static TextStyle syne({
    double fontSize = 14.5,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
    double? letterSpacing = -0.3,
    double? height,
    List<Shadow>? shadows,
  }) {
    if (isTesting) {
      return TextStyle(
        fontFamily: 'Roboto',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );
    }
    return GoogleFonts.syne(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    );
  }

  static TextStyle inter({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = textSecondary,
    double? letterSpacing,
    double? height,
    List<Shadow>? shadows,
  }) {
    if (isTesting) {
      return TextStyle(
        fontFamily: 'Roboto',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
        shadows: shadows,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      shadows: shadows,
    );
  }

  // --- Material 3 Theme Data ---
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryAccent,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.syne(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -1.0),
        displayMedium: GoogleFonts.syne(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.8),
        displaySmall: GoogleFonts.syne(fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        headlineLarge: GoogleFonts.syne(fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.6),
        headlineMedium: GoogleFonts.syne(fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.4),
        headlineSmall: GoogleFonts.syne(fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.3),
        titleLarge: GoogleFonts.syne(fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.2),
        titleMedium: GoogleFonts.syne(fontWeight: FontWeight.w600, color: textPrimary),
        titleSmall: GoogleFonts.syne(fontWeight: FontWeight.w600, color: textSecondary),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400, color: textSecondary),
        bodySmall: GoogleFonts.inter(fontWeight: FontWeight.w400, color: textMuted),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textPrimary),
        labelMedium: GoogleFonts.inter(fontWeight: FontWeight.w500, color: textSecondary),
        labelSmall: GoogleFonts.inter(fontWeight: FontWeight.w500, color: textMuted),
      ),
      colorScheme: ColorScheme.dark(
        primary: primaryAccent,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondaryAccent,
        tertiary: tertiaryAccent,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerLowest: surfaceContainerLowest,
        surfaceContainerLow: surfaceContainerLow,
        surfaceContainer: surfaceContainer,
        surfaceContainerHigh: surfaceContainerHigh,
        surfaceContainerHighest: surfaceContainerHighest,
        outline: border,
        outlineVariant: outlineVariant,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.syne(
          color: textPrimary,
          fontSize: 18.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: primaryContainer,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            color: isSelected ? textPrimary : textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? primaryAccentLight : textSecondary,
            size: 24,
          );
        }),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 2),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: primaryAccent,
        inactiveTrackColor: Colors.white.withOpacity(0.15),
        thumbColor: primaryAccent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerLow,
        selectedColor: primaryContainer,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: textPrimary, fontWeight: FontWeight.w500),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: border),
      ),
    );
  }
}
