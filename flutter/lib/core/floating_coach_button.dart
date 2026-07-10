import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Floating "Ask Coach" button — T10 (Wave 2).
///
/// Overlay on all student pages. Tapping navigates to /student/coach.
class FloatingCoachButton extends ConsumerWidget {
  const FloatingCoachButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFFB89B5F),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => context.push('/student/coach'),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.psychology_outlined, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Ask Coach',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}