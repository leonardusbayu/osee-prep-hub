import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/ui_components.dart';
import '../../../app/theme.dart';

/// Teacher dashboard — modern professional redesign.
class TeacherDashboardPage extends ConsumerStatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  ConsumerState<TeacherDashboardPage> createState() =>
      _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends ConsumerState<TeacherDashboardPage> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.create();
      final response = await dio.get('/teacher/dashboard');
      setState(() {
        _stats = response.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load dashboard';
        _isLoading = false;
      });
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
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDashboard,
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
          ? ErrorState(message: _error!, onRetry: _loadDashboard)
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              color: OseeTheme.primary,
              child: _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    final stats = _stats ?? {};
    final user = stats['user'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        _GreetingHeader(name: user['name'] as String?),
        const SizedBox(height: Spacing.lg),

        // Stats
        SectionHeader(title: 'Overview'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: Responsive.statGridColumns(context),
          childAspectRatio: 1.25,
          crossAxisSpacing: Spacing.sm,
          mainAxisSpacing: Spacing.sm,
          children: [
            StatCard(
              icon: Icons.groups_rounded,
              label: 'Students',
              value: '${stats['total_students'] ?? 0}',
              color: OseeTheme.success,
            ),
            StatCard(
              icon: Icons.class_rounded,
              label: 'Classrooms',
              value: '${stats['classrooms_count'] ?? 0}',
              color: OseeTheme.primary,
            ),
            StatCard(
              icon: Icons.payments_rounded,
              label: 'Commission',
              value: 'Rp ${_formatNum(stats['commission_this_month'] ?? 0)}',
              color: OseeTheme.warning,
            ),
            StatCard(
              icon: Icons.auto_awesome_rounded,
              label: 'AI Credits',
              value: '${stats['ai_quota_remaining'] ?? 0}',
              color: OseeTheme.accent,
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),

        // Quick actions
        SectionHeader(title: 'Quick Actions'),
        _ActionGrid(),
        const SizedBox(height: Spacing.lg),

        // Recent activity
        SectionHeader(title: 'Recent Activity'),
        _ActivityList(activities: stats['recent_activity'] as List? ?? []),
      ],
    );
  }

  String _formatNum(dynamic n) {
    final i = int.tryParse('$n') ?? 0;
    if (i >= 1000000) return '${(i / 1000000).toStringAsFixed(1)}M';
    if (i >= 1000) return '${(i / 1000).toStringAsFixed(0)}k';
    return '$i';
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? 'Good morning'
        : hour < 15
        ? 'Good afternoon'
        : 'Good evening';

    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [OseeTheme.primary, OseeTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting 👋',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name ?? 'Teacher',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final _actions = [
    _Action(Icons.view_kanban_rounded, 'Syllabi', '/teacher/syllabi'),
    _Action(Icons.class_outlined, 'Classrooms', '/teacher/classrooms'),
    _Action(Icons.edit_note_rounded, 'AI Grader', '/teacher/ai-grader'),
    _Action(Icons.mic_rounded, 'Speaking', '/teacher/speaking-grader'),
    _Action(Icons.auto_awesome_outlined, 'Generator', '/teacher/generator'),
    _Action(Icons.shopping_cart_outlined, 'Orders', '/teacher/orders'),
    _Action(Icons.payments_outlined, 'Earnings', '/teacher/commission'),
    _Action(Icons.picture_as_pdf_outlined, 'Reports', '/teacher/reports'),
    _Action(Icons.star_rounded, 'Upgrade', '/teacher/upgrade'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: _actions.map((a) => _ActionChip(action: a)).toList(),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final String route;
  const _Action(this.icon, this.label, this.route);
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.action});
  final _Action action;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(action.label),
      avatar: Icon(action.icon, size: 18, color: OseeTheme.primary),
      onPressed: () => context.push(action.route),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activities});
  final List activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(Spacing.lg),
        decoration: BoxDecoration(
          color: OseeTheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No recent activity yet',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: OseeTheme.textSecondary),
        ),
      );
    }
    return Column(
      children: activities.take(5).map((activity) {
        final a = activity as Map<String, dynamic>;
        final status = a['status'] as String? ?? '';
        final isPaid = status == 'paid';
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (isPaid ? OseeTheme.success : OseeTheme.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPaid
                      ? Icons.check_circle_rounded
                      : Icons.hourglass_top_rounded,
                  color: isPaid ? OseeTheme.success : OseeTheme.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: Spacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (a['action'] as String? ?? 'Event')
                          .replaceAll('_', ' ')
                          .split(' ')
                          .map((w) => w[0].toUpperCase() + w.substring(1))
                          .join(' '),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Rp ${a['amount_idr'] ?? 0} · $status',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OseeTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(a['created_at'] as String?),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: OseeTheme.textMuted),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day}/${d.month}';
  }
}
