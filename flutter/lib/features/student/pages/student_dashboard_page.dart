import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/ui_components.dart';

/// Student dashboard — Task 11.1.
class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  ConsumerState<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage> {
  Map<String, dynamic>? _dashboard;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/student/dashboard');
      setState(() { _dashboard = r.data as Map<String, dynamic>?; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load'; _isLoading = false; });
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Learning'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'Refresh'),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'Logout'),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _buildContent(_dashboard ?? {})),
    );
  }

  Widget _buildContent(Map<String, dynamic> d) {
    final progress = d['progress'] as Map<String, dynamic>? ?? {};
    final classrooms = d['classrooms'] as List? ?? [];
    final readiness = d['readiness'] as int? ?? 0;

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        // Readiness gauge
        _ReadinessCard(readiness: readiness),
        const SizedBox(height: Spacing.lg),

        // Quick navigation
        SectionHeader(title: 'Navigate'),
        _NavGrid(),
        const SizedBox(height: Spacing.lg),

        // Recent progress
        SectionHeader(title: 'Recent Progress'),
        _ProgressCard(progress: progress),
        const SizedBox(height: Spacing.lg),

        // My classes
        SectionHeader(title: 'My Classes'),
        if (classrooms.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Text(
                'No classes yet — join one with a code from your teacher',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
            ),
          )
        else
          ...classrooms.map((c) => _ClassroomTile(c as Map<String, dynamic>)),

        // Book test CTA
        if (readiness > 80) ...[
          const SizedBox(height: Spacing.lg),
          _BookTestCTA(onTap: () => context.go('/student/book-test')),
        ],
      ],
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.readiness});
  final int readiness;

  @override
  Widget build(BuildContext context) {
    final color = readiness > 80
        ? const Color(0xFF6B8E7F)
        : readiness > 50
            ? const Color(0xFFC9A96E)
            : const Color(0xFFE63946);
    final label = readiness > 80 ? 'Ready' : readiness > 50 ? 'Almost Ready' : 'Preparing';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Row(
          children: [
            // Circular progress
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: readiness / 100,
                    strokeWidth: 6,
                    color: color,
                    backgroundColor: Theme.of(context).dividerColor,
                  ),
                  Text(
                    '$readiness%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Readiness', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    readiness > 80
                        ? 'You\'re ready to book your official test!'
                        : 'Keep practicing to improve your score',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(Icons.trending_up, 'Progress', '/student/progress'),
      _NavItem(Icons.verified, 'Readiness', '/student/readiness'),
      _NavItem(Icons.video_library, 'Videos', '/student/videos'),
      _NavItem(Icons.videocam, 'Live', '/student/classes'),
      _NavItem(Icons.compare_arrows, 'Cross-Exam', '/student/cross-exam'),
      _NavItem(Icons.event, 'Book Test', '/student/book-test'),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.1,
      crossAxisSpacing: Spacing.sm,
      mainAxisSpacing: Spacing.sm,
      children: items.map((i) => _NavTile(item: i)).toList(),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(this.icon, this.label, this.route);
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item});
  final _NavItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: () => context.go(item.route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: Spacing.xs),
            Text(item.label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});
  final Map<String, dynamic> progress;

  @override
  Widget build(BuildContext context) {
    final ibt = progress['ibt_latest_score'];
    final itp = progress['itp_latest_score'];
    final ielts = progress['ielts_latest_band'];
    final toeic = progress['toeic_latest_score'];
    final count = progress['total_practice_count'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count total practice sessions', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: Spacing.sm),
            const Divider(),
            InfoRow(label: 'TOEFL iBT', value: ibt?.toString() ?? '—'),
            InfoRow(label: 'TOEFL ITP', value: itp?.toString() ?? '—'),
            InfoRow(label: 'IELTS Band', value: ielts?.toString() ?? '—'),
            InfoRow(label: 'TOEIC', value: toeic?.toString() ?? '—'),
          ],
        ),
      ),
    );
  }
}

class _ClassroomTile extends StatelessWidget {
  const _ClassroomTile(this.c);
  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
        leading: const Icon(Icons.class_, color: Color(0xFF6B8E7F)),
        title: Text(c['name'] as String? ?? '', style: Theme.of(context).textTheme.bodyLarge),
        subtitle: Text('Teacher: ${c['teacher_name'] as String? ?? ''}', style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _BookTestCTA extends StatelessWidget {
  const _BookTestCTA({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF6B8E7F).withValues(alpha: 0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFF6B8E7F), size: 32),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ready for the official test?', style: Theme.of(context).textTheme.titleMedium),
                    Text('Book your TOEFL or TOEIC at OSEE test center', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF6B8E7F)),
            ],
          ),
        ),
      ),
    );
  }
}