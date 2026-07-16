import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';

/// Teacher Classrooms page — Task 2.x.
class ClassroomsPage extends StatefulWidget {
  const ClassroomsPage({super.key});

  @override
  State<ClassroomsPage> createState() => _ClassroomsPageState();
}

class _ClassroomsPageState extends State<ClassroomsPage> {
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
        _error = 'Failed to load classrooms';
        _isLoading = false;
      });
    }
  }

  Future<void> _createClassroom() async {
    final nameController = TextEditingController();
    final examController = TextEditingController(text: 'TOEFL_IBT');
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Classroom'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Classroom name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: 'TOEFL_IBT',
              items: [
                'TOEFL_IBT',
                'TOEFL_ITP',
                'IELTS',
                'TOEIC',
                'GENERAL',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => examController.text = v ?? 'TOEFL_IBT',
              decoration: const InputDecoration(labelText: 'Target exam'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != true || nameController.text.trim().isEmpty) return;

    try {
      final dio = ApiClient.create();
      await dio.post(
        '/teacher/classrooms',
        data: {
          'name': nameController.text.trim(),
          'target_exam': examController.text,
          'description': descController.text.trim(),
        },
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Create failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const LoadingState()
        : _error != null
        ? ErrorState(message: _error!, onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: (_classrooms?.isEmpty ?? true)
                ? ListView(
                    padding: const EdgeInsets.all(Spacing.md),
                    children: [
                      PageHeader(
                        title: 'Classrooms',
                        subtitle:
                            'Create groups, share join codes, and monitor enrolled students.',
                        icon: Icons.class_rounded,
                        trailing: FilledButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create'),
                          onPressed: _createClassroom,
                        ),
                      ),
                      const SizedBox(height: Spacing.xl),
                      EmptyState(
                        icon: Icons.class_outlined,
                        title: 'No classrooms yet',
                        subtitle:
                            'Create a classroom to invite students with a join code.',
                        action: FilledButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create Classroom'),
                          onPressed: _createClassroom,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(Spacing.md),
                    itemCount: _classrooms!.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Spacing.lg),
                          child: PageHeader(
                            title: 'Classrooms',
                            subtitle:
                                'Manage your active learning groups and join codes.',
                            icon: Icons.class_rounded,
                            trailing: FilledButton.icon(
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create'),
                              onPressed: _createClassroom,
                            ),
                          ),
                        );
                      }
                      final index = i - 1;
                      final cr = _classrooms![index] as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.sm),
                        child: SurfaceCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: OseeTheme.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.class_rounded,
                                color: OseeTheme.primary,
                              ),
                            ),
                            title: Text(cr['name'] as String? ?? ''),
                            subtitle: Text(
                              '${cr['target_exam'] ?? '—'} · ${cr['join_code'] ?? 'no code'}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () =>
                                context.go('/teacher/classrooms/${cr['id']}'),
                          ),
                        ),
                      );
                    },
                  ),
          );
  }
}
