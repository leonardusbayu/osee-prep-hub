import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/ui_components.dart';
import '../../../app/theme.dart';

/// Partner (institution) dashboard — Task 15.8.
class PartnerDashboardPage extends ConsumerStatefulWidget {
  const PartnerDashboardPage({super.key});

  @override
  ConsumerState<PartnerDashboardPage> createState() =>
      _PartnerDashboardPageState();
}

class _PartnerDashboardPageState extends ConsumerState<PartnerDashboardPage> {
  Map<String, dynamic>? _stats;
  List<dynamic>? _teachers;
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
      final statsR = await dio.get('/partner/dashboard');
      final teachersR = await dio.get('/partner/teachers');
      setState(() {
        _stats = statsR.data as Map<String, dynamic>?;
        _teachers = teachersR.data['teachers'] as List?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load';
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
        title: const Text('Institution Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    final s = _stats ?? {};
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        const PageHeader(
          title: 'Institution Dashboard',
          subtitle:
              'Manage teachers, student activity, and institution-level ordering.',
          icon: Icons.business_rounded,
        ),
        const SizedBox(height: Spacing.lg),
        SectionHeader(title: 'Overview'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.4,
          crossAxisSpacing: Spacing.sm,
          mainAxisSpacing: Spacing.sm,
          children: [
            StatCard(
              icon: Icons.school_rounded,
              label: 'Teachers',
              value: '${s['teachers_count'] ?? 0}',
              color: OseeTheme.primary,
            ),
            StatCard(
              icon: Icons.people_rounded,
              label: 'Students',
              value: '${s['total_students'] ?? 0}',
              color: OseeTheme.success,
            ),
            StatCard(
              icon: Icons.receipt_long_rounded,
              label: 'Orders',
              value: '${s['total_orders'] ?? 0}',
              color: OseeTheme.warning,
            ),
            StatCard(
              icon: Icons.payments_rounded,
              label: 'Total Spent',
              value: 'Rp ${_formatNum(s['total_spent'] ?? 0)}',
              color: OseeTheme.accent,
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),

        SectionHeader(title: 'Actions'),
        Wrap(
          spacing: Spacing.sm,
          children: [
            ActionChip(
              avatar: const Icon(Icons.person_add, size: 18),
              label: const Text('Invite Teacher'),
              onPressed: _inviteTeacherDialog,
            ),
            ActionChip(
              avatar: const Icon(Icons.shopping_cart, size: 18),
              label: const Text('Order Tests'),
              onPressed: () => context.push('/teacher/orders'),
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),

        SectionHeader(title: 'Teachers in Institution'),
        if ((_teachers ?? []).isEmpty)
          const SurfaceCard(child: Text('No teachers yet — invite one.'))
        else
          ...(_teachers ?? []).map((t) {
            final m = t as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: SurfaceCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.person_outline_rounded,
                    color: OseeTheme.primary,
                  ),
                  title: Text(
                    m['name'] as String? ?? '',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    '${m['email']} · ${m['students_count'] ?? 0} students',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  String _formatNum(dynamic n) {
    final i = int.tryParse('$n') ?? 0;
    if (i >= 1000000) return '${(i / 1000000).toStringAsFixed(1)}M';
    if (i >= 1000) return '${(i / 1000).toStringAsFixed(0)}k';
    return '$i';
  }

  void _inviteTeacherDialog() {
    final emailCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite Teacher'),
        content: TextField(
          controller: emailCtrl,
          decoration: const InputDecoration(labelText: 'Teacher email'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final dio = ApiClient.create();
                await dio.post(
                  '/partner/teachers/invite',
                  data: {'email': emailCtrl.text.trim()},
                );
                if (mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invited ${emailCtrl.text.trim()}')),
                  );
                }
                _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              }
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }
}
