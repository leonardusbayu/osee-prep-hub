import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';

/// Student Progress page — Task 11.3.
class StudentProgressPage extends StatefulWidget {
  const StudentProgressPage({super.key});

  @override
  State<StudentProgressPage> createState() => _StudentProgressPageState();
}

class _StudentProgressPageState extends State<StudentProgressPage> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : _buildContent(_progress ?? {}),
    );
  }

  Widget _buildContent(Map<String, dynamic> p) {
    final ibt = p['ibt_latest_score'];
    final itp = p['itp_latest_score'];
    final ielts = p['ielts_latest_band'];
    final toeic = p['toeic_latest_score'];
    final streak = p['edubot_streak_days'] ?? 0;
    final xp = p['edubot_xp'] ?? 0;
    final questions = p['edubot_questions_answered'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        const PageHeader(
          title: 'Progress',
          subtitle:
              'Review exam scores and EduBot practice signals across the learning journey.',
          icon: Icons.trending_up_rounded,
        ),
        const SizedBox(height: Spacing.lg),
        const SectionHeader(title: 'Exam Scores'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            StatCard(
              icon: Icons.language_rounded,
              label: 'TOEFL iBT',
              value: ibt?.toString() ?? '—',
              color: OseeTheme.primary,
            ),
            StatCard(
              icon: Icons.assignment_rounded,
              label: 'TOEFL ITP',
              value: itp?.toString() ?? '—',
              color: OseeTheme.success,
            ),
            StatCard(
              icon: Icons.school_rounded,
              label: 'IELTS Band',
              value: ielts?.toString() ?? '—',
              color: OseeTheme.accent,
            ),
            StatCard(
              icon: Icons.business_center_rounded,
              label: 'TOEIC',
              value: toeic?.toString() ?? '—',
              color: OseeTheme.warning,
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        const SectionHeader(title: 'EduBot Tutor'),
        SurfaceCard(
          child: Padding(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                InfoRow(label: 'Streak (days)', value: streak.toString()),
                InfoRow(label: 'XP', value: xp.toString()),
                InfoRow(
                  label: 'Questions answered',
                  value: questions.toString(),
                ),
                InfoRow(
                  label: 'Accuracy',
                  value:
                      '${((p['edubot_accuracy_rate'] as num?) ?? 0).toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
