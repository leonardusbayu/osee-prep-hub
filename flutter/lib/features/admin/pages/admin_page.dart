import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:js' as js;

import '../../../core/api_client.dart';
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
    setState(() { _isLoading = true; _error = null; });
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/admin/stats');
      setState(() { _stats = r.data as Map<String, dynamic>?; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load stats'; _isLoading = false; });
    }
  }

  void _openAdminPanel() {
    // The admin React app — replace with the actual deployed URL.
    const url = 'https://prep.osee.co.id/admin';
    try {
      js.context.callMethod('open', [url, '_blank']);
    } catch (_) {
      // Non-web fallback
    }
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
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.admin_panel_settings, size: 32, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Admin Panel (Web)',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The full admin dashboard (Users, Pricing, Knowledge Base, Commission, '
                    'Ambassadors, Analytics) is available in the web admin panel.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Admin Panel'),
                    onPressed: _openAdminPanel,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Quick Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_isLoading)
            const LoadingState()
          else if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            )
          else if (_stats != null)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _StatCard('Total Users', '${_stats!['total_users'] ?? 0}', Colors.blue),
                _StatCard('Teachers', '${_stats!['active_teachers'] ?? 0}', Colors.green),
                _StatCard('Bookings', '${_stats!['total_bookings'] ?? 0}', Colors.purple),
                _StatCard('Revenue', 'Rp ${_stats!['total_revenue'] ?? 0}', Colors.orange),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.color);
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
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}