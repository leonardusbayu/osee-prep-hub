import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../core/responsive.dart';
import '../../auth/providers/auth_provider.dart';

/// Teacher dashboard — Task 2.1.
///
/// Shows: total students, active classrooms, commission this month,
/// AI credits remaining, recent activity feed, order section link,
/// voucher stats.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboard,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadDashboard,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildStatsGrid(),
    );
  }

  Widget _buildStatsGrid() {
    final stats = _stats ?? {};
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: Responsive.statGridColumns(context),
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _StatCard(
                icon: Icons.groups,
                label: 'Total Students',
                value: '${stats['total_students'] ?? 0}',
                color: Colors.blue,
              ),
              _StatCard(
                icon: Icons.class_,
                label: 'Classrooms',
                value: '${stats['classrooms_count'] ?? 0}',
                color: Colors.green,
              ),
              _StatCard(
                icon: Icons.payments,
                label: 'Commission (Month)',
                value: 'Rp ${stats['commission_this_month'] ?? 0}',
                color: Colors.orange,
              ),
              _StatCard(
                icon: Icons.auto_awesome,
                label: 'AI Credits Left',
                value: '${stats['ai_quota_remaining'] ?? 0}',
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick actions
          Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Syllabi'),
                avatar: const Icon(Icons.view_kanban_outlined),
                onPressed: () => context.push('/teacher/syllabi'),
              ),
              ActionChip(
                label: const Text('Classrooms'),
                avatar: const Icon(Icons.class_outlined),
                onPressed: () => context.push('/teacher/classrooms'),
              ),
              ActionChip(
                label: const Text('AI Grader'),
                avatar: const Icon(Icons.edit_note),
                onPressed: () => context.push('/teacher/ai-grader'),
              ),
              ActionChip(
                label: const Text('Order Tests'),
                avatar: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => context.push('/teacher/orders'),
              ),
              ActionChip(
                label: const Text('Commission'),
                avatar: const Icon(Icons.payments_outlined),
                onPressed: () => context.push('/teacher/commission'),
              ),
              ActionChip(
                label: const Text('Reports'),
                avatar: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: () => context.push('/teacher/reports'),
              ),
              ActionChip(
                label: const Text('Settings'),
                avatar: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/teacher/settings'),
              ),
              ActionChip(
                label: const Text('Upgrade'),
                avatar: const Icon(Icons.star_outline),
                onPressed: () => context.push('/teacher/upgrade'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent activity
          Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if ((stats['recent_activity'] as List?)?.isEmpty ?? true)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No recent activity yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ),
            )
          else
            ...(stats['recent_activity'] as List).take(5).map((activity) {
              final a = activity as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(a['action'] as String? ?? 'Event'),
                  subtitle: Text('Rp ${a['amount_idr'] ?? 0} · ${a['status'] ?? ''}\n${a['created_at'] as String? ?? ''}'),
                  isThreeLine: true,
                ),
              );
            }),

          // Order section quick link
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.shopping_cart, size: 32),
              title: const Text('Order Tests & Vouchers'),
              subtitle: const Text('Buy mock tests, official tests, and Tutor Bot premium at teacher rates'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/teacher/orders'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}