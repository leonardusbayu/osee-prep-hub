import 'package:flutter/material.dart';

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
          const Icon(Icons.school, size: 12, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            'OSEE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
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
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.school, size: 14, color: Colors.blue),
          const SizedBox(width: 6),
          Text(
            'Powered by OSEE Education Hub',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}