import 'package:flutter/material.dart';

/// Responsive utilities — Task 18.3.
///
/// Helper breakpoints matching Material Design 3 window-size classes:
///   compact:   < 600 dp   (phone portrait)
///   medium:    600-840 dp (phone landscape, small tablet)
///   expanded:  840-1200 dp (tablet, desktop small)
///   large:     >= 1200 dp  (desktop)
class Responsive {
  const Responsive._();

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;
  static bool isMedium(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 && w < 840;
  }

  static bool isExpanded(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 840 && w < 1200;
  }

  static bool isLarge(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1200;

  /// Number of grid columns for a stat grid given current screen width.
  static int statGridColumns(BuildContext context) {
    if (isLarge(context)) return 4;
    if (isExpanded(context)) return 3;
    if (isMedium(context)) return 2;
    return 2; // compact
  }

  /// Whether to show sidebar (drawer on mobile, fixed on desktop).
  static bool showSidebar(BuildContext context) => isExpanded(context);

  /// Max content width (centered on large screens for readability).
  static double contentMaxWidth(BuildContext context) {
    if (isLarge(context)) return 1000;
    if (isExpanded(context)) return 840;
    return double.infinity;
  }
}

/// Wraps children in a centered max-width container on large screens.
class CenteredContent extends StatelessWidget {
  const CenteredContent({super.key, required this.child, this.maxWidth});
  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final w = maxWidth ?? Responsive.contentMaxWidth(context);
    if (w == double.infinity) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: w),
        child: child,
      ),
    );
  }
}
