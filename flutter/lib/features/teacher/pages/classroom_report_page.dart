import 'package:flutter/material.dart';

import '../../../core/api_client.dart';

/// Classroom report page with weakness heatmap — Task 9.3.
///
/// Loads classroom report (JSON) and visualizes the weakness heatmap:
/// a grid of students × exam sections, color-coded by score.
class ClassroomReportPage extends StatefulWidget {
  const ClassroomReportPage({super.key, required this.classroomId});
  final String classroomId;

  @override
  State<ClassroomReportPage> createState() => _ClassroomReportPageState();
}

class _ClassroomReportPageState extends State<ClassroomReportPage> {
  Map<String, dynamic>? _report;
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
      final r = await dio.get('/teacher/classrooms/${widget.classroomId}/report');
      setState(() { _report = r.data as Map<String, dynamic>; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_report?['classroom']?['name'] as String? ?? 'Classroom Report'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(_report ?? {}),
    );
  }

  Widget _buildContent(Map<String, dynamic> r) {
    final summary = (r['summary'] as Map<String, dynamic>?) ?? {};
    final students = (r['students'] as List?) ?? <dynamic>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary stats
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat('Total', summary['total_students']?.toString() ?? '0'),
                _stat('Active', summary['active_students']?.toString() ?? '0'),
                _stat('Avg', summary['avg_progress']?.toString() ?? '0'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Common weaknesses badges
        const Text('Common Weaknesses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: ((summary['common_weaknesses'] as List?) ?? <dynamic>[])
              .map((w) => Chip(
                    label: Text(w.toString()),
                    backgroundColor: Colors.red.shade100,
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),

        // Weakness heatmap
        const Text('Weakness Heatmap',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Color = score per exam. Red = low, Green = high. Blank = no data.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _Heatmap(students: students.cast<Map<String, dynamic>>()),
      ],
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.students});
  final List<Map<String, dynamic>> students;

  static const _exams = ['ibt', 'itp', 'ielts', 'toeic'];
  static const _examLabels = ['iBT', 'ITP', 'IELTS', 'TOEIC'];

  @override
  Widget build(BuildContext context) {
    if (students.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('No students enrolled.', style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 4,
        columns: [
          const DataColumn(label: Text('Student'), tooltip: 'Student name'),
          for (int i = 0; i < _exams.length; i++)
            DataColumn(label: Text(_examLabels[i]), tooltip: _exams[i]),
        ],
        rows: [
          for (final s in students)
            DataRow(
              cells: [
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      (s['name'] as String?) ?? '',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                for (int i = 0; i < _exams.length; i++)
                  DataCell(_heatCell(s, _exams[i])),
              ],
            ),
        ],
      ),
    );
  }

  Widget _heatCell(Map<String, dynamic> student, String exam) {
    final scores = (student['latest_scores'] as Map<String, dynamic>?) ?? {};
    final score = scores[exam];
    if (score == null) {
      return const SizedBox(
        width: 50,
        height: 28,
        child: Center(child: Text('—', style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }

    // Normalize score to 0-1 range for color
    // Different exams have different max: iBT 120, ITP 677, IELTS 9, TOEIC 990
    final maxByExam = {'ibt': 120.0, 'itp': 677.0, 'ielts': 9.0, 'toeic': 990.0};
    final max = maxByExam[exam] ?? 100.0;
    final ratio = ((score as num).toDouble() / max).clamp(0.0, 1.0);

    // Color: red (low) → yellow (mid) → green (high)
    final color = _scoreColor(ratio);

    return Container(
      width: 50,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        score.toString(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Returns a color from red (0) → yellow (0.5) → green (1).
  Color _scoreColor(double ratio) {
    if (ratio < 0.5) {
      // Red → Yellow
      final t = ratio / 0.5;
      final r = 0xE5;
      final g = (0x29 + (0xD6 - 0x29) * t).round();
      final b = 0x29;
      return Color.fromARGB(255, r, g, b);
    } else {
      // Yellow → Green
      final t = (ratio - 0.5) / 0.5;
      final r = (0xE5 - (0xE5 - 0x16) * t).round();
      final g = (0xD6 - (0xD6 - 0xA3) * t).round();
      final b = (0x29 + (0x4A - 0x29) * t).round();
      return Color.fromARGB(255, r, g, b);
    }
  }
}