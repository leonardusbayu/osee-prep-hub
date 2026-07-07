import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';
import '../../../core/mind_board_api.dart';

/// Teacher student progress view — magazine style.
///
/// Shows a classroom's progress summary: per-student accuracy, weak areas,
/// and answer history. Teacher can click through to individual student detail
/// and generate parent reports.
class StudentProgressPage extends ConsumerStatefulWidget {
  const StudentProgressPage({super.key, required this.classroomId});
  final String classroomId;

  @override
  ConsumerState<StudentProgressPage> createState() => _StudentProgressPageState();
}

class _StudentProgressPageState extends ConsumerState<StudentProgressPage> {
  late final MindBoardApi _api;
  List<Map<String, dynamic>> _progress = [];
  Map<String, dynamic>? _classroom;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _api = ref.read(mindBoardApiProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.getClassroomProgress(widget.classroomId);
      setState(() {
        _progress = (result['progress'] as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
    // Also fetch classroom info
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/teacher/classrooms/${widget.classroomId}');
      setState(() => _classroom = r.data as Map<String, dynamic>?);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseeTheme.paper,
      appBar: AppBar(
        backgroundColor: OseeTheme.paper,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: OseeTheme.ink, width: 2)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: OseeTheme.ink), onPressed: () => context.go('/teacher')),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('STUDENT PROGRESS', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 3, color: OseeTheme.ink)),
          const SizedBox(height: 2),
          Text(_classroom?['name'] as String? ?? 'Classroom', style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
        ]),
        actions: [IconButton(icon: const Icon(Icons.refresh, color: OseeTheme.ink), onPressed: _load, tooltip: 'Refresh')],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: OseeTheme.ink))
          : _progress.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.people_outline, size: 48, color: OseeTheme.cloud),
                  const SizedBox(height: 12),
                  Text('No student progress data yet.', style: TextStyle(fontFamily: 'Georgia', fontSize: 14, color: OseeTheme.ink.withValues(alpha: 0.5), fontStyle: FontStyle.italic)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _progress.length,
                  itemBuilder: (_, i) => _StudentProgressCard(
                    student: _progress[i],
                    onTap: () => _showStudentDetail(_progress[i]),
                  ),
                ),
    );
  }

  void _showStudentDetail(Map<String, dynamic> student) {
    final studentId = student['student_id'] as String;
    final studentName = student['student_name'] as String? ?? 'Student';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OseeTheme.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(2))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, sc) => _StudentDetailSheet(
          studentId: studentId,
          studentName: studentName,
          progress: student,
          classroomId: widget.classroomId,
          api: _api,
        ),
      ),
    );
  }
}

