import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Magazine design tokens — Task 6 (Wave 1).
///
/// Shim over [OseeTheme]: the single base theme. These aliases exist so the
/// 6 pages built on the Magazine gold palette keep working while rendering
/// the canonical OseeTheme colors (no duplicate golds/creams/inks).
/// New code should import OseeTheme directly.

class MagazineColors {
  MagazineColors._();

  // Brand — aliased to OseeTheme (P0-1 theme unification).
  static const mastheadGold = OseeTheme.gold;             // #C9A96E (was #B89B5F)
  static const mastheadGoldLight = OseeTheme.warning;     // lighter accent
  static const paperCream = OseeTheme.paper;              // #F7F5F0 (was #FAF6EE)
  static const inkBlack = OseeTheme.ink;                  // #1A1A2E (was #1A1A1A)
  static const inkGray = OseeTheme.textSecondary;         // #6D6D7C (was #4A4A4A)
  static const accentRed = OseeTheme.danger;              // #E63946 (was #A02B2B)
  static const dropCapBlue = Color(0xFF1E3A5F);           // kept — no OseeTheme equivalent

  /// WCAG-AA-safe gold for body text on paper backgrounds (~4.6:1 on #F7F5F0).
  /// Decorative rules/borders keep the brighter [mastheadGold]; use this for text.
  static const mastheadGoldText = Color(0xFF8A6B35);

  // Status (subtle, magazine-muted)
  static const successGreen = OseeTheme.success;          // #6B8E7F (was #4A6741)
  static const warningAmber = OseeTheme.warning;          // #C9A96E
  static const errorRed = OseeTheme.danger;               // #E63946

  // Surfaces
  static const surfaceLight = OseeTheme.paper;            // #F7F5F0
  static const surfaceDark = OseeTheme.primary;           // #1A1A2E
  static const surfaceMuted = OseeTheme.surfaceVariant;   // #F0EEE7 (was #E8E2D5)
}

class MagazineSpacing {
  MagazineSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const base = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
  static const xxxl = 64.0;
}

class MagazineRadius {
  MagazineRadius._();
  static const none = 0.0; // sharp magazine corners
  static const sm = 2.0;
  static const md = 4.0;
}

class MagazineDuration {
  MagazineDuration._();
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
}

class MagazineElevation {
  MagazineElevation._();
  static const none = 0.0;
  static const sm = 1.0;
  static const md = 2.0;
  static const lg = 4.0;
}

class MagazineTypography {
  MagazineTypography._();

  // Display — for masthead / hero numbers
  static const display = TextStyle(
    fontSize: 48,
    height: 56 / 48,
    fontWeight: FontWeight.w800,
    fontFamily: 'Georgia',
    letterSpacing: -0.5,
    color: MagazineColors.inkBlack,
  );

  // Headline — section titles
  static const headline = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    fontFamily: 'Georgia',
    letterSpacing: -0.3,
    color: MagazineColors.inkBlack,
  );

  // Title — card titles, page headers
  static const title = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
    fontFamily: 'Georgia',
    color: MagazineColors.inkBlack,
  );

  // Body — paragraphs
  static const body = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    fontFamily: 'Inter',
    color: MagazineColors.inkGray,
  );

  // Body emphasis — for bold inline
  static const bodyEmphasis = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    fontFamily: 'Inter',
    color: MagazineColors.inkBlack,
  );

  // Caption — small metadata
  static const caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    fontFamily: 'Inter',
    color: MagazineColors.inkGray,
  );

  // Overline — kickers, labels
  static const overline = TextStyle(
    fontSize: 10,
    height: 14 / 10,
    fontWeight: FontWeight.w700,
    fontFamily: 'Inter',
    letterSpacing: 1.2,
    color: MagazineColors.mastheadGold,
  );
}