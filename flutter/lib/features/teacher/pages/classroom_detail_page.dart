import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../shared/widgets/ui_components.dart';

/// Classroom detail page — Task 2.x.
class ClassroomDetailPage extends StatefulWidget {
  const ClassroomDetailPage({super.key, required this.classroomId});
  final String classroomId;

  @override
  State<ClassroomDetailPage> createState() => _ClassroomDetailPageState();
}

class _ClassroomDetailPageState extends State<ClassroomDetailPage> {
  Map<String, dynamic>? _classroom;
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
      final r = await dio.get('/teacher/classrooms/${widget.classroomId}');
      setState(() {
        _classroom = r.data as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load classroom';
        _isLoading = false;
      });
    }
  }

  Future<void> _viewStudentReport(String studentId, String studentName) async {
    if (studentId.isEmpty) return;
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/teacher/students/$studentId/report');
      if (!mounted) return;
      final report = r.data as Map<String, dynamic>;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Report — $studentName'),
          content: SizedBox(
            width: 400,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text('Email: ${report['student']?['email'] ?? '—'}'),
                Text('Target: ${report['student']?['target_exam'] ?? '—'}'),
                const SizedBox(height: 12),
                const Text(
                  'Latest Scores:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '• iBT: ${report['progress']?['ibt_latest_score'] ?? '—'}',
                ),
                Text(
                  '• ITP: ${report['progress']?['itp_latest_score'] ?? '—'}',
                ),
                Text(
                  '• IELTS: ${report['progress']?['ielts_latest_band'] ?? '—'}',
                ),
                Text(
                  '• TOEIC: ${report['progress']?['toeic_latest_score'] ?? '—'}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Weaknesses:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                if ((report['weaknesses'] as List?)?.isEmpty ?? true)
                  const Text('• None detected'),
                for (final w in (report['weaknesses'] as List?) ?? [])
                  Text('• ${(w as Map)['area']}: ${(w)['recommendation']}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: '${_classroom?['id']}'));
                Navigator.pop(ctx);
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.contains('404')
                ? 'No report available for this student yet'
                : 'Failed to load report',
            ),
          ),
        );
      }
    }
  }

  Future<void> _addStudents() async {
    final controller = TextEditingController();
    final emails = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Students'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter student emails (comma-separated):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Student emails',
                hintText: 'a@x.com, b@y.com',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              keyboardType: TextInputType.emailAddress,
              maxLines: 3,
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (emails == null || emails.isEmpty) return;

    final list = emails
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (list.isEmpty) return;

    try {
      final dio = ApiClient.create();
      final r = await dio.post(
        '/teacher/classrooms/${widget.classroomId}/students',
        data: {'student_emails': list},
      );
      if (!mounted) return;
      final data = r.data as Map<String, dynamic>? ?? {};
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Enrolled: ${data['enrolled'] ?? 0}, '
            'Already: ${data['already_enrolled'] ?? 0}, '
            'Not found: ${data['not_found'] ?? 0}',
          ),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _openClassroomReport() async {
    final url =
        'https://osee-prep-hub-worker.edubot-leonardus.workers.dev'
        '/api/teacher/classrooms/${widget.classroomId}/report/html';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Classroom Report'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Open this URL in your browser to view/print the report:',
              ),
              const SizedBox(height: 8),
              SelectableText(
                url,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
              const SizedBox(height: 12),
              const Text('Make sure you are logged in (auth cookie needed).'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_classroom?['name'] as String? ?? 'Classroom'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Add students',
            onPressed: _addStudents,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.grid_on),
            tooltip: 'Heatmap report',
            onPressed: () =>
                context.go('/teacher/classrooms/${widget.classroomId}/report'),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF report',
            onPressed: _openClassroomReport,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : _buildContent(_classroom ?? {}),
    );
  }

  Widget _buildContent(Map<String, dynamic> c) {
    final students = (c['students'] as List?) ?? [];
    final joinCode = c['join_code'] as String?;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['name'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (c['description'] != null) ...[
                  const SizedBox(height: 4),
                  Text(c['description'] as String),
                ],
                const SizedBox(height: 8),
                Text('Target: ${c['target_exam'] ?? '—'}'),
                if (joinCode != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Join code: $joinCode',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Students (${students.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (students.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No students yet. Share join code "$joinCode" with your students.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          for (final s in students)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(
                  ((s as Map)['student'] as Map?)?['display_name'] as String? ?? '',
                ),
                subtitle: Text(
                  (s['student'] as Map?)?['email'] as String? ?? '',
                ),
                trailing: const Icon(Icons.picture_as_pdf),
                onTap: () => _viewStudentReport(
                  (s['student'] as Map?)?['id'] as String? ?? '',
                  (s['student'] as Map?)?['display_name'] as String? ?? 'Student',
                ),
              ),
            ),
      ],
    );
  }
}
