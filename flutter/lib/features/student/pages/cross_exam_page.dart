import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../student_theme.dart';
import '../widgets/student_widgets.dart';

/// Cross-exam score map page — Modernized UI.
class CrossExamPage extends ConsumerStatefulWidget {
  const CrossExamPage({super.key});

  @override
  ConsumerState<CrossExamPage> createState() => _CrossExamPageState();
}

class _CrossExamPageState extends ConsumerState<CrossExamPage> {
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
      final r = await dio.get('/student/cross-exam-map');
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
    final equivalents = (d['equivalents'] as Map<String, dynamic>?) ?? {};
    final sourceScores = (d['source_scores'] as Map<String, dynamic>?) ?? {};

    final exams = ['TOEFL_IBT', 'TOEFL_ITP', 'IELTS', 'TOEIC'];

    return ListView(
      padding: const EdgeInsets.all(StudentSpacing.xl),
      children: [
        StudentTopBar(
          name: 'Student',
          subtitle: 'Cross-Exam Map',
          onMenuTap: isDesktop ? null : () => Scaffold.of(context).openDrawer(),
        ),
        const SizedBox(height: StudentSpacing.xxl),
        
        Container(
          padding: const EdgeInsets.all(StudentSpacing.xl),
          decoration: BoxDecoration(
            color: StudentTheme.surface,
            borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
            boxShadow: StudentTheme.cardShadow,
            border: Border.all(color: StudentTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: StudentTheme.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.assignment_ind_rounded, color: StudentTheme.primary),
                  ),
                  const SizedBox(width: StudentSpacing.md),
                  Text(
                    'Your Latest Scores',
                    style: StudentTheme.sectionTitle(),
                  ),
                ],
              ),
              const SizedBox(height: StudentSpacing.xl),
              for (int i = 0; i < exams.length; i++) ...[
                _row(
                  exams[i].replaceAll('_', ' '),
                  sourceScores[exams[i].toLowerCase()]?.toString() ?? '—',
                ),
                if (i < exams.length - 1)
                  const Divider(height: 24),
              ],
            ],
          ),
        ),
        const SizedBox(height: StudentSpacing.xxl),
        
        const StudentSectionHeader(
          title: 'Equivalency Matrix',
          icon: Icons.grid_on_rounded,
        ),
        const SizedBox(height: StudentSpacing.lg),
        
        Container(
          padding: const EdgeInsets.all(StudentSpacing.lg),
          decoration: BoxDecoration(
            color: StudentTheme.surface,
            borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
            boxShadow: StudentTheme.cardShadow,
            border: Border.all(color: StudentTheme.divider),
          ),
          child: _EquivalencyTable(equivalents: equivalents, exams: exams),
        ),
        const SizedBox(height: StudentSpacing.xl),
        
        Container(
          padding: const EdgeInsets.all(StudentSpacing.md),
          decoration: BoxDecoration(
            color: StudentTheme.warningOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: StudentTheme.warningOrange.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: StudentTheme.warningOrange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Note: Scores are approximate based on ETS concordance tables. Use as a guide, not as a guarantee.',
                  style: StudentTheme.cardLabel(StudentTheme.warningOrange),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: StudentTheme.cardLabel()),
        Text(value, style: StudentTheme.cardValue().copyWith(fontSize: 18)),
      ],
    );
  }
}

class _EquivalencyTable extends StatelessWidget {
  const _EquivalencyTable({required this.equivalents, required this.exams});
  final Map<String, dynamic> equivalents;
  final List<String> exams;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Table(
        border: TableBorder.all(color: StudentTheme.divider, borderRadius: BorderRadius.circular(8)),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: StudentTheme.background),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Source',
                  style: StudentTheme.cardLabel().copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              for (final e in exams)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    e.replaceAll('_', ' '),
                    style: StudentTheme.cardLabel().copyWith(fontWeight: FontWeight.bold, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          for (final sourceExam in exams)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    sourceExam.replaceAll('_', ' '),
                    style: StudentTheme.noticeTitle().copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                for (final targetExam in exams)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _val(equivalents, targetExam, sourceExam),
                      style: StudentTheme.cardValue().copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _val(Map<String, dynamic> eq, String target, String source) {
    final row = eq[target] as Map<String, dynamic>?;
    if (row == null) return '—';
    final v = row[source];
    if (v == null) return '—';
    return v.toString();
  }
}
