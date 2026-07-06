import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';

/// Syllabus assignment panel — teacher assigns a syllabus to a classroom
/// (all students) or to individual students for personalized learning.
///
/// Shown as a dialog from the syllabus builder.
class SyllabusAssignPage extends ConsumerStatefulWidget {
  const SyllabusAssignPage({super.key, required this.syllabusId, required this.syllabusName});
  final String syllabusId;
  final String syllabusName;

  @override
  ConsumerState<SyllabusAssignPage> createState() => _SyllabusAssignPageState();
}

class _SyllabusAssignPageState extends ConsumerState<SyllabusAssignPage> {
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
      final r = await dio.get('/teacher/syllabi/${widget.syllabusId}/assignments');
      setState(() {
        _data = r.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load assignments';
        _isLoading = false;
      });
    }
  }

  Future<void> _assignToClassroom(String classroomId, String classroomName) async {
    try {
      final dio = ApiClient.create();
      await dio.post('/teacher/syllabi/${widget.syllabusId}/assign/classroom', data: {'classroom_id': classroomId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Linked to $classroomName — all enrolled students can see it'), backgroundColor: OseeTheme.sage),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assign failed: $e'), backgroundColor: OseeTheme.accent));
    }
  }

  Future<void> _assignToStudent(String studentId, String studentName) async {
    try {
      final dio = ApiClient.create();
      await dio.post('/teacher/syllabi/${widget.syllabusId}/assign/student', data: {'student_id': studentId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assigned to $studentName'), backgroundColor: OseeTheme.sage),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assign failed: $e'), backgroundColor: OseeTheme.accent));
    }
  }

  Future<void> _unassignStudent(String studentId, String studentName) async {
    try {
      final dio = ApiClient.create();
      await dio.delete('/teacher/syllabi/${widget.syllabusId}/assign/student/$studentId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unassigned from $studentName')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: OseeTheme.accent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseeTheme.paper,
      appBar: AppBar(
        backgroundColor: OseeTheme.paper,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ASSIGN SYLLABUS', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3, color: OseeTheme.stone)),
            Text(widget.syllabusName, style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: OseeTheme.ink), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: OseeTheme.ink))
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_error!, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, color: OseeTheme.ink)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ]))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final data = _data ?? {};
    final classroomId = data['classroom_id'] as String?;
    final classroomName = data['classroom_name'] as String?;
    final classroomStudents = (data['classroom_students'] as List? ?? const []) as List;
    final individual = (data['individual_assignments'] as List? ?? const []) as List;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ---------- Classroom assignment ----------
        const _SectionLabel('CLASSROOM'),
        const SizedBox(height: 10),
        if (classroomId != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0x226B8E7F),
              border: Border(left: BorderSide(color: OseeTheme.sage, width: 3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.class_, color: OseeTheme.sage),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(classroomName ?? '—', style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
                      Text('${classroomStudents.length} enrolled students see this syllabus', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: OseeTheme.stone)),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: OseeTheme.sage),
              ],
            ),
          )
        else
          _ClassroomPicker(onPick: (id, name) => _assignToClassroom(id, name)),
        const SizedBox(height: 24),

        // ---------- Individual assignments ----------
        const _SectionLabel('INDIVIDUAL STUDENTS'),
        const SizedBox(height: 4),
        Text(
          'Assign this syllabus to specific students for personalized learning.',
          style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.stone),
        ),
        const SizedBox(height: 10),
        if (individual.isNotEmpty) ...[
          for (final a in individual)
            _StudentAssignmentRow(
              name: (a as Map<String, dynamic>)['student_name'] as String? ?? '—',
              email: a['student_email'] as String? ?? '',
              onUnassign: () => _unassignStudent(a['student_id'] as String, a['student_name'] as String? ?? 'student'),
            ),
          const SizedBox(height: 12),
        ],
        _StudentPicker(
          classroomStudents: classroomStudents,
          alreadyAssignedIds: individual.map((a) => (a as Map<String, dynamic>)['student_id'] as String).toSet(),
          onPick: (id, name) => _assignToStudent(id, name),
        ),
        const SizedBox(height: 24),

        // ---------- Classroom students list ----------
        if (classroomId != null && classroomStudents.isNotEmpty) ...[
          const _SectionLabel('STUDENTS IN CLASSROOM'),
          const SizedBox(height: 10),
          for (final s in classroomStudents)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: OseeTheme.stone),
                  const SizedBox(width: 8),
                  Expanded(child: Text((s as Map<String, dynamic>)['name'] as String? ?? '—', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink))),
                  Text(s['email'] as String? ?? '', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: OseeTheme.stone)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 1, color: OseeTheme.ink),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.ink)),
      ],
    );
  }
}

