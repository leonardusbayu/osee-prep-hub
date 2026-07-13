import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OSEE Prep Hub — Modern professional theme.
///
/// Design language:
/// - Font: Inter (clean, geometric sans-serif — modern SaaS standard)
/// - Colors: deep indigo primary, emerald success, amber accent, slate text
/// - Cards: radius 16, soft shadow, white on light slate background
/// - Buttons: radius 12, medium weight, letter-spacing 0.5
/// - Spacing: 8px base grid
class OseeTheme {
  OseeTheme._();

  // Modern brand palette
  static const Color primary = Color(0xFF4F46E5);      // indigo-600
  static const Color primaryLight = Color(0xFF818CF8);  // indigo-400
  static const Color primaryDark = Color(0xFF3730A3);   // indigo-800
  static const Color success = Color(0xFF10B981);        // emerald-500
  static const Color warning = Color(0xFFF59E0B);        // amber-500
  static const Color danger = Color(0xFFEF4444);         // red-500
  static const Color accent = Color(0xFFEC4899);         // pink-500

  // Neutrals (slate)
  static const Color bg = Color(0xFFF8FAFC);             // slate-50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);  // slate-100
  static const Color border = Color(0xFFE2E8F0);          // slate-200
  static const Color textPrimary = Color(0xFF0F172A);     // slate-900
  static const Color textSecondary = Color(0xFF64748B);   // slate-500
  static const Color textMuted = Color(0xFF94A3B8);       // slate-400

  // Legacy aliases (backward compatibility with old palette)
  static const Color paper = bg;
  static const Color ink = textPrimary;
  static const Color gold = warning;
  static const Color stone = textMuted;
  static const Color sage = success;
  static const Color cloud = border;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: accent,
      surface: surface,
      onSurface: textPrimary,
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,

      // Typography — Inter via Google Fonts
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 48, fontWeight: FontWeight.w800, color: textPrimary,
          height: 1.1, letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 36, fontWeight: FontWeight.w700, color: textPrimary,
          height: 1.15, letterSpacing: -0.5,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary,
          height: 1.2,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary,
          height: 1.3,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary,
          letterSpacing: 0.2,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600, color: textSecondary,
          letterSpacing: 0.5,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white,
          letterSpacing: 0.5,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600, color: textMuted,
          letterSpacing: 0.8,
        ),
      ),

      // Clean app bar — surface color, subtle border, no elevation
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary, size: 22),
        shape: const Border(
          bottom: BorderSide(color: border, width: 1),
        ),
      ),

      // Modern cards — radius 16, soft shadow
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),

      // Buttons — radius 12, medium weight
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input fields — filled style, radius 12
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500, color: textSecondary,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Bottom nav
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: primary.withValues(alpha: 0.12),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary,
        ),
      ),
    );
  }
}