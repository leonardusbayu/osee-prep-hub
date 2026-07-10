import 'package:flutter/material.dart';

/// Offline banner widget — Task 5 (Wave 1).
///
/// Shows a dismissible gold-rule banner at the top of the app when the
/// device is offline. Magazine-styled: thin gold rule + serif label.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.isOnline, this.onRetry});

  final bool isOnline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isOnline) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(
          bottom: BorderSide(color: Color(0xFFB89B5F), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, color: Color(0xFFB89B5F), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'You are offline. Changes will sync when you reconnect.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Georgia',
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Color(0xFFB89B5F),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}