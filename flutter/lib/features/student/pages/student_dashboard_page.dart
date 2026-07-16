import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../student_theme.dart';
import '../widgets/student_widgets.dart';

/// Student dashboard — Figma "Student Portal Dashboard" layout adapted to
/// OSEE Prep Hub data (endpoint eksisting `/student/dashboard` + `/readiness`).
///
/// Visual: ungu/Poppins/radius 24 (StudentTheme) via local [Theme] wrapper so
/// the global `OseeTheme` (navy/Inter) stays intact for teacher/admin.
class StudentDashboardPage extends ConsumerStatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  ConsumerState<StudentDashboardPage> createState() =>
      _StudentDashboardPageState();
}

class _StudentDashboardPageState extends ConsumerState<StudentDashboardPage> {
  Map<String, dynamic>? _dashboard;
  Map<String, dynamic>? _readiness;
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
      final results = await Future.wait([
        dio.get('/student/dashboard'),
        dio.get('/student/readiness'),
      ]);
      setState(() {
        _dashboard = results[0].data as Map<String, dynamic>?;
        _readiness = results[1].data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load';
        _isLoading = false;
      });
    }
  }

  Future<void> _joinClass() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the join code from your teacher:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Join code',
                hintText: 'ABC123',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;

    try {
      final dio = ApiClient.create();
      await dio.post('/student/classrooms/join', data: {'join_code': code});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Joined!')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
                    Text(_error!,
                        style: StudentTheme.cardLabel(
                            StudentTheme.textSecondary)),
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
    final d = _dashboard ?? {};
    final student = d['student'] as Map<String, dynamic>? ?? {};
    final progress = d['progress'] as Map<String, dynamic>? ?? {};
    final classrooms = (d['classrooms'] as List?) ?? [];
    final readiness = (d['readiness'] as num?) ?? 0;
    final name = student['name'] as String? ?? 'Student';
    final subtitle = _readiness?['target_exam'] as String? ?? 'OSEE Prep';

    final practiceCount = (progress['total_practice_count'] as num?) ?? 0;
    final recommendations =
        (_readiness?['recommendations'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(StudentSpacing.xl),
      children: [
        StudentTopBar(
          name: name,
          subtitle: subtitle,
          onMenuTap: isDesktop ? null : () => Scaffold.of(context).openDrawer(),
        ),
        const SizedBox(height: StudentSpacing.xl),
        WelcomeBanner(name: name),
        const SizedBox(height: StudentSpacing.xxl),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildLeftColumn(classrooms, readiness, practiceCount)),
              const SizedBox(width: StudentSpacing.gap),
              SizedBox(width: 293, child: _buildRightColumn(recommendations)),
            ],
          )
        else
          Column(
            children: [
              ..._buildStatRow(classrooms, readiness, practiceCount),
              const SizedBox(height: StudentSpacing.xxl),
              _buildCoursesSection(classrooms),
              const SizedBox(height: StudentSpacing.xxl),
              _buildInstructorsSection(),
              const SizedBox(height: StudentSpacing.xxl),
              _buildNoticeSection(recommendations),
              const SizedBox(height: StudentSpacing.xxl),
            ],
          ),
      ],
    );
  }

  Widget _buildLeftColumn(List classrooms, num readiness, num practiceCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._buildStatRow(classrooms, readiness, practiceCount),
        const SizedBox(height: StudentSpacing.xxl),
        _buildCoursesSection(classrooms),
      ],
    );
  }

  Widget _buildRightColumn(List recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 45),
        const StudentSectionHeader(
          title: 'Course Instructors',
          icon: Icons.people_alt_rounded,
        ),
        const SizedBox(height: StudentSpacing.lg),
        const InstructorRow(count: 3),
        const SizedBox(height: StudentSpacing.xxl),
        const StudentSectionHeader(
          title: 'Daily Notice',
          icon: Icons.campaign_rounded,
        ),
        const SizedBox(height: StudentSpacing.lg),
        DailyNoticePanel(
          items: _buildNotices(recommendations),
          onSeeMore: () => context.go('/student/readiness'),
        ),
      ],
    );
  }

  List<Widget> _buildStatRow(List classrooms, num readiness, num practiceCount) {
    final classCount = classrooms.length.toString();
    return [
      const StudentSectionHeader(
        title: 'Overview',
        icon: Icons.analytics_rounded,
      ),
      const SizedBox(height: StudentSpacing.lg),
      Row(
        children: [
          StudentStatCard(
            icon: Icons.verified_rounded,
            value: '$readiness%',
            label: 'Readiness',
            accentColor: StudentTheme.successGreen,
            surfaceColor: StudentTheme.successGreen.withValues(alpha: 0.12),
          ),
          const SizedBox(width: StudentSpacing.gap),
          StudentStatCard(
            icon: Icons.bar_chart_rounded,
            value: practiceCount.toString(),
            label: 'Practice',
            accentColor: StudentTheme.warningOrange,
            surfaceColor: StudentTheme.warningOrange.withValues(alpha: 0.12),
            highlighted: true,
          ),
          const SizedBox(width: StudentSpacing.gap),
          StudentStatCard(
            icon: Icons.class_rounded,
            value: classCount,
            label: 'Classes',
            accentColor: StudentTheme.primaryDeep,
            surfaceColor: StudentTheme.primaryDeep.withValues(alpha: 0.12),
          ),
        ],
      ),
    ];
  }

  Widget _buildCoursesSection(List classrooms) {
    final cards = classrooms.take(2).map<Widget>((c) {
      final map = c as Map<String, dynamic>;
      return StudentCourseCard(
        title: map['name'] as String? ?? 'Class',
        progress: 0.45, // Placeholder progress
        onView: () => context.go('/student/syllabus'),
      );
    }).toList();
    if (cards.isEmpty) {
      cards.add(
        StudentCourseCard(
          title: 'Join a class to get started',
          onView: _joinClass,
        ),
      );
    }
    while (cards.length < 2) {
      cards.add(const StudentCourseCard(
        title: 'No class yet',
        onView: null,
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudentSectionHeader(
          title: 'Enrolled Courses',
          icon: Icons.import_contacts_rounded,
          onSeeAll: () => context.go('/student/syllabus'),
        ),
        const SizedBox(height: StudentSpacing.lg),
        Row(
          children: [
            cards[0],
            const SizedBox(width: StudentSpacing.gap),
            cards[1],
          ],
        ),
      ],
    );
  }

  Widget _buildInstructorsSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudentSectionHeader(
          title: 'Course Instructors',
          icon: Icons.people_alt_rounded,
        ),
        SizedBox(height: StudentSpacing.lg),
        InstructorRow(count: 3),
      ],
    );
  }

  Widget _buildNoticeSection(List recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StudentSectionHeader(
          title: 'Daily Notice',
          icon: Icons.campaign_rounded,
        ),
        const SizedBox(height: StudentSpacing.lg),
        DailyNoticePanel(
          items: _buildNotices(recommendations),
          onSeeMore: () => context.go('/student/readiness'),
        ),
      ],
    );
  }

  List<NoticeItem> _buildNotices(List recommendations) {
    final notices = <NoticeItem>[];
    if (recommendations.isEmpty) {
      notices.add(const NoticeItem(
        title: 'Prelim payment due',
        body: 'Please complete your prelim payment before next week.',
        isImportant: true,
        icon: Icons.payments_rounded,
      ));
    } else {
      notices.add(NoticeItem(
        title: 'Recommendation',
        body: recommendations.first.toString(),
        icon: Icons.lightbulb_outline_rounded,
      ));
    }
    notices.add(NoticeItem(
      title: 'Exam schedule',
      body: recommendations.length > 1
          ? recommendations[1].toString()
          : 'Your next mock exam is scheduled for this Friday. Prepare well!',
      icon: Icons.event_available_rounded,
    ));
    return notices;
  }
}