import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../../shared/widgets/ui_components.dart';

/// Student reports list page — Task 8.x.
/// Lists students across the teacher's classrooms and links to detailed reports.
class StudentReportsPage extends StatefulWidget {
  const StudentReportsPage({super.key});

  @override
  State<StudentReportsPage> createState() => _StudentReportsPageState();
}

class _StudentReportsPageState extends State<StudentReportsPage> {
  List<dynamic>? _classrooms;
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
      final r = await dio.get('/teacher/classrooms');
      setState(() {
        _classrooms = (r.data as Map)['classrooms'] as List? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load';
        _isLoading = false;
      });
    }
  }

  void _copyReportUrl(String studentId, String studentName) {
    final url =
        'https://osee-prep-hub-worker.edubot-leonardus.workers.dev'
        '/api/teacher/students/$studentId/report/html';
    launchUrl(Uri.parse(url));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Report — $studentName'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The report opened in a new tab.'),
              const SizedBox(height: 8),
              SelectableText(
                url,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
              const SizedBox(height: 12),
              const Text(
                'If it didn\'t open, copy the URL above and paste it in a '
                'browser where you\'re logged in to the hub.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: url)),
            child: const Text('Copy URL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingState()
        : _error != null
        ? ErrorState(message: _error!, onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_classrooms?.isEmpty ?? true)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No classrooms yet. Create one first.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                else
                  for (final cr in _classrooms!)
                    Card(
                      child: ExpansionTile(
                        leading: const Icon(Icons.class_),
                        title: Text((cr as Map)['name'] as String? ?? ''),
                        subtitle: Text('Join code: ${cr['join_code'] ?? '—'}'),
                        children: [
                          // For each student in classroom, show row
                          for (final s
                              in (cr['students'] as List?) ?? <dynamic>[])
                            ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(
                                (s as Map)['display_name'] as String? ?? '',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.picture_as_pdf),
                                onPressed: () => _copyReportUrl(
                                  s['id'] as String,
                                  s['display_name'] as String? ?? 'Student',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
              ],
            ),
          );
  }
}
