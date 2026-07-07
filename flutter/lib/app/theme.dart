import 'package:flutter/material.dart';

/// OSEE Prep Hub — Magazine-style editorial theme.
/// Clean, sophisticated, with strong typography hierarchy.
class OseeTheme {
  OseeTheme._();

  // Editorial color palette (light)
  static const Color ink = Color(0xFF1A1A2E);       // deep navy-black
  static const Color paper = Color(0xFFF7F5F0);      // warm off-white
  static const Color accent = Color(0xFFE63946);     // magazine red
  static const Color gold = Color(0xFFC9A96E);       // muted gold
  static const Color sage = Color(0xFF6B8E7F);       // sage green
  static const Color cloud = Color(0xFFE8E6E1);      // light grey
  static const Color stone = Color(0xFF9B9B9B);      // medium grey

  // Scrapbook palette — aged parchment, tape, ink, coffee stains
  static const Color parchment = Color(0xFFEDE5D3);  // antique parchment
  static const Color parchmentDark = Color(0xFFD9CEB5); // darker parchment
  static const Color tape = Color(0x55FFE08A);       // washi tape (translucent yellow)
  static const Color tapePink = Color(0x55FFB3BA);   // washi tape pink
  static const Color coffeeRing = Color(0x228B6F47); // coffee stain ring
  static const Color inkBleed = Color(0x331A1A2E);   // ink bleed shadow
  static const Color polaroidWhite = Color(0xFFFAF8F3); // polaroid card white
  static const Color clippingYellow = Color(0xFFF5EFD0); // aged clipping yellow
  static const Color redStamp = Color(0xFFD44545);   // red stamp / sticker

  // Dark editorial palette (evening edition)
  static const Color inkDark = Color(0xFF0E0E1A);     // near-black
  static const Color paperDark = Color(0xFF1F1F2E);   // dark navy paper
  static const Color cloudDark = Color(0xFF2E2E40);  // elevated surface
  static const Color stoneDark = Color(0xFF8A8AA0);   // muted text on dark

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      primary: accent,
      secondary: gold,
      surface: paper,
      onSurface: ink,
      error: accent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      fontFamily: 'Georgia',

      // Magazine-style typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 56,
          fontWeight: FontWeight.w700,
          color: ink,
          height: 1.1,
          letterSpacing: -1.5,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: ink,
          height: 1.15,
          letterSpacing: -0.8,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 1.2,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Helvetica',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ink,
          letterSpacing: 0.5,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Helvetica',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: stone,
          letterSpacing: 1.5,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: ink,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: ink,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Helvetica',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: stone,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Helvetica',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Helvetica',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: stone,
          letterSpacing: 2,
        ),
      ),

      // Minimalist app bar
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        iconTheme: IconThemeData(color: ink),
      ),

      // Editorial-style cards
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        margin: EdgeInsets.zero,
      ),

      // Bold buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),

      // Filled buttons — accent red
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),

      // Text buttons — underlined like links
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),

      // Clean input fields
      inputDecorationTheme: InputDecorationTheme(
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: cloud, width: 1),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: cloud, width: 1),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: ink, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: accent, width: 1),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Helvetica',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: stone,
          letterSpacing: 1,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 16,
          color: OseeTheme.stone.withValues(alpha: 0.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        filled: false,
      ),

      // Bottom nav
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: paper,
        selectedItemColor: accent,
        unselectedItemColor: stone,
        type: BottomNavigationBarType.fixed,
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: cloud,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Evening edition — dark mode for low-light reading.
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      primary: accent,
      secondary: gold,
      surface: paperDark,
      onSurface: paper,
      error: accent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: inkDark,
      fontFamily: 'Georgia',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Georgia', fontSize: 56, fontWeight: FontWeight.w700, color: paper, height: 1.1, letterSpacing: -1.5),
        displayMedium: TextStyle(fontFamily: 'Georgia', fontSize: 40, fontWeight: FontWeight.w700, color: paper, height: 1.15, letterSpacing: -0.8),
        displaySmall: TextStyle(fontFamily: 'Georgia', fontSize: 28, fontWeight: FontWeight.w600, color: paper, height: 1.2),
        headlineLarge: TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.w600, color: paper, height: 1.3),
        headlineMedium: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w600, color: paper),
        headlineSmall: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w500, color: paper),
        titleLarge: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.w600, color: paper),
        titleMedium: TextStyle(fontFamily: 'Helvetica', fontSize: 14, fontWeight: FontWeight.w600, color: paper, letterSpacing: 0.5),
        titleSmall: TextStyle(fontFamily: 'Helvetica', fontSize: 12, fontWeight: FontWeight.w700, color: stoneDark, letterSpacing: 1.5),
        bodyLarge: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.w400, color: paper, height: 1.6),
        bodyMedium: TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w400, color: paper, height: 1.5),
        bodySmall: TextStyle(fontFamily: 'Helvetica', fontSize: 12, fontWeight: FontWeight.w400, color: stoneDark, height: 1.4),
        labelLarge: TextStyle(fontFamily: 'Helvetica', fontSize: 14, fontWeight: FontWeight.w700, color: paper, letterSpacing: 1),
        labelSmall: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, color: stoneDark, letterSpacing: 2),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: inkDark,
        foregroundColor: paper,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.w700, color: paper),
        iconTheme: IconThemeData(color: paper),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cloudDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: paper,
          foregroundColor: inkDark,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: const TextStyle(fontFamily: 'Helvetica', fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          textStyle: const TextStyle(fontFamily: 'Helvetica', fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: UnderlineInputBorder(borderSide: BorderSide(color: cloudDark, width: 1)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: cloudDark, width: 1)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: paper, width: 2)),
        errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent, width: 1)),
        labelStyle: const TextStyle(fontFamily: 'Helvetica', fontSize: 12, fontWeight: FontWeight.w600, color: stoneDark, letterSpacing: 1),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        filled: false,
      ),
      dividerTheme: const DividerThemeData(color: cloudDark, thickness: 1, space: 1),
    );
  }
}