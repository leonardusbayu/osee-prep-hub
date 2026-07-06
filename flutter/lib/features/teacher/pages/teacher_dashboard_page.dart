import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';

/// Unified Teacher Dashboard — magazine editorial style.
///
/// Three sections:
///  1. Masthead — kicker + teacher name + gold rule + stat strip (4 numbers).
///  2. CLASSROOMS — horizontal scroll of classroom cards (Trello-ish tiles).
///  3. STUDENTS — searchable roster table with progress columns (iBT / IELTS /
///     TOEIC / readiness / EduBot XP if available). Tap a row → student report.
class TeacherDashboardPage extends ConsumerStatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  ConsumerState<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends ConsumerState<TeacherDashboardPage> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  String _studentQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.create();
      final res = await dio.get('/teacher/dashboard');
      setState(() {
        _data = res.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load dashboard';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseeTheme.paper,
      appBar: AppBar(
        backgroundColor: OseeTheme.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TEACHER DASHBOARD',
              style: TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: OseeTheme.stone,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _data?['user']?['name'] ?? '—',
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: OseeTheme.ink,
              ),
            ),
            const SizedBox(height: 6),
            Container(height: 1, color: OseeTheme.gold),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: OseeTheme.ink),
            onPressed: _loadDashboard,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: OseeTheme.ink),
            onPressed: () => context.go('/login'),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: OseeTheme.ink))
          : _error != null
              ? _ErrorPanel(error: _error!, onRetry: _loadDashboard)
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: _buildBody(),
                ),
    );
  }

  Widget _buildBody() {
    final data = _data ?? {};
    final classrooms = (data['classrooms'] as List? ?? const []) as List;
    final students = (data['students'] as List? ?? const []) as List;
    final activity = (data['recent_activity'] as List? ?? const []) as List;
    final edubotOn = data['edubot_bridge_enabled'] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // ---------- Masthead stat strip ----------
        _StatStrip(
          stats: [
            _Stat(label: 'STUDENTS', value: '${data['total_students'] ?? 0}', accent: OseeTheme.accent),
            _Stat(label: 'CLASSES', value: '${data['classrooms_count'] ?? 0}', accent: OseeTheme.gold),
            _Stat(label: 'COMMISSION', value: 'Rp ${_fmtIdr(data['commission_this_month'] ?? 0)}', accent: OseeTheme.sage),
            _Stat(label: 'AI CREDITS', value: '${data['ai_quota_remaining'] ?? 0}', accent: const Color(0xFF4F8DE0)),
          ],
        ),
        const SizedBox(height: 8),
        if (edubotOn)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: OseeTheme.sage, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(
                  'EDUBOT LIVE',
                  style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.sage),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // ---------- Quick actions ----------
        _SectionLabel(label: 'ACTIONS', action: null),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ActionChip(icon: Icons.view_kanban_outlined, label: 'Syllabi', onTap: () => context.push('/teacher/syllabi')),
            _ActionChip(icon: Icons.class_outlined, label: 'AI Grader', onTap: () => context.push('/teacher/ai-grader')),
            _ActionChip(icon: Icons.auto_awesome_outlined, label: 'Generator', onTap: () => context.push('/teacher/generator')),
            _ActionChip(icon: Icons.shopping_cart_outlined, label: 'Order Tests', onTap: () => context.push('/teacher/orders')),
          ],
        ),
        const SizedBox(height: 28),

        // ---------- Classrooms ----------
        Row(
          children: [
            const _SectionLabel(label: 'CLASSROOMS'),
            const Spacer(),
            if (classrooms.isNotEmpty)
              TextButton(
                onPressed: () => context.push('/teacher/syllabi'),
                child: const Text('MANAGE SYLLABI', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (classrooms.isEmpty)
          _EmptyState(message: 'No classrooms yet. Students joining with your referral code will appear here.')
        else
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: classrooms.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final c = classrooms[i] as Map<String, dynamic>;
                return _ClassroomCard(
                  name: c['name'] as String? ?? '—',
                  targetExam: c['target_exam'] as String?,
                  joinCode: c['join_code'] as String? ?? '',
                  studentCount: c['student_count'] as int? ?? 0,
                  syllabusCount: c['syllabus_count'] as int? ?? 0,
                );
              },
            ),
          ),
        const SizedBox(height: 28),

        // ---------- Students ----------
        Row(
          children: [
            const _SectionLabel(label: 'STUDENTS'),
            const Spacer(),
            if (students.isNotEmpty)
              SizedBox(
                width: 180,
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 14, color: OseeTheme.stone),
                    hintText: 'Search…',
                    hintStyle: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.stone),
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                  ),
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 12),
                  onChanged: (v) => setState(() => _studentQuery = v),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (students.isEmpty)
          _EmptyState(message: 'No students enrolled yet. Share your referral code to invite students.')
        else
          _StudentRoster(
            students: students
                .where((s) {
                  if (_studentQuery.isEmpty) return true;
                  final sn = (s as Map<String, dynamic>)['display_name'] as String? ?? '';
                  final em = s['email'] as String? ?? '';
                  final q = _studentQuery.toLowerCase();
                  return sn.toLowerCase().contains(q) || em.toLowerCase().contains(q);
                })
                .toList(),
            edubotOn: edubotOn,
            onStudentTap: (studentId) async {
              // Fetch the student report inline and show in a dialog.
              try {
                final dio = ApiClient.create();
                final res = await dio.get('/teacher/students/$studentId/report');
                if (!mounted) return;
                _showReportDialog(context, res.data as Map<String, dynamic>);
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report unavailable for this student')));
              }
            },
          ),
        const SizedBox(height: 28),

        // ---------- Recent activity ----------
        const _SectionLabel(label: 'RECENT ACTIVITY'),
        const SizedBox(height: 10),
        if (activity.isEmpty)
          _EmptyState(message: 'No activity yet. Practice-test completions and bookings will appear here.')
        else
          Column(
            children: [
              for (final a in activity.take(8))
                _ActivityRow(
                  event: (a as Map<String, dynamic>)['event_type'] as String? ?? 'event',
                  platform: a['platform'] as String?,
                  timestamp: a['timestamp'] as String? ?? '',
                ),
            ],
          ),
      ],
    );
  }

  void _showReportDialog(BuildContext context, Map<String, dynamic> report) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: OseeTheme.paper,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('STUDENT REPORT', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3, color: OseeTheme.stone)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: OseeTheme.gold),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      _prettyReport(report),
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtIdr(dynamic v) {
    final n = v is num ? v : int.tryParse('$v') ?? 0;
    return n.toString();
  }

  String _prettyReport(Map<String, dynamic> report) {
    try {
      return const JsonEncoder.withIndent('  ').convert(report);
    } catch (_) {
      return report.toString();
    }
  }
}

