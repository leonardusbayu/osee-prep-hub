import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/ui_components.dart';
import '../../../app/theme.dart';

/// Student dashboard — modern professional redesign.
class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  ConsumerState<StudentDashboardPage> createState() =>
      _StudentDashboardPageState();
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/student/dashboard');
      setState(() {
        _dashboard = r.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load';
        _isLoading = false;
      });
    }
  }

  Future<void> _joinClass() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the join code from your teacher:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Join code',
                hintText: 'ABC123',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;

    try {
      final dio = ApiClient.create();
      await dio.post(
        '/student/classrooms/join',
        data: {'join_code': code},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Joined!')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
          IconButton(
            icon: const Icon(Icons.group_add_rounded),
            onPressed: _joinClass,
            tooltip: 'Join class',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              color: OseeTheme.primary,
              child: _buildContent(_dashboard ?? {}),
            ),
    );
  }

  Widget _buildContent(Map<String, dynamic> d) {
    final progress = d['progress'] as Map<String, dynamic>? ?? {};
    final classrooms = d['classrooms'] as List? ?? [];
    final readiness = d['readiness'] as int? ?? 0;

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        _ReadinessCard(readiness: readiness),
        const SizedBox(height: Spacing.lg),
        SectionHeader(title: 'Navigate'),
        _NavGrid(),
        const SizedBox(height: Spacing.lg),
        SectionHeader(title: 'Recent Progress'),
        _ProgressCard(progress: progress),
        const SizedBox(height: Spacing.lg),
        SectionHeader(title: 'My Classes'),
        if (classrooms.isEmpty)
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: OseeTheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No classes yet — join one with a code from your teacher',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: OseeTheme.textSecondary),
            ),
          )
        else
          ...classrooms.map((c) => _ClassroomTile(c as Map<String, dynamic>)),
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
        ? OseeTheme.success
        : readiness > 50
        ? OseeTheme.warning
        : OseeTheme.danger;
    final label = readiness > 80
        ? 'Ready'
        : readiness > 50
        ? 'Almost Ready'
        : 'Preparing';

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: readiness / 100,
                  strokeWidth: 6,
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                ),
                Text(
                  '$readiness%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 16,
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
                Text(
                  'Readiness',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  readiness > 80
                      ? "You're ready to book your test!"
                      : 'Keep practicing to improve',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavGrid extends StatelessWidget {
  final _items = [
    _NavItem(Icons.trending_up_rounded, 'Progress', '/student/progress'),
    _NavItem(Icons.verified_rounded, 'Readiness', '/student/readiness'),
    _NavItem(Icons.video_library_rounded, 'Videos', '/student/videos'),
    _NavItem(Icons.videocam_rounded, 'Live', '/student/classes'),
    _NavItem(Icons.compare_arrows_rounded, 'Cross-Exam', '/student/cross-exam'),
    _NavItem(Icons.event_rounded, 'Book Test', '/student/book-test'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.1,
      crossAxisSpacing: Spacing.sm,
      mainAxisSpacing: Spacing.sm,
      children: _items.map((i) => _NavTile(item: i)).toList(),
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
    return Material(
      color: OseeTheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go(item.route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: OseeTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item.icon, color: OseeTheme.primary, size: 20),
            ),
            const SizedBox(height: Spacing.xs + 2),
            Text(
              item.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: OseeTheme.textPrimary,
              ),
            ),
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

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: OseeTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: OseeTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: OseeTheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: Spacing.sm + 2),
              Text(
                '$count practice sessions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          const Divider(),
          InfoRow(label: 'TOEFL iBT', value: ibt?.toString() ?? '—'),
          InfoRow(label: 'TOEFL ITP', value: itp?.toString() ?? '—'),
          InfoRow(label: 'IELTS Band', value: ielts?.toString() ?? '—'),
          InfoRow(label: 'TOEIC', value: toeic?.toString() ?? '—'),
        ],
      ),
    );
  }
}

class _ClassroomTile extends StatelessWidget {
  const _ClassroomTile(this.c);
  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: OseeTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: OseeTheme.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.class_rounded,
              color: OseeTheme.success,
              size: 18,
            ),
          ),
          const SizedBox(width: Spacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['name'] as String? ?? '',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Teacher: ${c['teacher_name'] as String? ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OseeTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: OseeTheme.textMuted),
        ],
      ),
    );
  }
}

class _BookTestCTA extends StatelessWidget {
  const _BookTestCTA({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OseeTheme.success.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: OseeTheme.success,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready for the official test?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Book at OSEE test center',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OseeTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: OseeTheme.success),
            ],
          ),
        ),
      ),
    );
  }
}
