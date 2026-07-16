import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../student_theme.dart';
import '../widgets/student_widgets.dart';

/// Student Progress page — Modernized UI.
class StudentProgressPage extends ConsumerStatefulWidget {
  const StudentProgressPage({super.key});

  @override
  ConsumerState<StudentProgressPage> createState() => _StudentProgressPageState();
}

class _StudentProgressPageState extends ConsumerState<StudentProgressPage> {
  Map<String, dynamic>? _progress;
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
      final r = await dio.get('/student/progress');
      setState(() {
        _progress = (r.data as Map)['progress'] as Map<String, dynamic>? ?? {};
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
    final p = _progress ?? {};
    final ibt = p['ibt_latest_score'];
    final itp = p['itp_latest_score'];
    final ielts = p['ielts_latest_band'];
    final toeic = p['toeic_latest_score'];
    final streak = p['edubot_streak_days'] ?? 0;
    final xp = p['edubot_xp'] ?? 0;
    final questions = p['edubot_questions_answered'] ?? 0;
    final accuracy = (p['edubot_accuracy_rate'] as num?) ?? 0;

    return ListView(
      padding: const EdgeInsets.all(StudentSpacing.xl),
      children: [
        StudentTopBar(
          name: 'Student', // Ideally fetched from provider/dashboard
          subtitle: 'Progress',
          onMenuTap: isDesktop ? null : () => Scaffold.of(context).openDrawer(),
        ),
        const SizedBox(height: StudentSpacing.xxl),
        
        const StudentSectionHeader(
          title: 'Exam Scores',
          icon: Icons.assignment_turned_in_rounded,
        ),
        const SizedBox(height: StudentSpacing.lg),
        
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 4 : 2,
          childAspectRatio: 1.4,
          crossAxisSpacing: StudentSpacing.gap,
          mainAxisSpacing: StudentSpacing.gap,
          children: [
            Row(children: [
              StudentStatCard(
                icon: Icons.language_rounded,
                label: 'TOEFL iBT',
                value: ibt?.toString() ?? '—',
                accentColor: StudentTheme.primary,
                surfaceColor: StudentTheme.primary.withValues(alpha: 0.12),
              ),
            ]),
            Row(children: [
              StudentStatCard(
                icon: Icons.assignment_rounded,
                label: 'TOEFL ITP',
                value: itp?.toString() ?? '—',
                accentColor: StudentTheme.successGreen,
                surfaceColor: StudentTheme.successGreen.withValues(alpha: 0.12),
              ),
            ]),
            Row(children: [
              StudentStatCard(
                icon: Icons.school_rounded,
                label: 'IELTS Band',
                value: ielts?.toString() ?? '—',
                accentColor: StudentTheme.successGreen,
                surfaceColor: StudentTheme.successGreen.withValues(alpha: 0.12),
              ),
            ]),
            Row(children: [
              StudentStatCard(
                icon: Icons.business_center_rounded,
                label: 'TOEIC',
                value: toeic?.toString() ?? '—',
                accentColor: StudentTheme.warningOrange,
                surfaceColor: StudentTheme.warningOrange.withValues(alpha: 0.12),
              ),
            ]),
          ],
        ),

        const SizedBox(height: StudentSpacing.xxl),
        const StudentSectionHeader(
          title: 'EduBot Tutor',
          icon: Icons.smart_toy_rounded,
        ),
        const SizedBox(height: StudentSpacing.lg),

        Container(
          padding: const EdgeInsets.all(StudentSpacing.xl),
          decoration: BoxDecoration(
            color: StudentTheme.surface,
            borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
            boxShadow: StudentTheme.cardShadow,
            border: Border.all(color: StudentTheme.divider),
          ),
          child: Column(
            children: [
              _InfoRow(label: 'Streak (days)', value: streak.toString()),
              const Divider(height: 24),
              _InfoRow(label: 'XP', value: xp.toString()),
              const Divider(height: 24),
              _InfoRow(label: 'Questions answered', value: questions.toString()),
              const Divider(height: 24),
              _InfoRow(label: 'Accuracy', value: '${accuracy.toStringAsFixed(1)}%'),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: StudentTheme.cardLabel()),
        Text(value, style: StudentTheme.cardValue().copyWith(fontSize: 18)),
      ],
    );
  }
}
