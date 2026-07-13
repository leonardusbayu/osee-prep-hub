import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../shared/widgets/ui_components.dart';
import '../../../app/theme.dart';

/// Student syllabus page — blueprint line 1623.
/// Shows assigned syllabi + items with deep links to practice platforms.
class StudentSyllabusPage extends StatefulWidget {
  const StudentSyllabusPage({super.key});

  @override
  State<StudentSyllabusPage> createState() => _StudentSyllabusPageState();
}

class _StudentSyllabusPageState extends State<StudentSyllabusPage> {
  List<dynamic>? _syllabi;
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
      final r = await dio.get('/student/syllabus');
      setState(() { _syllabi = (r.data as Map)['syllabi'] as List? ?? []; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load'; _isLoading = false; });
    }
  }

  Future<void> _startItem(String itemId) async {
    try {
      final dio = ApiClient.create();
      final r = await dio.post('/student/syllabus/$itemId/start', data: {});
      final deepLink = (r.data as Map)['deep_link'] as String?;
      if (deepLink != null && deepLink.isNotEmpty && mounted) {
        // Open deep link in new tab
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening: $deepLink'), action: SnackBarAction(label: 'Open', onPressed: () {})),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Started! No external link for this item.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _completeItem(String itemId) async {
    try {
      final dio = ApiClient.create();
      await dio.post('/student/syllabus/$itemId/complete', data: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completed! ✓')),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Syllabus'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: OseeTheme.primary,
                  child: (_syllabi?.isEmpty ?? true)
                      ? ListView(children: [
                          const SizedBox(height: 100),
                          EmptyState(
                            icon: Icons.view_kanban_outlined,
                            title: 'No syllabus assigned yet',
                            subtitle: 'Ask your teacher to assign a syllabus to your classroom.',
                          ),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(Spacing.md),
                          itemCount: _syllabi!.length,
                          itemBuilder: (ctx, i) => _SyllabusCard(
                            syllabus: _syllabi![i] as Map<String, dynamic>,
                            onStart: _startItem,
                            onComplete: _completeItem,
                          ),
                        ),
                ),
    );
  }
}

class _SyllabusCard extends StatelessWidget {
  const _SyllabusCard({required this.syllabus, required this.onStart, required this.onComplete});
  final Map<String, dynamic> syllabus;
  final void Function(String) onStart;
  final void Function(String) onComplete;

  @override
  Widget build(BuildContext context) {
    final items = (syllabus['syllabus_items'] as List?) ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: OseeTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: OseeTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.view_kanban_rounded, color: OseeTheme.primary, size: 20),
              ),
              const SizedBox(width: Spacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(syllabus['name'] as String? ?? '', style: Theme.of(context).textTheme.titleMedium),
                    Text('${syllabus['target_exam'] ?? '—'} · ${items.length} items', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: OseeTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          for (final item in items)
            _SyllabusItemTile(
              item: item as Map<String, dynamic>,
              onStart: () => onStart(item['id'] as String),
              onComplete: () => onComplete(item['id'] as String),
            ),
        ],
      ),
    );
  }
}

class _SyllabusItemTile extends StatelessWidget {
  const _SyllabusItemTile({required this.item, required this.onStart, required this.onComplete});
  final Map<String, dynamic> item;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final type = item['item_type'] as String? ?? '';
    final icon = _typeIcon(type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs + 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: OseeTheme.textSecondary),
          const SizedBox(width: Spacing.sm + 2),
          Expanded(
            child: Text(item['title'] as String? ?? '', style: Theme.of(context).textTheme.bodyMedium),
          ),
          TextButton(onPressed: onStart, child: const Text('Start')),
          const SizedBox(width: Spacing.xs),
          OutlinedButton(onPressed: onComplete, child: const Text('Done')),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'reading': return Icons.menu_book_rounded;
      case 'listening': return Icons.headphones_rounded;
      case 'speaking': return Icons.mic_rounded;
      case 'writing': return Icons.edit_rounded;
      case 'grammar': return Icons.spellcheck_rounded;
      case 'vocabulary': return Icons.translate_rounded;
      case 'mock_test': return Icons.quiz_rounded;
      case 'video': return Icons.video_library_rounded;
      case 'live_class': return Icons.videocam_rounded;
      default: return Icons.assignment_rounded;
    }
  }
}