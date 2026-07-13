import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';

/// Readiness gauge page — Task 11.4.
class ReadinessPage extends StatefulWidget {
  const ReadinessPage({super.key});

  @override
  State<ReadinessPage> createState() => _ReadinessPageState();
}

class _ReadinessPageState extends State<ReadinessPage> {
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
      final r = await dio.get('/student/readiness');
      setState(() {
        _data = r.data as Map<String, dynamic>;
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
        title: const Text('Readiness'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : _buildContent(_data ?? {}),
    );
  }

  Widget _buildContent(Map<String, dynamic> d) {
    final pct = (d['readiness_pct'] as num?) ?? 0;
    final status = d['readiness_status'] as String? ?? 'preparing';
    final predicted = d['predicted_score'];
    final weeks = d['weeks_to_target'];
    final targetExam = d['target_exam'] as String? ?? '—';
    final targetScore = d['target_score'];
    final recommendations = (d['recommendations'] as List?) ?? [];

    final color = pct >= 80
        ? OseeTheme.success
        : pct >= 60
        ? OseeTheme.warning
        : OseeTheme.danger;
    final statusLabel = status == 'ready'
        ? 'READY'
        : status == 'almost_ready'
        ? 'ALMOST READY'
        : 'PREPARING';

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        const PageHeader(
          title: 'Readiness',
          subtitle:
              'Estimate whether your latest progress is close to your official test target.',
          icon: Icons.verified_rounded,
        ),
        const SizedBox(height: Spacing.lg),
        SurfaceCard(
          child: Padding(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Text(
                  'Readiness Gauge',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: Spacing.md),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: pct / 100,
                        strokeWidth: 14,
                        color: color,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '$pct%',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                        ),
                        Text(
                          statusLabel,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _info('Target', '$targetExam · ${targetScore ?? '—'}'),
                    if (predicted != null)
                      _info('Predicted', predicted.toString()),
                    if (weeks != null)
                      _info('Weeks to target', weeks.toString()),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        const SectionHeader(title: 'Recommendations'),
        for (final r in recommendations)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: SurfaceCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: OseeTheme.warning,
                ),
                title: Text(r.toString()),
              ),
            ),
          ),
        const SizedBox(height: Spacing.lg),
        if (pct >= 80)
          SurfaceCard(
            color: OseeTheme.success.withValues(alpha: 0.08),
            borderColor: OseeTheme.success.withValues(alpha: 0.2),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.verified_rounded,
                color: OseeTheme.success,
                size: 32,
              ),
              title: const Text('You are ready!'),
              subtitle: const Text('Book your official test at osee.co.id'),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                // Open osee.co.id — link via the book-test endpoint
              },
            ),
          ),
      ],
    );
  }

  Widget _info(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: OseeTheme.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: OseeTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