class _StudentProgressCard extends StatelessWidget {
  const _StudentProgressCard({required this.student, required this.onTap});
  final Map<String, dynamic> student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = student['student_name'] as String? ?? 'Unknown';
    final totalAnswered = (student['total_answered'] as num?)?.toInt() ?? 0;
    final totalCorrect = (student['total_correct'] as num?)?.toInt() ?? 0;
    final accuracy = (student['accuracy'] as num?)?.toDouble() ?? 0;
    final accuracyPct = (accuracy * 100).round();
    final weakParts = (student['weak_parts'] as List?)?.cast<String>() ?? [];
    final accuracyColor = accuracy > 0.8 ? OseeTheme.sage : accuracy > 0.6 ? OseeTheme.gold : OseeTheme.accent;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: accuracyColor, width: 3), top: BorderSide(color: OseeTheme.cloud), bottom: BorderSide(color: OseeTheme.cloud), right: BorderSide(color: OseeTheme.cloud)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.w700, color: OseeTheme.ink))),
                Text('$accuracyPct%', style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700, color: accuracyColor)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('$totalCorrect / $totalAnswered answered', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: OseeTheme.ink.withValues(alpha: 0.6))),
                const Spacer(),
                // Mini accuracy bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: Container(width: 60, height: 4, color: OseeTheme.cloud, child: Align(alignment: Alignment.centerLeft, child: Container(width: 60 * accuracy, height: 4, color: accuracyColor))),
                ),
              ],
            ),
            if (weakParts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 2, children: weakParts.take(3).map((p) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: OseeTheme.accent.withValues(alpha: 0.08), border: Border.all(color: OseeTheme.accent.withValues(alpha: 0.3))), child: Text('Part $p', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, color: OseeTheme.accent)))).toList()),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudentDetailSheet extends StatefulWidget {
  const _StudentDetailSheet({required this.studentId, required this.studentName, required this.progress, required this.classroomId, required this.api});
  final String studentId;
  final String studentName;
  final Map<String, dynamic> progress;
  final String classroomId;
  final MindBoardApi api;

  @override
  State<_StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends State<_StudentDetailSheet> {
  Map<String, dynamic>? _answers;
  bool _isLoadingAnswers = true;
  Map<String, dynamic>? _report;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadAnswers();
  }

  Future<void> _loadAnswers() async {
    try {
      final result = await widget.api.getStudentAnswers(widget.studentId);
      setState(() {
        _answers = result;
        _isLoadingAnswers = false;
      });
    } catch (_) {
      setState(() => _isLoadingAnswers = false);
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);
    try {
      final report = await widget.api.generateReport(
        studentId: widget.studentId,
        classroomId: widget.classroomId,
        reportType: 'progress',
      );
      setState(() {
        _report = report;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report failed: $e'), backgroundColor: OseeTheme.accent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = (widget.progress['accuracy'] as num?)?.toDouble() ?? 0;
    final totalAnswered = (widget.progress['total_answered'] as num?)?.toInt() ?? 0;
    final totalCorrect = (widget.progress['total_correct'] as num?)?.toInt() ?? 0;
    final byPart = (widget.progress['by_part'] as Map<String, dynamic>?) ?? {};
    final weakParts = (widget.progress['weak_parts'] as List?)?.cast<String>() ?? [];
    final accuracyColor = accuracy > 0.8 ? OseeTheme.sage : accuracy > 0.6 ? OseeTheme.gold : OseeTheme.accent;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Row(children: [
          Expanded(child: Text(widget.studentName, style: const TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.w700, color: OseeTheme.ink))),
          Text('${(accuracy * 100).round()}%', style: TextStyle(fontFamily: 'Georgia', fontSize: 28, fontWeight: FontWeight.w700, color: accuracyColor)),
        ]),
        Container(height: 1, color: OseeTheme.gold, margin: const EdgeInsets.only(top: 8, bottom: 16)),

        // Summary stats
        Row(children: [
          _StatBox(label: 'ANSWERED', value: '$totalAnswered', color: OseeTheme.ink),
          const SizedBox(width: 8),
          _StatBox(label: 'CORRECT', value: '$totalCorrect', color: OseeTheme.sage),
          const SizedBox(width: 8),
          _StatBox(label: 'ACCURACY', value: '${(accuracy * 100).round()}%', color: accuracyColor),
        ]),

        // By part breakdown
        if (byPart.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('BY PART'),
          const SizedBox(height: 8),
          ...byPart.entries.map((e) {
            final part = e.key;
            final stats = e.value as Map<String, dynamic>;
            final correct = (stats['correct'] as num?)?.toInt() ?? 0;
            final total = (stats['total'] as num?)?.toInt() ?? 0;
            final partAccuracy = total > 0 ? correct / total : 0.0;
            final partColor = partAccuracy > 0.8 ? OseeTheme.sage : partAccuracy > 0.6 ? OseeTheme.gold : OseeTheme.accent;
            return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
              SizedBox(width: 60, child: Text('Part $part', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(1), child: Container(height: 6, color: OseeTheme.cloud, child: Align(alignment: Alignment.centerLeft, child: Container(width: 200 * partAccuracy, height: 6, color: partColor))))),
              const SizedBox(width: 8),
              SizedBox(width: 50, child: Text('$correct/$total', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: OseeTheme.ink), textAlign: TextAlign.right)),
            ]));
          }),
        ],

        // Weak areas
        if (weakParts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: OseeTheme.accent.withValues(alpha: 0.06), border: Border(left: BorderSide(color: OseeTheme.accent, width: 2))), child: Row(children: [
            const Icon(Icons.warning_amber, size: 16, color: OseeTheme.accent),
            const SizedBox(width: 8),
            Expanded(child: Text('Weak areas: ${weakParts.map((p) => 'Part $p').join(', ')}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, fontStyle: FontStyle.italic))),
          ])),
        ],

        // Answer history
        if (_answers != null) ...[
          const SizedBox(height: 24),
          const _SectionLabel('RECENT ANSWERS'),
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final answerList = (_answers!['answers'] as List?) ?? [];
            if (answerList.isEmpty) {
              return Text('No answer history yet.', style: TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink.withValues(alpha: 0.5), fontStyle: FontStyle.italic));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: answerList.take(10).cast<Map<String, dynamic>>().map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Icon(a['is_correct'] == true ? Icons.check_circle : Icons.cancel, size: 14, color: a['is_correct'] == true ? OseeTheme.sage : OseeTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a['student_answer'] as String? ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink))),
                  Text(a['part'] as String? ?? '', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: OseeTheme.stone)),
                ]),
              )).toList(),
            );
          }),
        ],

        // Parent report
        const SizedBox(height: 24),
        const _SectionLabel('PARENT REPORT'),
        const SizedBox(height: 8),
        if (_report == null)
          FilledButton.icon(
            onPressed: _isGenerating ? null : _generateReport,
            icon: _isGenerating ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white)) : const Icon(Icons.assignment_outlined, size: 16),
            label: Text(_isGenerating ? 'GENERATING…' : 'GENERATE REPORT', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            style: FilledButton.styleFrom(backgroundColor: OseeTheme.ink, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), padding: const EdgeInsets.symmetric(vertical: 12)),
          )
        else
          _ReportPreview(report: _report!, api: widget.api),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: color, width: 2), bottom: BorderSide(color: OseeTheme.cloud), left: BorderSide(color: OseeTheme.cloud), right: BorderSide(color: OseeTheme.cloud))), child: Column(children: [
      Text(label, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.stone)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: color)),
    ])));
  }
}

