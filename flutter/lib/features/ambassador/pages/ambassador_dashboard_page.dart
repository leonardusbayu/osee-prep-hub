import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';

/// Ambassador dashboard — Task 17.2.
class AmbassadorDashboardPage extends ConsumerStatefulWidget {
  const AmbassadorDashboardPage({super.key});

  @override
  ConsumerState<AmbassadorDashboardPage> createState() => _AmbassadorDashboardPageState();
}

class _AmbassadorDashboardPageState extends ConsumerState<AmbassadorDashboardPage> {
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
      final r = await dio.get('/ambassador/dashboard');
      setState(() { _stats = r.data as Map<String, dynamic>?; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambassador Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _body(_stats ?? {}),
    );
  }

  Widget _body(Map<String, dynamic> s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero card
        Card(
          color: Colors.amber.shade100,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.workspace_premium, size: 56, color: Colors.orange),
                const SizedBox(height: 12),
                Text(
                  'Total Bonus Earned',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Rp ${s['total_bonus_earned'] ?? 0}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text('This month: Rp ${s['this_month_bonus'] ?? 0}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(child: _stat('Recruited Teachers', '${s['recruited_teachers'] ?? 0}', Icons.school)),
            const SizedBox(width: 12),
            Expanded(child: _stat('Downline Activity', '${s['downline_activity'] ?? 0}', Icons.trending_up)),
          ],
        ),

        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ambassador Benefits', style: Theme.of(context).textTheme.titleMedium),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}