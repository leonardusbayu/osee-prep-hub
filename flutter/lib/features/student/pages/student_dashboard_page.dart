import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';

/// Student dashboard — magazine editorial style.
///
/// Sections:
///  1. Student masthead — avatar initials, name, level, streak.
///  2. Continue where you left off — resume card.
///  3. Readiness gauge — redesigned circular gauge.
///  4. JOIN A CLASSROOM — input for entering a teacher's join code.
///  5. My Classes — list of enrolled classrooms.
///  6. Recent Progress — scores across practice platforms.
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

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2), side: BorderSide(color: OseeTheme.cloud)),
        title: const Text('Sign Out', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: OseeTheme.stone))),
          FilledButton(
            onPressed: () { Navigator.pop(ctx); context.go('/login'); },
            style: FilledButton.styleFrom(backgroundColor: OseeTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
            child: const Text('Sign Out', style: TextStyle(fontFamily: 'Helvetica', fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseeTheme.paper,
      appBar: AppBar(
        backgroundColor: OseeTheme.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: _buildMasthead(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: OseeTheme.ink))
          : _error != null
              ? _ErrorPanel(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: OseeTheme.ink,
                  child: _buildContent(_dashboard ?? {}),
                ),
      bottomNavigationBar: _buildBottomNav(0),
    );
  }

  // ---- Masthead ----
  Widget _buildMasthead() {
    final student = _dashboard?['student'] as Map<String, dynamic>?;
    final name = student?['name'] as String? ?? 'Student';
    final initials = _extractInitials(name);
    final level = student?['current_level'] as String? ?? '—';
    final streak = student?['streak'] as int? ?? 0;
    return Row(
      children: [
        _buildAvatar(initials),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('MY LEARNING', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 3, color: OseeTheme.ink)),
              const SizedBox(height: 2),
              Text(name, style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: OseeTheme.ink, height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                _LevelBadge(level: level),
                const SizedBox(width: 8),
                _StreakBadge(streak: streak),
              ]),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: OseeTheme.ink),
          onPressed: _load,
          tooltip: 'Refresh dashboard',
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: OseeTheme.ink),
          onPressed: _confirmLogout,
          tooltip: 'Sign out',
        ),
      ],
    );
  }

  String _extractInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name.substring(0, 2).toUpperCase() : 'S';
  }

  Widget _buildAvatar(String initials) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: OseeTheme.ink, border: Border.all(color: OseeTheme.gold, width: 2)),
      child: Center(child: Text(initials, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
    );
  }

  // ---- Bottom navigation ----
  Widget _buildBottomNav(int selected) {
    final items = [
      {'label': 'Dashboard', 'icon': Icons.home_outlined, 'route': '/student', 'index': 0},
      {'label': 'Workbook', 'icon': Icons.menu_book_outlined, 'route': '/student/syllabus', 'index': 1},
      {'label': 'Practice', 'icon': Icons.quiz_outlined, 'route': '/student/practice', 'index': 2},
      {'label': 'Profile', 'icon': Icons.person_outline, 'route': '/student/profile', 'index': 3},
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: OseeTheme.ink, width: 2))),
      child: Row(
        children: items.map((item) {
          final isActive = item['index'] == selected;
          return Expanded(
            child: InkWell(
              onTap: () => context.go(item['route'] as String),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item['icon'] as IconData, size: 20, color: isActive ? OseeTheme.accent : OseeTheme.stone),
                    const SizedBox(height: 2),
                    Text((item['label'] as String).toUpperCase(), style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: isActive ? OseeTheme.accent : OseeTheme.stone)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---- Content ----
  Widget _buildContent(Map<String, dynamic> d) {
    final progress = d['progress'] as Map<String, dynamic>? ?? {};
    final classrooms = (d['classrooms'] as List? ?? const []) as List;
    final readiness = (d['readiness'] as num?)?.toInt() ?? 0;
    final student = d['student'] as Map<String, dynamic>?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // ---------- Continue where you left off ----------
        _ContinueCard(student: student, classrooms: classrooms),
        const SizedBox(height: 20),

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
            border: Border(left: BorderSide(color: OseeTheme.accent, width: 3), top: BorderSide(color: OseeTheme.cloud), bottom: BorderSide(color: OseeTheme.cloud), right: BorderSide(color: OseeTheme.cloud)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Have a code from your teacher?', style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
              const SizedBox(height: 4),
              Text('Enter the 6-character join code to enroll in your class.', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.ink.withValues(alpha: 0.6), height: 1.4)),
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
                        hintStyle: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 14, color: OseeTheme.ink.withValues(alpha: 0.4)),
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
        Row(
          children: [
            const _SectionLabel(label: 'MY CLASSES'),
            const Spacer(),
            if (classrooms.isNotEmpty)
              TextButton(
                onPressed: () => context.push('/student/syllabus'),
                child: const Text('VIEW WORKBOOK', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.accent)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (classrooms.isEmpty)
          const _EmptyState(message: 'No classes yet. Enter a join code above, or ask your teacher for their referral link.')
        else
          Column(
            children: [
              for (final c in classrooms)
                _ClassroomRow(
                  name: (c as Map<String, dynamic>)['name'] as String? ?? '—',
                  teacherName: c['teacher_name'] as String? ?? '—',
                  targetExam: c['target_exam'] as String?,
                  onTap: () => context.push('/student/syllabus'),
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
              color: OseeTheme.sage.withValues(alpha: 0.08),
              border: Border(left: BorderSide(color: OseeTheme.sage, width: 3), top: BorderSide(color: OseeTheme.cloud), bottom: BorderSide(color: OseeTheme.cloud), right: BorderSide(color: OseeTheme.cloud)),
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
                      Text('Book your TOEFL or TOEIC at the OSEE test center.', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.ink.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking flow coming soon'))),
                  style: FilledButton.styleFrom(backgroundColor: OseeTheme.sage, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
                  child: const Text('BOOK', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
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

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final String level;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: OseeTheme.gold, width: 1)),
      child: Text('CEFR $level', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: OseeTheme.ink)),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak});
  final int streak;
  @override
  Widget build(BuildContext context) {
    if (streak <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department, size: 12, color: OseeTheme.accent),
        const SizedBox(width: 2),
        Text('$streak day${streak > 1 ? 's' : ''}', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: OseeTheme.ink)),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.student, required this.classrooms});
  final Map<String, dynamic>? student;
  final List classrooms;

  @override
  Widget build(BuildContext context) {
    if (classrooms.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: () => context.push('/student/syllabus'),
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OseeTheme.ink,
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CONTINUE LEARNING', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.gold)),
                const SizedBox(height: 4),
                Text('Pick up where you left off', style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, fontStyle: FontStyle.italic)),
              ],
            ),
            const Spacer(),
            Container(width: 36, height: 36, decoration: BoxDecoration(color: OseeTheme.gold, shape: BoxShape.circle), child: const Icon(Icons.play_arrow, color: OseeTheme.ink, size: 18)),
          ],
        ),
      ),
    );
  }
}

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
        border: Border(left: BorderSide(color: color, width: 3), top: BorderSide(color: OseeTheme.cloud), bottom: BorderSide(color: OseeTheme.cloud), right: BorderSide(color: OseeTheme.cloud)),
      ),
      child: Row(
        children: [
          // Circular gauge
          SizedBox(
            width: 64, height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64, height: 64,
                  child: CircularProgressIndicator(
                    value: readiness / 100,
                    strokeWidth: 6,
                    color: color,
                    backgroundColor: OseeTheme.cloud,
                  ),
                ),
                Text('$readiness%', style: TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('READINESS', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: OseeTheme.ink)),
                const SizedBox(height: 2),
                Text(
                  readiness > 80 ? 'You are ready!' : readiness > 50 ? 'Getting close' : 'Keep practicing',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.w700, color: OseeTheme.ink),
                ),
                const SizedBox(height: 2),
                Text('Based on your recent scores across all platforms', style: TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.ink.withValues(alpha: 0.5), fontStyle: FontStyle.italic)),
              ],
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
        Text(label, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.ink)),
      ],
    );
  }
}

