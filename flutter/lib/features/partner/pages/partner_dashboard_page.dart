import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';

/// Partner (institution) dashboard — Task 15.8.
class PartnerDashboardPage extends ConsumerStatefulWidget {
  const PartnerDashboardPage({super.key});

  @override
  ConsumerState<PartnerDashboardPage> createState() => _PartnerDashboardPageState();
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
    setState(() { _isLoading = true; _error = null; });
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
      setState(() { _error = 'Failed to load'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.go('/login')),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    final s = _stats ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          children: [
            _stat('Teachers', '${s['teachers_count'] ?? 0}', Icons.school),
            _stat('Students', '${s['total_students'] ?? 0}', Icons.people),
            _stat('Orders', '${s['total_orders'] ?? 0}', Icons.receipt_long),
            _stat('Total Spent', 'Rp ${s['total_spent'] ?? 0}', Icons.payments),
          ],
        ),
        const SizedBox(height: 24),

        // Quick actions
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.person_add),
              label: const Text('Invite Teacher'),
              onPressed: _inviteTeacherDialog,
            ),
            ActionChip(
              avatar: const Icon(Icons.shopping_cart),
              label: const Text('Order Tests'),
              onPressed: () => context.push('/teacher/orders'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Teachers
        Text('Teachers in Institution', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if ((_teachers ?? []).isEmpty)
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('No teachers yet — invite one!', style: Theme.of(context).textTheme.bodyMedium)))
        else
          ...(_teachers ?? []).map((t) {
            final m = t as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(m['name'] as String? ?? ''),
                subtitle: Text('${m['email']} • ${m['students_count'] ?? 0} students'),
              ),
            );
          }),
      ],
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                final dio = ApiClient.create();
                await dio.post('/partner/teachers/invite', data: {'email': emailCtrl.text.trim()});
                if (mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invited ${emailCtrl.text.trim()}')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
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