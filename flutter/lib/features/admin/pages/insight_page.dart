import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:osee_prep_hub/design/tokens.dart';
import 'package:osee_prep_hub/design/components.dart';

/// Institution analytics page — T13 (Wave 2).
///
/// Magazine-styled data viz: cohort heatmap, teacher effectiveness,
/// institution stats. Mock data for skeleton; real impl fetches from
/// /api/insight/*.
class InsightPage extends ConsumerWidget {
  const InsightPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: fetch from /api/insight/stats + cohort-heatmap + teacher-effectiveness.
    final stats = _MockStats();
    final heatmap = _MockHeatmap();
    final teachers = _MockTeachers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insight', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
        backgroundColor: MagazineColors.paperCream,
        elevation: 0,
      ),
      backgroundColor: MagazineColors.paperCream,
      body: ListView(
        padding: const EdgeInsets.all(MagazineSpacing.base),
        children: [
          const MagazineMasthead(
            kicker: 'OSEE INSIGHT',
            title: 'How the institution is doing',
            subtitle: 'Cohort heatmaps, teacher effectiveness, readiness distribution.',
            date: 'Refreshed hourly',
          ),
          const SizedBox(height: MagazineSpacing.lg),

          // Stats row
          const MagazineSectionRule(label: 'At a glance'),
          const SizedBox(height: MagazineSpacing.md),
          Row(
            children: [
              Expanded(child: MagazineStat(value: stats.totalStudents.toString(), label: 'STUDENTS')),
              const SizedBox(width: MagazineSpacing.base),
              Expanded(child: MagazineStat(value: stats.totalTeachers.toString(), label: 'TEACHERS')),
            ],
          ),
          const SizedBox(height: MagazineSpacing.base),
          Row(
            children: [
              Expanded(child: MagazineStat(value: '${stats.avgReadinessPct}%', label: 'AVG READINESS')),
              const SizedBox(width: MagazineSpacing.base),
              Expanded(child: MagazineStat(value: stats.readyCount.toString(), label: 'TEST-READY')),
            ],
          ),
          const SizedBox(height: MagazineSpacing.lg),

          // Cohort heatmap
          const MagazineSectionRule(label: 'Cohort heatmap (12-week completion %)'),
          const SizedBox(height: MagazineSpacing.md),
          _HeatmapTable(rows: heatmap),
          const SizedBox(height: MagazineSpacing.lg),

          // Teacher effectiveness
          const MagazineSectionRule(label: 'Teacher effectiveness'),
          const SizedBox(height: MagazineSpacing.md),
          for (final t in teachers) ...[
            _TeacherRow(teacher: t),
            const SizedBox(height: MagazineSpacing.sm),
          ],
          const SizedBox(height: MagazineSpacing.xxl),
        ],
      ),
    );
  }
}

class _MockStats {
  final int totalStudents = 247;
  final int totalTeachers = 18;
  final int totalClassrooms = 34;
  final double avgReadinessPct = 62.3;
  final int readyCount = 41;
  final int almostReadyCount = 87;
  final int preparingCount = 119;
}

class _HeatmapRow {
  final String name;
  final List<int> weeks;
  _HeatmapRow(this.name, this.weeks);
}

List<_HeatmapRow> _MockHeatmap() => [
  _HeatmapRow('Andi W.', [100, 95, 90, 85, 80, 78, 75, 70, 65, 60, 55, 50]),
  _HeatmapRow('Budi S.', [80, 78, 75, 70, 65, 60, 55, 50, 45, 40, 35, 30]),
  _HeatmapRow('Citra L.', [60, 62, 65, 70, 72, 75, 78, 80, 82, 85, 88, 90]),
  _HeatmapRow('Dewi K.', [40, 45, 50, 55, 60, 65, 70, 72, 75, 78, 80, 82]),
  _HeatmapRow('Eko P.', [20, 25, 30, 35, 40, 45, 50, 55, 58, 60, 62, 65]),
];

class _MockTeacher {
  final String name;
  final int students;
  final double avgImprovement;
  final int completedSyllabi;
  _MockTeacher(this.name, this.students, this.avgImprovement, this.completedSyllabi);
}

List<_MockTeacher> _MockTeachers() => [
  _MockTeacher('Ibu Sari', 28, 0.7, 4),
  _MockTeacher('Pak Andi', 35, 0.5, 6),
  _MockTeacher('Ibu Rina', 19, 0.8, 3),
  _MockTeacher('Pak Budi', 22, 0.6, 5),
];

class _HeatmapTable extends StatelessWidget {
  const _HeatmapTable({required this.rows});
  final List<_HeatmapRow> rows;

  Color _colorForPct(int pct) {
    if (pct >= 80) return MagazineColors.successGreen.withValues(alpha: 0.9);
    if (pct >= 60) return MagazineColors.mastheadGold.withValues(alpha: 0.8);
    if (pct >= 40) return MagazineColors.warningAmber.withValues(alpha: 0.5);
    return MagazineColors.surfaceMuted;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 36,
        columnSpacing: 4,
        columns: [
          const DataColumn(label: Text('Student', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          for (var i = 1; i <= 12; i++) DataColumn(label: Text('W$i', style: const TextStyle(fontSize: 11))),
        ],
        rows: rows.map((row) => DataRow(cells: [
          DataCell(Text(row.name, style: const TextStyle(fontSize: 12))),
          for (final pct in row.weeks)
            DataCell(Container(
              width: 32,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _colorForPct(pct)),
              child: Text('$pct', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            )),
        ])).toList(),
      ),
    );
  }
}

class _TeacherRow extends StatelessWidget {
  const _TeacherRow({required this.teacher});
  final _MockTeacher teacher;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MagazineSpacing.base),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: MagazineColors.mastheadGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teacher.name, style: magazineTitle()),
                Text('${teacher.students} students · ${teacher.completedSyllabi} syllabi completed',
                    style: magazineCaption()),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('+${teacher.avgImprovement}', style: const TextStyle(
                  fontSize: 28, fontFamily: 'Georgia', fontWeight: FontWeight.w700,
                  color: MagazineColors.successGreen,
                )),
                const Text('AVG BAND GAIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: MagazineColors.mastheadGold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}