class _ReportPreview extends StatefulWidget {
  const _ReportPreview({required this.report, required this.api});
  final Map<String, dynamic> report;
  final MindBoardApi api;

  @override
  State<_ReportPreview> createState() => _ReportPreviewState();
}

class _ReportPreviewState extends State<_ReportPreview> {
  final _emailCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final content = widget.report['content'] as Map<String, dynamic>?;
    final student = content?['student'] as Map<String, dynamic>?;
    final stats = content?['stats'] as Map<String, dynamic>?;
    final aiSummary = content?['ai_summary'] as String? ?? '';
    final recommendations = (content?['recommendations'] as List?)?.cast<String>() ?? [];
    final weakAreas = (content?['weak_areas'] as List?)?.cast<String>() ?? [];
    final strongAreas = (content?['strong_areas'] as List?)?.cast<String>() ?? [];
    final status = (widget.report['status'] as String?) ?? 'draft';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status badge
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: status == 'sent' ? OseeTheme.sage : OseeTheme.gold), child: Text(status.toUpperCase(), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white))),
          const Spacer(),
          Text(widget.report['created_at'] as String? ?? '', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: OseeTheme.stone)),
        ]),
        const SizedBox(height: 12),

        // AI Summary
        if (aiSummary.isNotEmpty) ...[
          const _SectionLabel('AI SUMMARY (BAHASA INDONESIA)'),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: OseeTheme.parchment.withValues(alpha: 0.3), border: Border(left: BorderSide(color: OseeTheme.gold, width: 2))), child: Text(aiSummary, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, height: 1.6))),
        ],

        // Recommendations
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionLabel('RECOMMENDATIONS'),
          const SizedBox(height: 4),
          ...recommendations.map((r) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: OseeTheme.accent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(r, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, height: 1.5))),
          ]))),
        ],

        // Weak/Strong areas
        if (weakAreas.isNotEmpty || strongAreas.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (weakAreas.isNotEmpty) Text('⚠ Weak: ${weakAreas.join(', ')}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.accent)),
          if (strongAreas.isNotEmpty) Text('✓ Strong: ${strongAreas.join(', ')}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.sage)),
        ],

        // Send to parent
        const SizedBox(height: 16),
        const _SectionLabel('SEND TO PARENT'),
        const SizedBox(height: 8),
        if (status != 'sent') ...[
          TextField(controller: _emailCtl, decoration: InputDecoration(labelText: 'Parent email', labelStyle: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: OseeTheme.stone), border: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.cloud)), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.ink, width: 2)), isDense: true), style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink)),
          const SizedBox(height: 8),
          TextField(controller: _nameCtl, decoration: InputDecoration(labelText: 'Parent name (optional)', labelStyle: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: OseeTheme.stone), border: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.cloud)), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.ink, width: 2)), isDense: true), style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink)),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _isSending ? null : () async {
              if (_emailCtl.text.trim().isEmpty) return;
              setState(() => _isSending = true);
              try {
                await widget.api.sendReport(widget.report['id'] as String, parentEmail: _emailCtl.text.trim(), parentName: _nameCtl.text.trim().isEmpty ? null : _nameCtl.text.trim());
                setState(() => _isSending = false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent!'), backgroundColor: OseeTheme.sage));
              } catch (e) {
                setState(() => _isSending = false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e'), backgroundColor: OseeTheme.accent));
              }
            },
            icon: _isSending ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white)) : const Icon(Icons.send, size: 14),
            label: const Text('SEND REPORT', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            style: FilledButton.styleFrom(backgroundColor: OseeTheme.sage, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ] else
          Text('Sent to ${widget.report['parent_email'] ?? 'parent'}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.sage, fontStyle: FontStyle.italic)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 1, color: OseeTheme.ink),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.ink)),
    ]);
  }
}