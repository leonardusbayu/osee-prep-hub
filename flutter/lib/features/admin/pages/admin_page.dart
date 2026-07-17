import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';
import '../../auth/providers/auth_provider.dart';

/// Admin page (Flutter) — Task 18.4.
///
/// Admin role uses the React/Vite admin panel (frontend-admin) deployed at a
/// different subdomain. This Flutter page:
///   1. Shows a clear message that admin operations are in the web panel.
///   2. Provides an "Open Admin Panel" button that opens the webapp URL in a
///      new browser tab.
///   3. Shows quick stats (read-only) from /admin/stats so admin can glance
///      at numbers without leaving Flutter.
class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
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
      final r = await dio.get('/admin/stats');
      setState(() {
        _stats = r.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load stats';
        _isLoading = false;
      });
    }
  }

  void _openAdminPanel() {
    const url = 'https://prep.osee.co.id/admin';
    launchUrl(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
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
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          PageHeader(
            title: 'Admin Panel',
            subtitle:
                'Open the dedicated admin web app for full operational controls.',
            icon: Icons.admin_panel_settings_rounded,
            trailing: FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open'),
              onPressed: _openAdminPanel,
            ),
          ),
          const SizedBox(height: Spacing.md),
          SurfaceCard(
            color: OseeTheme.primary.withValues(alpha: 0.04),
            borderColor: OseeTheme.primary.withValues(alpha: 0.16),
            child: Text(
              'The full admin dashboard covers users, pricing, knowledge base, commission, ambassadors, and analytics.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: OseeTheme.textSecondary),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          const SectionHeader(title: 'Quick Stats'),
          if (_isLoading)
            const LoadingState()
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else if (_stats != null)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                StatCard(
                  icon: Icons.people_rounded,
                  label: 'Total Users',
                  value: '${_stats!['total_users'] ?? 0}',
                  color: OseeTheme.primary,
                ),
                StatCard(
                  icon: Icons.school_rounded,
                  label: 'Teachers',
                  value: '${_stats!['active_teachers'] ?? 0}',
                  color: OseeTheme.success,
                ),
                StatCard(
                  icon: Icons.event_available_rounded,
                  label: 'Bookings',
                  value: '${_stats!['total_bookings'] ?? 0}',
                  color: OseeTheme.accent,
                ),
                StatCard(
                  icon: Icons.payments_rounded,
                  label: 'Revenue',
                  value: 'Rp ${_stats!['total_revenue'] ?? 0}',
                  color: OseeTheme.warning,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
