import 'package:flutter/material.dart';

import '../../../core/api_client.dart';

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
    setState(() { _isLoading = true; _error = null; });
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/videos/courses');
      setState(() {
        _courses = (r.data as Map)['courses'] as List? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video Lessons'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: (_courses?.isEmpty ?? true)
                      ? ListView(
                          children: [
                            const SizedBox(height: 100),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.video_library_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text('No video courses yet — coming soon!'),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _courses!.length,
                          itemBuilder: (ctx, i) {
                            final c = _courses![i] as Map<String, dynamic>;
                            return Card(
                              child: ExpansionTile(
                                leading: const Icon(Icons.play_circle_outline, size: 40, color: Colors.red),
                                title: Text(c['title'] as String? ?? ''),
                                subtitle: Text(
                                  '${c['exam_type'] ?? '—'} · ${c['total_lessons'] ?? 0} lessons',
                                ),
                                children: [
                                  if ((c['lessons'] as List?) != null)
                                    for (final lesson in c['lessons'] as List)
                                      ListTile(
                                        leading: const Icon(Icons.play_arrow),
                                        title: Text((lesson as Map)['title'] as String? ?? ''),
                                        subtitle: Text((lesson)['section'] as String? ?? ''),
                                        trailing: const Icon(Icons.chevron_right),
                                      ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}