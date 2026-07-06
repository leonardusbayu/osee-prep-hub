import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';

/// Student dashboard — magazine editorial style.
///
/// Sections:
///  1. Readiness gauge (big number + progress bar).
///  2. JOIN A CLASSROOM — input for entering a teacher's join code.
///  3. My Classes — list of enrolled classrooms.
///  4. Recent Progress — scores across practice platforms.
class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  ConsumerState<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage> {
  Map<String, dynamic>? _dashboard;
  bool _isLoading = true;
  String? _error;
  bool _isJoining = false;
  final _joinCodeCtl = TextEditingController();

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
      final r = await dio.get('/student/dashboard');
      setState(() {
        _dashboard = r.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load';
        _isLoading = false;
      });
    }
  }

  Future<void> _joinClassroom() async {
    final code = _joinCodeCtl.text.trim();
    if (code.isEmpty) return;
    setState(() => _isJoining = true);
    try {
      final dio = ApiClient.create();
      final res = await dio.post('/student/classrooms/join', data: {'join_code': code});
      if (!mounted) return;
      final classroomName = (res.data as Map<String, dynamic>)['classroom_name'] as String? ?? 'classroom';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined $classroomName'), backgroundColor: OseeTheme.sage),
      );
      _joinCodeCtl.clear();
      _load();
    } catch (e) {
      if (!mounted) return;
      String msg = 'Failed to join';
      try {
        final d = (e as dynamic).response?.data as Map<String, dynamic>?;
        if (d != null) {
          final errMsg = (d['error'] as Map<String, dynamic>?)?['message'] as String?;
          if (errMsg != null) msg = errMsg;
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: OseeTheme.accent));
    } finally {
      if (mounted) setState(() => _isJoining = false);
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
              'MY LEARNING',
              style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3, color: OseeTheme.stone),
            ),
            const SizedBox(height: 2),
            Text(
              _dashboard?['student']?['name'] ?? 'Student',
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.w700, color: OseeTheme.ink),
            ),
            const SizedBox(height: 6),
            Container(height: 1, color: OseeTheme.gold),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: OseeTheme.ink), onPressed: _load, tooltip: 'Refresh'),
          IconButton(icon: const Icon(Icons.logout, color: OseeTheme.ink), onPressed: () => context.go('/login'), tooltip: 'Logout'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: OseeTheme.ink))
          : _error != null
              ? _ErrorPanel(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildContent(_dashboard ?? {}),
                ),
    );
  }

  Widget _buildContent(Map<String, dynamic> d) {
    final progress = d['progress'] as Map<String, dynamic>? ?? {};
    final classrooms = (d['classrooms'] as List? ?? const []) as List;
    final readiness = (d['readiness'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // ---------- Readiness gauge ----------
        _ReadinessGauge(readiness: readiness),
        const SizedBox(height: 24),

        // ---------- Join a classroom ----------
        const _SectionLabel(label: 'JOIN A CLASSROOM'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: OseeTheme.accent, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Have a code from your teacher?',
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: OseeTheme.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter the 6-character join code to enroll in your class.',
                style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.stone, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _joinCodeCtl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'ABCDEF',
                        hintStyle: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 14, color: OseeTheme.stone),
                        counterText: '',
                        border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.w700, color: OseeTheme.ink, letterSpacing: 4),
                      maxLength: 6,
                      onSubmitted: (_) => _joinClassroom(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isJoining ? null : _joinClassroom,
                    style: FilledButton.styleFrom(
                      backgroundColor: OseeTheme.ink,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    ),
                    child: _isJoining
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                        : const Text('JOIN', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ---------- My Classes ----------
        const _SectionLabel(label: 'MY CLASSES'),
        const SizedBox(height: 10),
        if (classrooms.isEmpty)
          _EmptyState(message: 'No classes yet. Enter a join code above, or ask your teacher for their referral link.')
        else
          Column(
            children: [
              for (final c in classrooms)
                _ClassroomRow(
                  name: (c as Map<String, dynamic>)['name'] as String? ?? '—',
                  teacherName: c['teacher_name'] as String? ?? '—',
                  targetExam: c['target_exam'] as String?,
                ),
            ],
          ),
        const SizedBox(height: 24),

        // ---------- Recent Progress ----------
        const _SectionLabel(label: 'RECENT PROGRESS'),
        const SizedBox(height: 10),
        _ProgressCard(progress: progress),
        if (readiness > 80) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0x226B8E7F),
              border: Border(left: BorderSide(color: OseeTheme.sage, width: 3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: OseeTheme.sage, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ready for the official test?', style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
                      Text('Book your TOEFL or TOEIC at the OSEE test center.', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.stone)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking flow coming soon'))),
                  child: const Text('BOOK'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// Magazine-styled components
// ============================================================

class _ReadinessGauge extends StatelessWidget {
  const _ReadinessGauge({required this.readiness});
  final int readiness;

  @override
  Widget build(BuildContext context) {
    final color = readiness > 80 ? OseeTheme.sage : readiness > 50 ? OseeTheme.gold : OseeTheme.accent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('READINESS', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: OseeTheme.stone)),
                const SizedBox(height: 4),
                Text(
                  '$readiness%',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 48, fontWeight: FontWeight.w700, color: color, height: 1),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 8,
            height: 80,
            child: LinearProgressIndicator(
              value: readiness / 100,
              minHeight: 8,
              color: color,
              backgroundColor: OseeTheme.cloud,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

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
      ],
    );
  }
}

class _ClassroomRow extends StatelessWidget {
  const _ClassroomRow({required this.name, required this.teacherName, required this.targetExam});
  final String name;
  final String teacherName;
  final String? targetExam;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: OseeTheme.gold, width: 3),
          bottom: BorderSide(color: OseeTheme.cloud, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.class_outlined, size: 18, color: OseeTheme.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
                const SizedBox(height: 2),
                Text('Teacher: $teacherName', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: OseeTheme.stone)),
              ],
            ),
          ),
          if (targetExam != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(border: Border.all(color: OseeTheme.cloud)),
              child: Text(
                targetExam!.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: OseeTheme.gold),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});
  final Map<String, dynamic> progress;

  @override
  Widget build(BuildContext context) {
    final ibt = progress['ibt_latest_score'];
    final itp = progress['itp_latest_score'];
    final ielts = progress['ielts_latest_band'];
    final toeic = progress['toeic_latest_score'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: OseeTheme.cloud),
      ),
      child: Column(
        children: [
          _row('TOEFL iBT', ibt != null ? '$ibt' : '—'),
          _row('TOEFL ITP', itp != null ? '$itp' : '—'),
          _row('IELTS band', ielts != null ? '$ielts' : '—'),
          _row('TOEIC', toeic != null ? '$toeic' : '—'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink))),
          Text(value, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
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