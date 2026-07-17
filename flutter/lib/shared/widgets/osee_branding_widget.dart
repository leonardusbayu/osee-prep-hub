import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// OSEE branding widget — Task 2.5.
///
/// Shows "Powered by OSEE Education Hub" branding at bottom of pages.
/// Visible by default. Can be hidden for Pro/Institution tier (Task 15.4).
class OseeBrandingWidget extends StatelessWidget {
  const OseeBrandingWidget({super.key, this.compact = false});

  /// Compact mode shows a smaller version (for tight spaces)
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_rounded, size: 12, color: OseeTheme.primary),
          const SizedBox(width: 4),
          Text(
            'OSEE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: OseeTheme.primary,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OseeTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school_rounded, size: 14, color: OseeTheme.primary),
          const SizedBox(width: 6),
          Text(
            'Powered by OSEE Education Hub',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: OseeTheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
