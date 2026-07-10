import 'package:flutter/material.dart';

/// Magazine design tokens — Task 6 (Wave 1).
///
/// Formal color + spacing + typography scale for the magazine editorial theme.
/// All app pages should reference these tokens, not hardcoded values.

class MagazineColors {
  MagazineColors._();

  // Brand
  static const mastheadGold = Color(0xFFB89B5F);
  static const mastheadGoldLight = Color(0xFFD4B98A);
  static const paperCream = Color(0xFFFAF6EE);
  static const inkBlack = Color(0xFF1A1A1A);
  static const inkGray = Color(0xFF4A4A4A);
  static const accentRed = Color(0xFFA02B2B);
  static const dropCapBlue = Color(0xFF1E3A5F);

  // Status (subtle, magazine-muted)
  static const successGreen = Color(0xFF4A6741);
  static const warningAmber = Color(0xFFB89B5F);
  static const errorRed = Color(0xFFA02B2B);

  // Surfaces
  static const surfaceLight = Color(0xFFFAF6EE);
  static const surfaceDark = Color(0xFF1A1A1A);
  static const surfaceMuted = Color(0xFFE8E2D5);
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