import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';
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
    setState(() { _isLoading = true; _error = null; });
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/teacher/classrooms');
      setState(() {
        _classrooms = (r.data as Map)['classrooms'] as List? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load classrooms'; _isLoading = false; });
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
              decoration: const InputDecoration(labelText: 'Classroom name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: 'TOEFL_IBT',
              items: ['TOEFL_IBT', 'TOEFL_ITP', 'IELTS', 'TOEIC', 'GENERAL']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => examController.text = v ?? 'TOEFL_IBT',
              decoration: const InputDecoration(labelText: 'Target exam', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );

    if (result != true || nameController.text.trim().isEmpty) return;

    try {
      final dio = ApiClient.create();
      await dio.post('/teacher/classrooms', data: {
        'name': nameController.text.trim(),
        'target_exam': examController.text,
        'description': descController.text.trim(),
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Classrooms'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.add), onPressed: _createClassroom),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: (_classrooms?.isEmpty ?? true)
                      ? ListView(
                          children: [
                            const SizedBox(height: 100),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.class_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text('No classrooms yet'),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    icon: const Icon(Icons.add),
                                    label: const Text('Create Classroom'),
                                    onPressed: _createClassroom,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _classrooms!.length,
                          itemBuilder: (ctx, i) {
                            final cr = _classrooms![i] as Map<String, dynamic>;
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.class_),
                                title: Text(cr['name'] as String? ?? ''),
                                subtitle: Text(
                                  '${cr['target_exam'] ?? '—'} · ${cr['join_code'] ?? 'no code'}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.go('/teacher/classrooms/${cr['id']}'),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}