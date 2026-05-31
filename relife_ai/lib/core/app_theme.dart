import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF7C3AED); // Deep Purple
  static const Color primaryDark = Color(0xFF4C1D95); // Violet Dark
  static const Color backgroundColor = Color(0xFFF5F3FF); // Soft Lavender White
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFEF4444); // Danger Red
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color successColor = Color(0xFF22C55E); // Safe Green
  static const Color textMainColor = Color(0xFF1A0050); // Dark Purple Text
  static const Color textSecondaryColor = Color(0xFF6B7280); // Grey
  static const Color hintColor = Color(0xFF9CA3AF); // Light Grey

  // Shared Global Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, primaryDark],
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: primaryColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w900, color: textMainColor),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w900, color: textMainColor),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400, color: textMainColor),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400, color: textMainColor),
        labelSmall: GoogleFonts.inter(fontWeight: FontWeight.w700, color: textSecondaryColor, letterSpacing: 0.8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,

        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor, // Fallback if no gradient
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ).copyWith(
          // For primary call to actions we will manually inject Gradient containers inside widgets
          // but if they just use standard ElevatedButton this will map decently.
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(color: hintColor, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0, // Using manual soft shadow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

