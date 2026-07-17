import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ambassador public recruitment page — Task 17.1.
///
/// Pitch for prospective teachers who want to become OSEE Ambassadors.
/// Shows the benefits + obligations + apply CTA.
class AmbassadorRecruitmentPage extends StatelessWidget {
  const AmbassadorRecruitmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become an OSEE Ambassador'),
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Hero
          Card(
            color: const Color(0xFF16A34A),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'OSEE Certified Educator',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Join 20 founding teachers. Get unlimited AI + 2x commission + free Pro for life.',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Benefits
          const Text(
            'Ambassador Benefits',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._benefits.map(
            (b) => Card(
              child: ListTile(
                leading: Icon(b.icon, color: const Color(0xFF16A34A)),
                title: Text(b.title),
                subtitle: Text(b.desc),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Obligations
          const Text(
            'Your Obligations',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._obligations.map(
            (o) => Card(
              child: ListTile(
                leading: const Icon(
                  Icons.assignment_outlined,
                  color: Colors.amber,
                ),
                title: Text(o),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recruitment target
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Who we\'re looking for',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• English teachers with 100+ students'),
                  Text('• Active on Instagram/TikTok/Facebook'),
                  Text(
                    '• Hashtags: #gurubahasainggris #lestofl #persiapanielts',
                  ),
                  Text('• EduBot channel followers who are teachers'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // CTA
          Card(
            color: const Color(0xFF16A34A),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Ready to apply?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Contact us via WhatsApp or Telegram to apply. We onboard 20 founding ambassadors.',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp'),
                        onPressed: () => _open('https://wa.me/6281234567890'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF16A34A),
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text('Telegram'),
                        onPressed: () => _open('https://t.me/osee_edubot'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(String url) {
    launchUrl(Uri.parse(url));
  }
}

class _Benefit {
  final IconData icon;
  final String title;
  final String desc;
  const _Benefit(this.icon, this.title, this.desc);
}

const _benefits = <_Benefit>[
  _Benefit(
    Icons.all_inclusive,
    'Unlimited AI',
    'No quota on grading, generation, or reports.',
  ),
  _Benefit(
    Icons.payments,
    '2x Commission',
    'Rp 20k per first test, Rp 100k per booking, Rp 30k/month premium.',
  ),
  _Benefit(
    Icons.verified,
    'Certified Educator Badge',
    'Show on profile + reports.',
  ),
  _Benefit(
    Icons.camera_alt,
    'Featured on Social Media',
    'OSEE will feature you on Instagram, TikTok, and the website.',
  ),
  _Benefit(
    Icons.lightbulb,
    'Early Access',
    'Try new features before anyone else.',
  ),
  _Benefit(Icons.star, 'Free Pro for Life', 'No Rp 50k/month — free forever.'),
];

const _obligations = <String>[
  'Use the platform with your students (real usage).',
  'Post about it on Instagram/TikTok at least 1x/month.',
  'Recruit 5 other teachers in first 3 months.',
  'Provide weekly feedback to the OSEE team.',
];