class _ClassroomRow extends StatelessWidget {
  const _ClassroomRow({required this.name, required this.teacherName, required this.targetExam, this.onTap});
  final String name;
  final String teacherName;
  final String? targetExam;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: OseeTheme.gold, width: 3), bottom: BorderSide(color: OseeTheme.cloud)),
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
                  Text('Teacher: $teacherName', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: OseeTheme.ink.withValues(alpha: 0.6))),
                ],
              ),
            ),
            if (targetExam != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(border: Border.all(color: OseeTheme.cloud)),
                child: Text(
                  targetExam!.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: OseeTheme.gold),
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 16, color: OseeTheme.stone),
            ],
          ],
        ),
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
          _row('TOEFL iBT', ibt != null ? '$ibt' : '—', OseeTheme.accent),
          const Divider(color: OseeTheme.cloud, height: 1),
          _row('TOEFL ITP', itp != null ? '$itp' : '—', OseeTheme.gold),
          const Divider(color: OseeTheme.cloud, height: 1),
          _row('IELTS band', ielts != null ? '$ielts' : '—', OseeTheme.sage),
          const Divider(color: OseeTheme.cloud, height: 1),
          _row('TOEIC', toeic != null ? '$toeic' : '—', OseeTheme.ink),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(width: 3, height: 16, color: accent),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink))),
          Text(value, style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: accent)),
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
        style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 13, color: OseeTheme.ink.withValues(alpha: 0.6), height: 1.5),
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
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: OseeTheme.ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
            child: const Text('Retry', style: TextStyle(fontFamily: 'Helvetica', fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}