// ============================================================
// Magazine-styled components
// ============================================================

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats});
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: OseeTheme.ink, width: 3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(width: 16),
              Container(width: 1, height: 36, color: OseeTheme.cloud),
              const SizedBox(width: 16),
            ],
            Expanded(child: stats[i]),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.accent});
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.stone),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700, color: accent, height: 1.1),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.action});
  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 1, color: OseeTheme.ink),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.ink),
        ),
        if (action != null) ...[
          const Spacer(),
          action!,
        ],
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w600, color: OseeTheme.ink)),
      avatar: Icon(icon, size: 16, color: OseeTheme.accent),
      backgroundColor: Colors.white,
      side: const BorderSide(color: OseeTheme.cloud),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      onPressed: onTap,
    );
  }
}

class _ClassroomCard extends StatelessWidget {
  const _ClassroomCard({
    required this.name,
    required this.targetExam,
    required this.joinCode,
    required this.studentCount,
    required this.syllabusCount,
  });

  final String name;
  final String? targetExam;
  final String joinCode;
  final int studentCount;
  final int syllabusCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: OseeTheme.gold, width: 3),
          bottom: BorderSide(color: OseeTheme.cloud, width: 1),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (targetExam != null)
            Text(
              targetExam!.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.gold),
            ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.w700, color: OseeTheme.ink, height: 1.2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Container(height: 0.5, color: const Color(0x99C9A96E)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.groups, size: 12, color: OseeTheme.stone),
              const SizedBox(width: 4),
              Text(
                '$studentCount students',
                style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: OseeTheme.stone),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.view_kanban, size: 12, color: OseeTheme.stone),
              const SizedBox(width: 4),
              Text(
                '$syllabusCount syllabi',
                style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: OseeTheme.stone),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: OseeTheme.cloud)),
            child: Text(
              'JOIN: $joinCode',
              style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: OseeTheme.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentRoster extends StatelessWidget {
  const _StudentRoster({required this.students, required this.edubotOn, required this.onStudentTap});
  final List students;
  final bool edubotOn;
  final void Function(String studentId) onStudentTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: OseeTheme.cloud),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFEFEDE6),
              border: Border(bottom: BorderSide(color: OseeTheme.cloud, width: 1)),
            ),
            child: Row(
              children: [
                _col('STUDENT', 2),
                _col('LEVEL', 1),
                _col('iBT', 1),
                _col('IELTS', 1),
                _col('READY', 1),
                if (edubotOn) _col('EDUBOT XP', 1),
              ],
            ),
          ),
          for (final s in students)
            _StudentRow(
              student: s as Map<String, dynamic>,
              edubotOn: edubotOn,
              onTap: () => onStudentTap(s['id'] as String),
            ),
        ],
      ),
    );
  }

  Widget _col(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.stone),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, required this.edubotOn, required this.onTap});
  final Map<String, dynamic> student;
  final bool edubotOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = student['display_name'] as String? ?? '—';
    final email = student['email'] as String? ?? '';
    final level = student['current_level'] as String? ?? '—';
    final ibt = student['ibt_latest_score'];
    final ielts = student['ielts_latest_band'];
    final readiness = student['readiness_status'] as String? ?? 'preparing';
    final readinessPct = student['readiness_pct'] as num? ?? 0;
    final xp = student['edubot_xp'];

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: OseeTheme.cloud, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
                  Text(email, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: OseeTheme.stone)),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(level, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, color: OseeTheme.ink)),
            ),
            Expanded(
              flex: 1,
              child: Text(
                ibt != null ? '$ibt' : '—',
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: OseeTheme.ink),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                ielts != null ? '$ielts' : '—',
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: OseeTheme.ink),
              ),
            ),
            Expanded(
              flex: 1,
              child: _ReadinessBadge(status: readiness, pct: readinessPct.toDouble()),
            ),
            if (edubotOn)
              Expanded(
                flex: 1,
                child: Text(
                  xp != null ? '$xp' : '—',
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: OseeTheme.sage),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessBadge extends StatelessWidget {
  const _ReadinessBadge({required this.status, required this.pct});
  final String status;
  final double pct;

  Color _color() {
    switch (status) {
      case 'ready':
        return OseeTheme.sage;
      case 'almost_ready':
        return OseeTheme.gold;
      case 'tested':
        return const Color(0xFF4F8DE0);
      default:
        return OseeTheme.stone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), border: Border(left: BorderSide(color: color, width: 2))),
      child: Text(
        '${status.replaceAll('_', ' ').toUpperCase()} ${pct.toInt()}%',
        style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.event, required this.platform, required this.timestamp});
  final String event;
  final String? platform;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: OseeTheme.cloud, width: 0.5))),
      child: Row(
        children: [
          Container(width: 3, height: 18, color: OseeTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, color: OseeTheme.ink, letterSpacing: 0.5),
                ),
                if (platform != null)
                  Text(
                    platform!.toUpperCase(),
                    style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: OseeTheme.gold),
                  ),
              ],
            ),
          ),
          Text(
            timestamp.substring(0, timestamp.length > 10 ? 10 : timestamp.length),
            style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: OseeTheme.stone),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: OseeTheme.cloud),
      ),
      child: Text(
        message,
        style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 13, color: OseeTheme.stone, height: 1.5),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: OseeTheme.accent),
          const SizedBox(height: 16),
          Text(error, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, color: OseeTheme.ink)),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}