class _ClassroomPicker extends StatefulWidget {
  const _ClassroomPicker({required this.onPick});
  final void Function(String id, String name) onPick;
  @override
  State<_ClassroomPicker> createState() => _ClassroomPickerState();
}

class _ClassroomPickerState extends State<_ClassroomPicker> {
  List<dynamic>? _classrooms;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/teacher/classrooms');
      setState(() {
        _classrooms = r.data['classrooms'] as List?;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 1.5));
    if (_classrooms == null || _classrooms!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: OseeTheme.cloud)),
        child: Text(
          'No classrooms yet. Create one from your dashboard first.',
          style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 12, color: OseeTheme.stone),
        ),
      );
    }
    return Column(
      children: [
        for (final c in _classrooms!)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => widget.onPick((c as Map<String, dynamic>)['id'] as String, c['name'] as String),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(left: BorderSide(color: OseeTheme.gold, width: 3), bottom: BorderSide(color: OseeTheme.cloud)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_link, size: 16, color: OseeTheme.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['name'] as String, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
                          Text('Tap to link', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: OseeTheme.stone)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: OseeTheme.stone),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StudentPicker extends StatefulWidget {
  const _StudentPicker({required this.classroomStudents, required this.alreadyAssignedIds, required this.onPick});
  final List classroomStudents;
  final Set<String> alreadyAssignedIds;
  final void Function(String id, String name) onPick;

  @override
  State<_StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<_StudentPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final available = widget.classroomStudents.where((s) {
      final id = (s as Map<String, dynamic>)['id'] as String;
      if (widget.alreadyAssignedIds.contains(id)) return false;
      if (_query.isEmpty) return true;
      final name = (s['name'] as String? ?? '').toLowerCase();
      final email = (s['email'] as String? ?? '').toLowerCase();
      return name.contains(_query.toLowerCase()) || email.contains(_query.toLowerCase());
    }).toList();

    if (widget.classroomStudents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: OseeTheme.cloud)),
        child: Text(
          'No students enrolled in any classroom yet. Link this syllabus to a classroom first, or share your referral link.',
          style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.stone, height: 1.4),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 14, color: OseeTheme.stone),
            hintText: 'Search students…',
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 8),
        if (available.isEmpty)
          Text('All students already assigned or none match.', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.stone))
        else
          for (final s in available.take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: () => widget.onPick((s as Map<String, dynamic>)['id'] as String, s['name'] as String? ?? 'student'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: OseeTheme.cloud)),
                  child: Row(
                    children: [
                      const Icon(Icons.person_add_outlined, size: 14, color: OseeTheme.accent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s['name'] as String? ?? '—', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink))),
                      Text(s['email'] as String? ?? '', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: OseeTheme.stone)),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _StudentAssignmentRow extends StatelessWidget {
  const _StudentAssignmentRow({required this.name, required this.email, required this.onUnassign});
  final String name;
  final String email;
  final VoidCallback onUnassign;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1AC9A96E),
        border: Border(left: BorderSide(color: OseeTheme.gold, width: 2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, size: 14, color: OseeTheme.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
                Text(email, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: OseeTheme.stone)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.remove_circle_outline, size: 16, color: OseeTheme.accent), onPressed: onUnassign, tooltip: 'Unassign'),
        ],
      ),
    );
  }
}