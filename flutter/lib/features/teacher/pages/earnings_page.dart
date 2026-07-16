import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';
import '../../../core/responsive.dart';

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
    setState(() {
      _isLoading = true;
      _error = null;
    });
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
      setState(() {
        _error = 'Failed to load earnings';
        _isLoading = false;
      });
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
              decoration: const InputDecoration(labelText: 'Amount (IDR)'),
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
                decoration: const InputDecoration(labelText: 'Method'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Request'),
          ),
        ],
      ),
    );

    if (result != true) return;
    final amount = int.tryParse(amountController.text);
    if (amount == null || amount <= 0) return;

    try {
      final dio = ApiClient.create();
      await dio.post(
        '/teacher/commission/payout',
        data: {'amount': amount, 'method': method.value},
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Payout failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingState()
        : _error != null
        ? ErrorState(message: _error!, onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(Spacing.md),
              children: [
                const PageHeader(
                  title: 'Earnings',
                  subtitle:
                      'Track commission, pending balance, payout requests, and recent student-driven revenue.',
                  icon: Icons.payments_rounded,
                ),
                const SizedBox(height: Spacing.lg),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: Responsive.statGridColumns(context),
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      StatCard(
                        icon: Icons.savings_rounded,
                        label: 'Total Earned',
                        value: 'Rp ${_stats?['total_earned'] ?? 0}',
                        color: OseeTheme.success,
                      ),
                      StatCard(
                        icon: Icons.calendar_month_rounded,
                        label: 'This Month',
                        value: 'Rp ${_stats?['this_month'] ?? 0}',
                        color: OseeTheme.primary,
                      ),
                      StatCard(
                        icon: Icons.hourglass_top_rounded,
                        label: 'Pending',
                        value: 'Rp ${_stats?['pending_amount'] ?? 0}',
                        color: OseeTheme.warning,
                      ),
                      StatCard(
                        icon: Icons.verified_rounded,
                        label: 'Paid Out',
                        value: 'Rp ${_stats?['paid_amount'] ?? 0}',
                        color: OseeTheme.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.lg),
                  const SectionHeader(title: 'By Type'),
                  for (final entry
                      in (_stats?['by_type'] as Map?)?.entries ??
                          <MapEntry<String, dynamic>>[])
                    SurfaceCard(
                      child: InfoRow(
                        label: entry.key.toString().replaceAll('_', ' '),
                        value: 'Rp ${entry.value}',
                      ),
                    ),
                  const SizedBox(height: Spacing.lg),
                  const SectionHeader(title: 'Recent Activity'),
                  for (final entry
                      in (_stats?['recent_entries'] as List?) ?? <dynamic>[])
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: SurfaceCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.receipt_long_rounded,
                            color: OseeTheme.primary,
                          ),
                          title: Text(
                            '${(entry as Map)['type']} · ${(entry)['student_name'] ?? '—'}',
                          ),
                          subtitle: Text(
                            'Rp ${entry['amount']} · ${entry['status']}',
                          ),
                          trailing: Text(
                            (entry)['created_at'] as String? ?? '',
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: Spacing.lg),
                  const SectionHeader(title: 'Payout History'),
                  if (_payouts?.isEmpty ?? true)
                    const SurfaceCard(child: Text('No payouts yet'))
                  else
                    for (final p in _payouts!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.sm),
                        child: SurfaceCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: OseeTheme.success,
                            ),
                            title: Text('Rp ${(p as Map)['amount']}'),
                            subtitle: Text(
                              '${p['method'] ?? '—'} · ${p['status']}',
                            ),
                            trailing: Text(p['requested_at'] as String? ?? ''),
                          ),
                        ),
                      ),
                const SizedBox(height: Spacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _requestPayout,
                    icon: const Icon(Icons.payment),
                    label: const Text('Request Payout'),
                  ),
                ),
              ],
            ),
        );
  }
}
