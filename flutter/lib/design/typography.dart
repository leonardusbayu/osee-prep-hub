import 'package:flutter/material.dart';

import 'tokens.dart';

export 'tokens.dart';

/// Magazine typography helpers — Task 6 (Wave 1).
///
/// Use these as drop-in replacements for default TextStyles.
/// All fonts are bundled via google_fonts in main.dart.

/// Display headline — for masthead hero numbers.
TextStyle magazineDisplay({Color? color}) =>
    MagazineTypography.display.copyWith(color: color ?? MagazineColors.inkBlack);

/// Section headline.
TextStyle magazineHeadline({Color? color}) =>
    MagazineTypography.headline.copyWith(color: color ?? MagazineColors.inkBlack);

/// Card / page title.
TextStyle magazineTitle({Color? color}) =>
    MagazineTypography.title.copyWith(color: color ?? MagazineColors.inkBlack);

/// Body paragraph.
TextStyle magazineBody({Color? color}) =>
    MagazineTypography.body.copyWith(color: color ?? MagazineColors.inkGray);

/// Body emphasis (bold inline).
TextStyle magazineBodyEmphasis({Color? color}) =>
    MagazineTypography.bodyEmphasis.copyWith(color: color ?? MagazineColors.inkBlack);

/// Caption / metadata.
TextStyle magazineCaption({Color? color}) =>
    MagazineTypography.caption.copyWith(color: color ?? MagazineColors.inkGray);

/// Overline / kicker.
TextStyle magazineOverline({Color? color}) =>
    MagazineTypography.overline.copyWith(color: color ?? MagazineColors.mastheadGold);