import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Teacher module theme — mirrors the Figma "Teacher Availability Calendar"
/// dashboard design (frame 383:107).
///
/// Localized to the teacher module only; the global `OseeTheme` is untouched so
/// other modules (admin/partner/legacy teacher dashboard) keep their look.
class TeacherTheme {
  TeacherTheme._();

  // ---- Brand (Figma) ----
  static const Color primaryBlue = Color(0xFF0177FB);
  static const Color primaryBlueSoft = Color(0x1A0177FB); // 10% alpha

  static const Color textPrimary = Color(0xFF161736);
  static const Color textActive = Color(0xFF141736);
  static const Color textSecondary = Color(0xFF7D8DA6);
  static const Color textMuted = Color(0xFFA5B4CB);

  static const Color successGreen = Color(0xFF6ED097);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F9FB); // light cool gray
  static const Color backgroundSecondary = Color(0xFFF0F2F6);
  static const Color divider = Color(0xFFDFE5F1);
  static const Color dividerSubtle = Color(0xFFEDF0F5);
  static const Color chipInactiveIcon = Color(0xFFAEAEAE);
  static const Color shadowColor = Color(0x1AB0B3BD); // 10% #B0B3BD

  // Active / Interactive states
  static const Color activeNavBg = Color(0x0D0177FB); // 5% primaryBlue
  static const Color hoverBg = Color(0x080177FB); // 3% primaryBlue
  static const Color badgeDanger = Color(0xFFE74C5E);

  // ---- Shape ----
  static const double radiusButton = 16;
  static const double radiusArrow = 6;
  static const double radiusCard = 16;
  static const double radiusPanel = 12;
  static const double radiusAvatar = 190; // full circle
  static const double radiusInput = 10;
  static const double radiusBadge = 8;
  static const double radiusNav = 10;

  // ---- Animation ----
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);

  // ---- Elevation ----
  static List<BoxShadow> get sidebarShadow => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 34,
          offset: const Offset(-16, 0),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  // ---- Typography (Inter as Gilroy fallback — Gilroy not on Google Fonts) ----
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      primary: primaryBlue,
      surface: surface,
      onSurface: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.17,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.3,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.17,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          height: 1.17,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          height: 1.17,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textMuted,
          height: 1.17,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          height: 1.17,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ---- Named text styles (Figma tokens) ----
  static TextStyle pageTitle([Color? c]) => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: c ?? textPrimary,
        height: 1.17,
      );

  static TextStyle eventTitle([Color? c]) => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: c ?? textPrimary,
        height: 1.17,
      );

  static TextStyle panelTitle([Color? c]) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: c ?? textPrimary,
        height: 1.3,
      );

  static TextStyle logo([Color? c]) => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: c ?? Colors.black,
        height: 1.17,
      );

  static TextStyle userName([Color? c]) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: c ?? Colors.black,
        height: 1.17,
      );

  static TextStyle userRole([Color? c]) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: c ?? textMuted,
        height: 1.17,
      );

  static TextStyle chipActive([Color? c]) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: c ?? textActive,
        height: 1.17,
      );

  static TextStyle chipInactive([Color? c]) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: c ?? textSecondary,
        height: 1.17,
      );

  static TextStyle caption([Color? c]) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: c ?? textSecondary,
        height: 1.17,
      );

  static TextStyle searchPlaceholder([Color? c]) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: c ?? textMuted,
        height: 1.17,
      );

  static TextStyle instructorName([Color? c]) => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: c ?? textMuted,
        height: 1.17,
      );

  static TextStyle navLabel(Color c, {bool active = false}) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        color: c,
        height: 1.2,
      );
}

/// Spacing scale for the teacher module (Figma-derived).
class TeacherSpacing {
  const TeacherSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 30;
  static const double xxl = 40;

  static const double sidebarWidth = 260;
  static const double topbarHeight = 76;
  static const double navItemHeight = 40;
}