import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';

/// Video lessons library page (student) — Task 13.x.
class VideoLessonsPage extends StatefulWidget {
  const VideoLessonsPage({super.key});

  @override
  State<VideoLessonsPage> createState() => _VideoLessonsPageState();
}

class _VideoLessonsPageState extends State<VideoLessonsPage> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Lessons'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: (_courses?.isEmpty ?? true)
                  ? ListView(
                      padding: const EdgeInsets.all(Spacing.md),
                      children: [
                        const PageHeader(
                          title: 'Video Lessons',
                          subtitle:
                              'Watch OSEE course videos, complete lesson quizzes, and continue from your syllabus.',
                          icon: Icons.video_library_rounded,
                        ),
                        const SizedBox(height: Spacing.xl),
                        const EmptyState(
                          icon: Icons.video_library_outlined,
                          title: 'No video courses yet',
                          subtitle:
                              'Courses will appear here when the library is published.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(Spacing.md),
                      itemCount: _courses!.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: Spacing.lg),
                            child: PageHeader(
                              title: 'Video Lessons',
                              subtitle:
                                  'Browse video courses and lesson-level practice.',
                              icon: Icons.video_library_rounded,
                            ),
                          );
                        }
                        final c = _courses![i - 1] as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Spacing.sm),
                          child: SurfaceCard(
                            child: ExpansionTile(
                              leading: const Icon(
                                Icons.play_circle_outline_rounded,
                                size: 34,
                                color: OseeTheme.primary,
                              ),
                              title: Text(c['title'] as String? ?? ''),
                              subtitle: Text(
                                '${c['exam_type'] ?? '—'} · ${c['total_lessons'] ?? 0} lessons',
                              ),
                              children: [
                                if ((c['lessons'] as List?) != null)
                                  for (final lesson in c['lessons'] as List)
                                    ListTile(
                                      leading: const Icon(
                                        Icons.play_arrow_rounded,
                                      ),
                                      title: Text(
                                        (lesson as Map)['title'] as String? ??
                                            '',
                                      ),
                                      subtitle: Text(
                                        (lesson)['section'] as String? ?? '',
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
