import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/responsive.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/ui_components.dart';

/// Teacher dashboard — Task 2.1.
class TeacherDashboardPage extends ConsumerStatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  ConsumerState<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
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
    setState(() { _isLoading = true; _error = null; });
    try {
      final dio = ApiClient.create();
      final response = await dio.get('/teacher/dashboard');
      setState(() {
        _stats = response.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load dashboard'; _isLoading = false; });
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDashboard, tooltip: 'Refresh'),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'Logout'),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _loadDashboard)
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
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
        // Greeting header
        _GreetingHeader(name: user['name'] as String?),
        const SizedBox(height: Spacing.lg),

        // Stats grid
        SectionHeader(title: 'Overview'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: Responsive.statGridColumns(context),
          childAspectRatio: 1.4,
          crossAxisSpacing: Spacing.sm,
          mainAxisSpacing: Spacing.sm,
          children: [
            StatCard(icon: Icons.groups, label: 'Students', value: '${stats['total_students'] ?? 0}', color: const Color(0xFF6B8E7F)),
            StatCard(icon: Icons.class_, label: 'Classrooms', value: '${stats['classrooms_count'] ?? 0}', color: const Color(0xFF1A1A2E)),
            StatCard(icon: Icons.payments, label: 'Commission', value: 'Rp ${_formatNum(stats['commission_this_month'] ?? 0)}', color: const Color(0xFFC9A96E)),
            StatCard(icon: Icons.auto_awesome, label: 'AI Credits', value: '${stats['ai_quota_remaining'] ?? 0}', color: const Color(0xFFE63946)),
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
    final greeting = hour < 11 ? 'Good morning' : hour < 15 ? 'Good afternoon' : 'Good evening';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting,',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).hintColor,
          ),
        ),
        Text(
          name ?? 'Teacher',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action(Icons.view_kanban_outlined, 'Syllabi', '/teacher/syllabi'),
      _Action(Icons.class_outlined, 'Classrooms', '/teacher/classrooms'),
      _Action(Icons.edit_note, 'AI Grader', '/teacher/ai-grader'),
      _Action(Icons.auto_awesome_outlined, 'Generator', '/teacher/generator'),
      _Action(Icons.shopping_cart_outlined, 'Orders', '/teacher/orders'),
      _Action(Icons.payments_outlined, 'Earnings', '/teacher/commission'),
      _Action(Icons.picture_as_pdf_outlined, 'Reports', '/teacher/reports'),
      _Action(Icons.star_outline, 'Upgrade', '/teacher/upgrade'),
    ];

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: actions.map((a) => _ActionChip(action: a)).toList(),
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
      avatar: Icon(action.icon, size: 18),
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Text(
            'No recent activity yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
      );
    }
    return Column(
      children: activities.take(5).map((activity) {
        final a = activity as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.only(bottom: Spacing.xs),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
            leading: Icon(
              a['status'] == 'paid' ? Icons.check_circle : Icons.hourglass_top,
              color: a['status'] == 'paid' ? const Color(0xFF6B8E7F) : const Color(0xFFC9A96E),
              size: 20,
            ),
            title: Text(
              (a['action'] as String? ?? 'Event').replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14),
            ),
            subtitle: Text(
              'Rp ${a['amount_idr'] ?? 0} · ${a['status'] ?? ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Text(
              _formatDate(a['created_at'] as String?),
              style: Theme.of(context).textTheme.bodySmall,
            ),
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