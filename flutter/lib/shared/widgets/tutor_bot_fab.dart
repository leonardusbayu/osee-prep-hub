import 'package:flutter/material.dart';

/// Tutor Bot floating action button — Task 2.6.
///
/// Student-only floating CTA that links to https://t.me/osee_edubot (EduBot Telegram).
/// Shows a chat icon + "Ask Tutor Bot" label.
/// Smooth animation on appear.
class TutorBotFab extends StatefulWidget {
  const TutorBotFab({super.key});

  @override
  State<TutorBotFab> createState() => _TutorBotFabState();
}

class _TutorBotFabState extends State<TutorBotFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    // Start animation after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openTutorBot() {
    // In a real web app, this would open https://t.me/osee_edubot
    // Flutter Web: use url_launcher package (added in future task)
    // For now, show a snackbar with the URL
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening Tutor Bot at https://t.me/osee_edubot...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FloatingActionButton.extended(
          onPressed: _openTutorBot,
          icon: const Icon(Icons.smart_toy),
          label: const Text('Ask Tutor Bot'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 4,
        ),
      ),
    );
  }
}