import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Student portal theme — modernized design matching teacher dashboard.
class StudentTheme {
  StudentTheme._();

  // ---- Brand (Figma) ----
  static const Color primary = Color(0xFF925FE2);
  static const Color primaryDeep = Color(0xFF7042C0);
  static const Color primaryLight = Color(0xFFE2D4F7);
  static const Color primaryLighter = Color(0xFFDFCFF7);
  static const Color primarySurface = Color(0xFFF3EDFD); 

  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F9FB); 
  static const Color courseCardBg = Color(0x4D925FE2); 

  static const Color textPrimary = Color(0xFF161736); 
  static const Color textActive = Color(0xFF141736);
  static const Color textSecondary = Color(0xFF7D8DA6); 
  static const Color textMuted = Color(0xFFA5B4CB); 
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnPrimaryMuted = Color(0x80FFFFFF); 
  static const Color textOnPrimarySoft = Color(0xBFFFFFFF); 
  
  // Accents
  static const Color accent = Color(0xFF0EA5E9); 
  static const Color accentSurface = Color(0xFFE0F2FE);
  
  static const Color successGreen = Color(0xFF6ED097);
  static const Color successSurface = Color(0xFFD1FAE5);
  
  static const Color warningOrange = Color(0xFFF0A030);
  static const Color warningSurface = Color(0xFFFEF3C7);
  
  static const Color danger = Color(0xFFE74C5E);
  static const Color dangerSurface = Color(0xFFFEE2E2);

  static const Color divider = Color(0xFFDFE5F1);
  static const Color dividerSubtle = Color(0xFFEDF0F5);
  
  static const Color activeNavBg = Color(0x1A925FE2); // 10% primary
  static const Color hoverBg = Color(0x0D925FE2); // 5% primary
  
  static const Color shadowColor = Color(0x1AB0B3BD); 

  static const Color avatarPlaceholder = Color(0xFFD9D9D9);

  // ---- Shape ----
  static const double radiusCard = 16; 
  static const double radiusButton = 16; 
  static const double radiusLogo = 12; 
  static const double radiusSearch = 10; 
  static const double radiusBadge = 8;
  static const double radiusNav = 10;
  static const double radiusAvatar = 190;

  // ---- Animation ----
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);

  // ---- Elevation ----
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get rootShadow => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 34,
          offset: const Offset(-16, 0),
        ),
      ];

  static List<BoxShadow> get avatarShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
      
  static List<BoxShadow> glowShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.25),
          blurRadius: 16,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
      ];

  // ---- Gradients ----
  static const LinearGradient sidebarGradient = LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)], // dark navy gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

  static const LinearGradient heroGradient = LinearGradient(
            colors: [primaryDeep, primary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          );

  static const LinearGradient logoGradient = LinearGradient(
            colors: [primary, primaryDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

  // ---- Typography (Inter) ----
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: accent,
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
        labelLarge: GoogleFonts.inter(
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

  // ---- Text styles ----
  static TextStyle pageTitle([Color? c]) => GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w600, color: c ?? textPrimary, height: 1.17,
      );
  static TextStyle sectionTitle([Color? c]) => GoogleFonts.inter(
        fontSize: 18, fontWeight: FontWeight.w600, color: c ?? textPrimary, height: 1.3,
      );
  static TextStyle cardValue([Color? c]) => GoogleFonts.inter(
        fontSize: 22, fontWeight: FontWeight.w600, color: c ?? textPrimary, height: 1.17,
      );
  static TextStyle cardLabel([Color? c]) => GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w500, color: c ?? textSecondary, height: 1.17,
      );
  static TextStyle courseTitle([Color? c]) => GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w600, color: c ?? textPrimary, height: 1.3,
      );
  static TextStyle navActive() => GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, color: textOnPrimary, height: 1.2,
      );
  static TextStyle navInactive() => GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w500, color: textOnPrimaryMuted, height: 1.2,
      );
  static TextStyle noticeTitle([Color? c]) => GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, color: c ?? textPrimary, height: 1.17,
      );
  static TextStyle noticeBody([Color? c]) => GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w500, color: c ?? textSecondary, height: 1.5,
      );
  static TextStyle link([Color? c]) => GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600, color: c ?? accent, height: 1.17,
      );
  static TextStyle dateStyle([Color? c]) => GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w500, color: c ?? textOnPrimaryMuted, height: 1.17,
      );
  static TextStyle profileName([Color? c]) => GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, color: c ?? textPrimary, height: 1.17,
      );
  static TextStyle profileYear([Color? c]) => GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w500, color: c ?? textSecondary, height: 1.17,
      );
  static TextStyle chipActive([Color? c]) => GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600, color: c ?? textActive, height: 1.17,
      );
  static TextStyle chipInactive([Color? c]) => GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600, color: c ?? textSecondary, height: 1.17,
      );
  static TextStyle searchPlaceholder([Color? c]) => GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w500, color: c ?? textMuted, height: 1.17,
      );
}

/// Spacing scale for student module.
class StudentSpacing {
  const StudentSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 30;
  static const double xxl = 40;
  static const double gap = 24;
  static const double navGap = 16;
}