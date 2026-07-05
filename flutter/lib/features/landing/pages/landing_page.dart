import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Magazine-style landing page — editorial layout with strong typography.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Top bar
          SliverToBoxAdapter(child: _TopBar()),

          // Hero — full-screen editorial cover
          SliverToBoxAdapter(child: _HeroCover()),

          // Issue number / date strip
          SliverToBoxAdapter(child: _IssueStrip()),

          // Features — magazine grid
          SliverToBoxAdapter(child: _FeatureSection()),

          // How it works — editorial spread
          SliverToBoxAdapter(child: _HowItWorksSpread()),

          // Pricing — clean table
          SliverToBoxAdapter(child: _PricingSection()),

          // Final CTA
          SliverToBoxAdapter(child: _FinalCTA()),

          // Footer
          SliverToBoxAdapter(child: _Footer()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Top navigation bar
// ─────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F5F0),
        border: Border(bottom: BorderSide(color: Color(0xFFE8E6E1))),
      ),
      child: Row(
        children: [
          Text(
            'OSEE',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 22,
                  letterSpacing: 4,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: const Color(0xFFE63946),
            child: const Text(
              'PREP HUB',
              style: TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign In'),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () => context.go('/register'),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Hero cover — full-screen editorial
// ─────────────────────────────────────────────
class _HeroCover extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 600,
      color: const Color(0xFF1A1A2E),
      child: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1A2E),
                  const Color(0xFF16213E),
                  const Color(0xFF0F3460).withOpacity(0.8),
                ],
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Kicker
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFC9A96E), width: 1),
                  ),
                  child: const Text(
                    'AI TEACHING ASSISTANT',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC9A96E),
                      letterSpacing: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Headline
                Text(
                  'Teach English\nSmarter.',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 72,
                        height: 1.05,
                      ),
                ),
                const SizedBox(height: 24),
                // Subheadline
                SizedBox(
                  width: 500,
                  child: Text(
                    'Free AI tools for English teachers in Indonesia. Grade essays, generate materials, track student progress — all powered by GPT-4o-mini and your knowledge of CEFR, IELTS, and TOEFL.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 18,
                          height: 1.6,
                        ),
                  ),
                ),
                const SizedBox(height: 36),
                // CTAs
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/register'),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('START FREE'),
                    ),
                    const SizedBox(width: 20),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: Text(
                        'I already have an account',
                        style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.6),
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Issue strip — magazine date/issue number
// ─────────────────────────────────────────────
class _IssueStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F5F0),
        border: Border(
          top: BorderSide(color: Color(0xFF1A1A2E), width: 2),
          bottom: BorderSide(color: Color(0xFFE8E6E1)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'VOL. 1',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(width: 24),
          Text(
            'ISSUE 01',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(width: 24),
          Text(
            'JULY 2026',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const Spacer(),
          Text(
            'FREE FOR TEACHERS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFE63946),
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Features — magazine grid layout
// ─────────────────────────────────────────────
class _FeatureSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
      color: const Color(0xFFF7F5F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 40,
                height: 2,
                color: const Color(0xFFE63946),
              ),
              const SizedBox(width: 12),
              Text(
                'FEATURES',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Everything you need\nto teach better.',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 48),
          // Feature grid — 2 columns, magazine style
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildFeatureColumn([
                _Feature(
                  number: '01',
                  title: 'AI Writing Grader',
                  description: 'Grade student essays with GPT-4o-mini powered by CEFR, IELTS, and TOEFL rubrics. Get instant band scores, criteria breakdowns, and improvement suggestions.',
                  icon: Icons.edit_note,
                ),
                _Feature(
                  number: '03',
                  title: 'Material Generator',
                  description: 'Generate reading passages, grammar exercises, vocabulary sets, and mock tests on any topic — aligned to your students\' exam level.',
                  icon: Icons.auto_awesome,
                ),
                _Feature(
                  number: '05',
                  title: 'Commission System',
                  description: 'Earn Rp 10,000 per student who completes their first practice test. Rp 50,000 per official test booking. 2x rates for ambassadors.',
                  icon: Icons.payments_outlined,
                ),
              ])),
              const SizedBox(width: 48),
              Expanded(child: _buildFeatureColumn([
                _Feature(
                  number: '02',
                  title: 'Speaking Evaluation',
                  description: 'Students record audio, get AI-powered transcription and fluency scoring via Whisper. Pronunciation, coherence, and grammar feedback.',
                  icon: Icons.mic_none,
                ),
                _Feature(
                  number: '04',
                  title: 'Syllabus Builder',
                  description: 'Drag-and-drop curriculum from all 4 OSEE practice platforms. Mix ITP, iBT, IELTS, and TOEIC materials. Add AI-generated content.',
                  icon: Icons.list_alt,
                ),
                _Feature(
                  number: '06',
                  title: 'Order Tests & Vouchers',
                  description: 'Buy mock tests, official TOEFL/TOEIC, and Tutor Bot premium at discounted teacher rates. Distribute vouchers to students.',
                  icon: Icons.shopping_bag_outlined,
                ),
              ])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureColumn(List<_Feature> features) {
    return Column(
      children: features
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: f,
              ))
          .toList(),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String number;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              number,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 36,
                    color: const Color(0xFFE63946),
                    fontWeight: FontWeight.w400,
                  ),
            ),
            const SizedBox(width: 16),
            Icon(icon, size: 28, color: const Color(0xFF1A1A2E)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// How it works — editorial spread
// ─────────────────────────────────────────────
class _HowItWorksSpread extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 40, height: 2, color: const Color(0xFFE63946)),
              const SizedBox(width: 12),
              Text('HOW IT WORKS', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Three steps to a\nsmarter classroom.',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(child: _Step(
                number: '1',
                title: 'Register',
                description: 'Create your free teacher account. No credit card needed. Get 50 AI grading credits and 10 material generation credits per month.',
              )),
              Container(width: 1, height: 120, color: const Color(0xFFE8E6E1)),
              Expanded(child: _Step(
                number: '2',
                title: 'Invite Students',
                description: 'Share your referral code or classroom join code. Students register and get linked to your classroom automatically.',
              )),
              Container(width: 1, height: 120, color: const Color(0xFFE8E6E1)),
              Expanded(child: _Step(
                number: '3',
                title: 'Teach & Earn',
                description: 'Grade essays with AI, generate materials, build syllabi. Earn commission when students practice and book official tests.',
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.description});
  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 64,
                  color: const Color(0xFFC9A96E),
                  fontWeight: FontWeight.w400,
                ),
          ),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Pricing — clean editorial table
// ─────────────────────────────────────────────
class _PricingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 80),
      color: const Color(0xFFF7F5F0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 40, height: 2, color: const Color(0xFFE63946)),
              const SizedBox(width: 12),
              Text('PRICING', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Free for teachers.\nAlways.',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _PriceCard(
                tier: 'FREE',
                price: 'Rp 0',
                period: '/month',
                features: const ['50 AI grading credits', '10 material generations', 'Unlimited classrooms', 'Commission on student actions'],
                isFeatured: false,
              )),
              const SizedBox(width: 24),
              Expanded(child: _PriceCard(
                tier: 'PRO',
                price: 'Rp 50k',
                period: '/month',
                features: const ['Unlimited AI grading', 'Unlimited generation', 'Classroom reports', 'Hide OSEE branding', 'Priority support'],
                isFeatured: true,
              )),
              const SizedBox(width: 24),
              Expanded(child: _PriceCard(
                tier: 'INSTITUTION',
                price: 'Rp 200k+',
                period: '/month',
                features: const ['Everything in Pro', 'Multi-teacher management', 'White-label branding', 'Custom subdomain', 'Bulk test ordering'],
                isFeatured: false,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.tier,
    required this.price,
    required this.period,
    required this.features,
    required this.isFeatured,
  });

  final String tier;
  final String price;
  final String period;
  final List<String> features;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isFeatured ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isFeatured ? const Color(0xFFE63946) : const Color(0xFFE8E6E1),
          width: isFeatured ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tier,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isFeatured ? const Color(0xFFC9A96E) : const Color(0xFF9B9B9B),
                ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: isFeatured ? Colors.white : const Color(0xFF1A1A2E),
                    ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  period,
                  style: TextStyle(
                    fontFamily: 'Helvetica',
                    fontSize: 12,
                    color: isFeatured ? Colors.white.withOpacity(0.5) : const Color(0xFF9B9B9B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check,
                      size: 16,
                      color: isFeatured ? const Color(0xFFC9A96E) : const Color(0xFF6B8E7F),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 14,
                          color: isFeatured ? Colors.white.withOpacity(0.8) : const Color(0xFF1A1A2E),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: isFeatured
                ? FilledButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('GET PRO'),
                  )
                : ElevatedButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('GET STARTED'),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Final CTA
// ─────────────────────────────────────────────
class _FinalCTA extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 80),
      color: const Color(0xFF1A1A2E),
      child: Column(
        children: [
          Text(
            'Start teaching smarter\ntoday.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 500,
            child: Text(
              'Join the OSEE education ecosystem. Free for teachers, with commission on every student action. No credit card needed to start.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.6),
                  ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.go('/register'),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('CREATE FREE ACCOUNT'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 80),
      color: const Color(0xFFF7F5F0),
      child: Column(
        children: [
          const Divider(color: Color(0xFFE8E6E1)),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'OSEE PREP HUB',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              Text(
                'prep.osee.co.id',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 24),
              Text(
                '© 2026 OSEE Education Hub',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'ETS-Certified Test Center',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B8E7F),
                    ),
              ),
              const SizedBox(width: 24),
              Text(
                'Powered by GPT-4o-mini + pgvector',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B8E7F),
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}