import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OSEE Prep Hub — Editorial SaaS Theme.
///
/// Design language:
/// - Brand: High-end education magazine / Enterprise SaaS
/// - Colors: Deep Navy, Cream, Crimson Red, Gold
/// - Shapes: Sharp, precise (2px radius)
/// - Texture: Flat, high-contrast, no heavy shadows
/// - Typography: Inter (sans) + tight tracking for headings, wide for labels
class OseeTheme {
  OseeTheme._();

  // Editorial brand palette
  static const Color primary = Color(0xFF1A1A2E); // Deep Navy
  static const Color primaryLight = Color(0xFF2E2E4A); 
  static const Color success = Color(0xFF6B8E7F); // Muted Sage (from landing)
  static const Color warning = Color(0xFFC9A96E); // Gold
  static const Color danger = Color(0xFFE63946); // Crimson Red
  static const Color accent = Color(0xFFE63946); 

  // Editorial Neutrals
  static const Color bg = Color(0xFFF7F5F0); // Cream / Off-white (outer bg)
  static const Color surface = Color(0xFFFFFFFF); // Pure white for cards
  static const Color surfaceVariant = Color(0xFFF0EEE7); // Slightly darker cream
  static const Color border = Color(0xFFE8E6E1); // Crisp 1px border color
  
  static const Color textPrimary = Color(0xFF1A1A2E); // Deep Navy text
  static const Color textSecondary = Color(0xFF6D6D7C); // Muted Navy
  static const Color textMuted = Color(0xFF9B9B9B); // Standard Grey

  // Legacy aliases
  static const Color paper = bg;
  static const Color ink = textPrimary;
  static const Color gold = warning;
  static const Color stone = textMuted;
  static const Color sage = success;
  static const Color cloud = border;

  // Ultra-subtle, practically invisible shadow (just for separation, not for "floating")
  static List<BoxShadow> get softShadows => [
        BoxShadow(
          color: textPrimary.withValues(alpha: 0.015),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

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

      // Typography — Inter via Google Fonts, styled strictly
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          height: 1.05,
          letterSpacing: -1.5, // Extremely tight, impactful
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          height: 1.1,
          letterSpacing: -1.0,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          height: 1.15,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.25,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.25,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          letterSpacing: 0,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.6, 
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.6,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textPrimary, // Typically used on buttons, override locally
          letterSpacing: 1.5, // Wide tracking for buttons
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textMuted,
          letterSpacing: 1.5, // Wide tracking for editorial tags
        ),
      ),

      // Clean app bar — Solid, flat
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0, 
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: textPrimary, size: 22),
        shape: const Border(bottom: BorderSide(color: border, width: 1)),
      ),

      // Editorial cards — radius 2, stark border
      cardTheme: CardThemeData(
        elevation: 0, 
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Buttons — sharp radius 2, high contrast
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0, // Flat
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0, // Uppercase style usually goes well with tracking
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),

      // Input fields — Flat, stark borders
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface, // Pure white
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16, 
        ),
      ),

      // Bottom nav
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 32, // Ample whitespace
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: primary.withValues(alpha: 0.1),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), 
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0, // Flat
        focusElevation: 0,
        hoverElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primary,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        elevation: 0,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: border, width: 1),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
