import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../shared/widgets/ui_components.dart';

/// Teacher Earnings/Commission dashboard page — Task 12.1.
class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key});

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends State<EarningsPage> {
  Map<String, dynamic>? _stats;
  List<dynamic>? _payouts;
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
      final results = await Future.wait([
        dio.get('/teacher/commission/dashboard'),
        dio.get('/teacher/commission/payouts'),
      ]);
      setState(() {
        _stats = results[0].data as Map<String, dynamic>;
        _payouts = (results[1].data as Map)['payouts'] as List? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load earnings'; _isLoading = false; });
    }
  }

  Future<void> _requestPayout() async {
    final amountController = TextEditingController();
    final method = ValueNotifier('bank_transfer');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Payout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (IDR)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: method,
              builder: (ctx, val, _) => DropdownButtonFormField<String>(
                value: val,
                items: ['bank_transfer', 'gopay', 'ovo', 'dana']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => method.value = v ?? 'bank_transfer',
                decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request')),
        ],
      ),
    );

    if (result != true) return;
    final amount = int.tryParse(amountController.text);
    if (amount == null || amount <= 0) return;

    try {
      final dio = ApiClient.create();
      await dio.post('/teacher/commission/payout', data: {
        'amount': amount,
        'method': method.value,
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payout failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.payment),
        label: const Text('Request Payout'),
        onPressed: _requestPayout,
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _StatCard('Total Earned', 'Rp ${_stats?['total_earned'] ?? 0}', Colors.green),
                          _StatCard('This Month', 'Rp ${_stats?['this_month'] ?? 0}', Colors.blue),
                          _StatCard('Pending', 'Rp ${_stats?['pending_amount'] ?? 0}', Colors.orange),
                          _StatCard('Paid Out', 'Rp ${_stats?['paid_amount'] ?? 0}', Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('By Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (final entry in (_stats?['by_type'] as Map?)?.entries ?? <MapEntry<String, dynamic>>[])
                        ListTile(
                          leading: const Icon(Icons.category),
                          title: Text(entry.key),
                          trailing: Text('Rp ${entry.value}'),
                        ),
                      const SizedBox(height: 24),
                      const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      for (final entry in (_stats?['recent_entries'] as List?) ?? <dynamic>[])
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt),
                            title: Text('${(entry as Map)['type']} · ${(entry)['student_name'] ?? '—'}'),
                            subtitle: Text('Rp ${entry['amount']} · ${entry['status']}'),
                            trailing: Text((entry)['created_at'] as String? ?? ''),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text('Payout History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_payouts?.isEmpty ?? true)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No payouts yet', style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        )
                      else
                        for (final p in _payouts!)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.account_balance_wallet),
                              title: Text('Rp ${(p as Map)['amount']}'),
                              subtitle: Text('${p['method'] ?? '—'} · ${p['status']}'),
                              trailing: Text(p['requested_at'] as String? ?? ''),
                            ),
                          ),
                    ],
                  ),
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
            Text(value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}