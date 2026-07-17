import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../app/theme.dart';

/// Partner Commission page — Goal 9: institution dashboard for commission
/// earnings aggregated across all its teachers.
class PartnerCommissionPage extends ConsumerStatefulWidget {
  const PartnerCommissionPage({super.key});

  @override
  ConsumerState<PartnerCommissionPage> createState() =>
      _PartnerCommissionPageState();
}

class _PartnerCommissionPageState extends ConsumerState<PartnerCommissionPage> {
  Map<String, dynamic>? _data;
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
      final res = await dio.get('/partner/commission');
      setState(() {
        _data = res.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load commission';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data ?? {};
    final byType = (d['by_type'] as Map<String, dynamic>?) ?? {};
    final recent = (d['recent_entries'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: OseeTheme.primary),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _load,
                    style: FilledButton.styleFrom(
                      backgroundColor: OseeTheme.primary,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Commission',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: OseeTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Earnings aggregated across all your teachers',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: [
                    _statCard(
                      'Total Earned',
                      _formatRupiah((d['total_earned'] as num?) ?? 0),
                    ),
                    _statCard(
                      'This Month',
                      _formatRupiah((d['this_month'] as num?) ?? 0),
                    ),
                    _statCard(
                      'Pending',
                      _formatRupiah((d['pending_amount'] as num?) ?? 0),
                    ),
                    _statCard(
                      'Paid',
                      _formatRupiah((d['paid_amount'] as num?) ?? 0),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (byType.isNotEmpty) ...[
                  const Text(
                    'By Commission Type',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  ...byType.entries.map(
                    (e) => Card(
                      child: ListTile(
                        title: Text(e.key.replaceAll('_', ' ')),
                        trailing: Text(
                          _formatRupiah((e.value as num?) ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text(
                  'Recent Entries',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No commission entries yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...recent.map((e) {
                    final entry = e as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        title: Text(
                          entry['type'] as String? ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${entry['student_name'] ?? '—'} • ${_formatRupiah(entry['amount'] as num? ?? 0)} • ${entry['status'] ?? ''}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        trailing: Text(
                          _formatDate(entry['created_at'] as String?),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _statCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: OseeTheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRupiah(num amount) {
    return 'Rp ${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      return DateTime.parse(iso).toLocal().toString().substring(0, 10);
    } catch (_) {
      return '';
    }
  }
}
