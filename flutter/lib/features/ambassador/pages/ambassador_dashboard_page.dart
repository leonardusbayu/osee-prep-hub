import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../shared/widgets/ui_components.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../app/theme.dart';

/// Ambassador dashboard — Task 17.2.
class AmbassadorDashboardPage extends ConsumerStatefulWidget {
  const AmbassadorDashboardPage({super.key});

  @override
  ConsumerState<AmbassadorDashboardPage> createState() =>
      _AmbassadorDashboardPageState();
}

class _AmbassadorDashboardPageState
    extends ConsumerState<AmbassadorDashboardPage> {
  Map<String, dynamic>? _stats;
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
      final r = await dio.get('/ambassador/dashboard');
      setState(() {
        _stats = r.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambassador Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Generate proposal',
            onPressed: () {
              final url =
                  'https://osee-prep-hub-worker.edubot-leonardus.workers.dev'
                  '/api/ambassador/proposal';
              Clipboard.setData(ClipboardData(text: url));
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Teacher Proposal'),
                  content: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Open this URL in your browser (logged in) to view/print/share the proposal:',
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          url,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: url)),
                      child: const Text('Copy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
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
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : _body(_stats ?? {}),
    );
  }

  Widget _body(Map<String, dynamic> s) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        const PageHeader(
          title: 'Ambassador Dashboard',
          subtitle:
              'Track recruited teachers, bonus performance, and ambassador resources.',
          icon: Icons.workspace_premium_rounded,
        ),
        const SizedBox(height: Spacing.lg),
        SurfaceCard(
          color: OseeTheme.warning.withValues(alpha: 0.08),
          borderColor: OseeTheme.warning.withValues(alpha: 0.24),
          child: Padding(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  size: 48,
                  color: OseeTheme.warning,
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Total Bonus Earned',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Rp ${s['total_bonus_earned'] ?? 0}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: OseeTheme.textPrimary,
                  ),
                ),
                Text('This month: Rp ${s['this_month_bonus'] ?? 0}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),

        Row(
          children: [
            Expanded(
              child: _stat(
                'Recruited Teachers',
                '${s['recruited_teachers'] ?? 0}',
                Icons.school,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: _stat(
                'Downline Activity',
                '${s['downline_activity'] ?? 0}',
                Icons.trending_up,
              ),
            ),
          ],
        ),

        const SizedBox(height: Spacing.lg),
        SurfaceCard(
          child: Padding(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ambassador Benefits',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text('• 2x commission rate on all student actions'),
                const Text('• Featured listing on teacher directory'),
                const Text('• Early access to new features'),
                const Text('• Exclusive ambassador badge on profile'),
                const Text('• Monthly bonus for top performers'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return SurfaceCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Icon(icon, color: OseeTheme.primary),
            const SizedBox(height: Spacing.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
