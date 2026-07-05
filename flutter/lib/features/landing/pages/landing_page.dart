import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Public landing page for prep.osee.co.id — Task 17.4.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero
            Container(
              color: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
              child: Column(
                children: [
                  Text('OSEE Prep Hub',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.bold,
                          )),
                  const SizedBox(height: 8),
                  Text('AI Teaching Assistant for English Teachers in Indonesia',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton(onPressed: () => context.go('/register'), child: const Text('Get Started Free')),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                        onPressed: () => context.go('/login'),
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Features
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                children: [
                  Text('Free AI Tools for Teachers',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: [
                      _Feature(title: 'AI Writing Grader', description: 'Grade student essays with GPT-4o-mini + RAG', icon: Icons.edit_note),
                      _Feature(title: 'Material Generator', description: 'Generate practice passages, vocab, grammar on any topic', icon: Icons.auto_awesome),
                      _Feature(title: 'Speaking Evaluation', description: 'Whisper transcription + fluency scoring via EduBot', icon: Icons.mic),
                      _Feature(title: 'Syllabus Builder', description: 'Drag-and-drop curriculum from all 4 platforms', icon: Icons.list_alt),
                      _Feature(title: 'Earn Commission', description: 'Rp 10-50k per student + 2x ambassador rate', icon: Icons.payments),
                      _Feature(title: 'Official Test Booking', description: 'Book TOEFL/TOEIC at OSEE test center with discount', icon: Icons.verified),
                    ],
                  ),
                ],
              ),
            ),

            // CTA
            Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                children: [
                  const Text('Ready to transform your teaching?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => context.go('/register'), child: const Text('Create Free Account')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.title, required this.description, required this.icon});
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8)],
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(description, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}