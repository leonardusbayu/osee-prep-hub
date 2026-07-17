import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../student_theme.dart';
import '../widgets/student_widgets.dart';

/// Readiness gauge page — Modernized UI.
class ReadinessPage extends ConsumerStatefulWidget {
  const ReadinessPage({super.key});

  @override
  ConsumerState<ReadinessPage> createState() => _ReadinessPageState();
}

class _ReadinessPageState extends ConsumerState<ReadinessPage> {
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

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: StudentTheme.primary))
        : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: StudentTheme.cardLabel(StudentTheme.textSecondary)),
                    const SizedBox(height: StudentSpacing.lg),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _buildContent(isDesktop);
  }

  Widget _buildContent(bool isDesktop) {
    final d = _data ?? {};
    final pct = (d['readiness_pct'] as num?) ?? 0;
    final status = d['readiness_status'] as String? ?? 'preparing';
    final predicted = d['predicted_score'];
    final weeks = d['weeks_to_target'];
    final targetExam = d['target_exam'] as String? ?? '—';
    final targetScore = d['target_score'];
    final recommendations = (d['recommendations'] as List?) ?? [];

    final color = pct >= 80
        ? StudentTheme.successGreen
        : pct >= 60
        ? StudentTheme.warningOrange
        : StudentTheme.danger;
        
    final statusLabel = status == 'ready'
        ? 'READY'
        : status == 'almost_ready'
        ? 'ALMOST READY'
        : 'PREPARING';

    return ListView(
      padding: const EdgeInsets.all(StudentSpacing.xl),
      children: [
        StudentTopBar(
          name: 'Student',
          subtitle: 'Readiness',
          onMenuTap: isDesktop ? null : () => Scaffold.of(context).openDrawer(),
        ),
        const SizedBox(height: StudentSpacing.xxl),
        
        Container(
          padding: const EdgeInsets.all(StudentSpacing.xxl),
          decoration: BoxDecoration(
            color: StudentTheme.surface,
            borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
            boxShadow: StudentTheme.cardShadow,
            border: Border.all(color: StudentTheme.divider),
          ),
          child: Column(
            children: [
              Text(
                'Readiness Gauge',
                style: StudentTheme.sectionTitle(),
              ),
              const SizedBox(height: StudentSpacing.xl),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: pct / 100,
                      strokeWidth: 16,
                      color: color,
                      backgroundColor: StudentTheme.divider,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                          letterSpacing: 1.2,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: StudentSpacing.xxl),
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
        
        const SizedBox(height: StudentSpacing.xxl),
        const StudentSectionHeader(
          title: 'Recommendations',
          icon: Icons.lightbulb_outline_rounded,
        ),
        const SizedBox(height: StudentSpacing.lg),
        
        if (recommendations.isNotEmpty)
          DailyNoticePanel(
            items: recommendations.map((r) => NoticeItem(
              title: 'Recommendation',
              body: r.toString(),
              icon: Icons.tips_and_updates_rounded,
            )).toList(),
          ),
          
        if (pct >= 80) ...[
          const SizedBox(height: StudentSpacing.lg),
          Container(
            padding: const EdgeInsets.all(StudentSpacing.lg),
            decoration: BoxDecoration(
              color: StudentTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
              border: Border.all(color: StudentTheme.successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: StudentTheme.successGreen.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded, color: StudentTheme.successGreen, size: 28),
                ),
                const SizedBox(width: StudentSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You are ready!', style: StudentTheme.courseTitle()),
                      const SizedBox(height: 4),
                      Text('Book your official test at osee.co.id', style: StudentTheme.cardLabel()),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, color: StudentTheme.successGreen),
                  onPressed: () {
                    // Link to book test
                  },
                )
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _info(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: StudentTheme.cardLabel(),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: StudentTheme.cardValue().copyWith(fontSize: 18),
        ),
      ],
    );
  }
}
