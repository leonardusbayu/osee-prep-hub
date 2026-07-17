import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../student_theme.dart';
import '../widgets/student_widgets.dart';

/// Video lessons library page (student) — Modernized UI.
class VideoLessonsPage extends ConsumerStatefulWidget {
  const VideoLessonsPage({super.key});

  @override
  ConsumerState<VideoLessonsPage> createState() => _VideoLessonsPageState();
}

class _VideoLessonsPageState extends ConsumerState<VideoLessonsPage> {
  List<dynamic>? _courses;
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
      final r = await dio.get('/videos/courses');
      setState(() {
        _courses = (r.data as Map)['courses'] as List? ?? [];
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
    final isEmpty = _courses?.isEmpty ?? true;

    return RefreshIndicator(
      onRefresh: _load,
      color: StudentTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(StudentSpacing.xl),
        children: [
          StudentTopBar(
            name: 'Student',
            subtitle: 'Video Lessons',
            onMenuTap: isDesktop ? null : () => Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(height: StudentSpacing.xxl),
          
          if (isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 64, horizontal: StudentSpacing.xl),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: StudentTheme.surface,
                borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
                boxShadow: StudentTheme.cardShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined, size: 64, color: StudentTheme.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: StudentSpacing.lg),
                  Text('No video courses yet', style: StudentTheme.courseTitle()),
                  const SizedBox(height: 8),
                  Text('Courses will appear here when the library is published.', style: StudentTheme.cardLabel(), textAlign: TextAlign.center),
                ],
              ),
            )
          else ...[
            const StudentSectionHeader(
              title: 'Library',
              icon: Icons.video_library_rounded,
            ),
            const SizedBox(height: StudentSpacing.lg),
            for (final cData in _courses!) ...[
              _buildCourseCard(cData as Map<String, dynamic>),
              const SizedBox(height: StudentSpacing.md),
            ],
          ]
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> c) {
    return Container(
      decoration: BoxDecoration(
        color: StudentTheme.surface,
        borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
        boxShadow: StudentTheme.cardShadow,
        border: Border.all(color: StudentTheme.divider),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: StudentTheme.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.play_circle_fill_rounded, color: StudentTheme.primary, size: 28),
        ),
        title: Text(
          c['title'] as String? ?? '',
          style: StudentTheme.courseTitle().copyWith(fontSize: 16),
        ),
        subtitle: Text(
          '${c['exam_type'] ?? '—'} · ${c['total_lessons'] ?? 0} lessons',
          style: StudentTheme.cardLabel(),
        ),
        children: [
          if ((c['lessons'] as List?) != null)
            for (final lesson in c['lessons'] as List)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: StudentSpacing.xl, vertical: 4),
                leading: const Icon(Icons.play_arrow_rounded, color: StudentTheme.textSecondary),
                title: Text(
                  (lesson as Map)['title'] as String? ?? '',
                  style: StudentTheme.noticeTitle().copyWith(fontWeight: FontWeight.normal),
                ),
                subtitle: Text(
                  (lesson)['section'] as String? ?? '',
                  style: StudentTheme.noticeBody(),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: StudentTheme.textSecondary),
                onTap: () {
                  // Navigate to video player
                },
              ),
        ],
      ),
    );
  }
}
