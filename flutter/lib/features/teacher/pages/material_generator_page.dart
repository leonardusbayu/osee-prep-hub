import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';

/// AI Material Generator page — Task 6.3.
///
/// Form: material type, exam, level, topic → POST /api/ai/generate-material.
/// Shows preview of generated material + "Add to syllabus" button.
class MaterialGeneratorPage extends ConsumerStatefulWidget {
  const MaterialGeneratorPage({super.key});

  @override
  ConsumerState<MaterialGeneratorPage> createState() => _MaterialGeneratorPageState();
}

class _MaterialGeneratorPageState extends ConsumerState<MaterialGeneratorPage> {
  final _formKey = GlobalKey<FormState>();
  final _topicController = TextEditingController();
  String _type = 'reading';
  String _exam = 'IELTS';
  String _level = 'B2';
  Map<String, dynamic>? _generated;
  bool _isGenerating = false;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isGenerating = true; });
    try {
      final dio = ApiClient.create();
      final response = await dio.post('/ai/generate-material', data: {
        'type': _type,
        'exam': _exam,
        'level': _level,
        'topic': _topicController.text.trim(),
      });
      setState(() { _generated = response.data as Map<String, dynamic>; _isGenerating = false; });
    } catch (e) {
      setState(() { _isGenerating = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generation failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Material Generator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Type
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Material Type'),
                items: const [
                  DropdownMenuItem(value: 'reading', child: Text('Reading Passage')),
                  DropdownMenuItem(value: 'listening', child: Text('Listening Script')),
                  DropdownMenuItem(value: 'grammar', child: Text('Grammar Exercise')),
                  DropdownMenuItem(value: 'vocabulary', child: Text('Vocabulary Set')),
                  DropdownMenuItem(value: 'writing', child: Text('Writing Prompt')),
                  DropdownMenuItem(value: 'mock_test', child: Text('Mock Test')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'reading'),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _exam,
                      decoration: const InputDecoration(labelText: 'Exam'),
                      items: const [
                        DropdownMenuItem(value: 'IELTS', child: Text('IELTS')),
                        DropdownMenuItem(value: 'TOEFL_IBT', child: Text('TOEFL iBT')),
                        DropdownMenuItem(value: 'TOEFL_ITP', child: Text('TOEFL ITP')),
                        DropdownMenuItem(value: 'TOEIC', child: Text('TOEIC')),
                        DropdownMenuItem(value: 'GENERAL', child: Text('General English')),
                      ],
                      onChanged: (v) => setState(() => _exam = v ?? 'IELTS'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _level,
                      decoration: const InputDecoration(labelText: 'Level'),
                      items: const [
                        DropdownMenuItem(value: 'A2', child: Text('A2')),
                        DropdownMenuItem(value: 'B1', child: Text('B1')),
                        DropdownMenuItem(value: 'B2', child: Text('B2')),
                        DropdownMenuItem(value: 'C1', child: Text('C1')),
                      ],
                      onChanged: (v) => setState(() => _level = v ?? 'B2'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _topicController,
                decoration: const InputDecoration(
                  labelText: 'Topic',
                  hintText: 'e.g. technology and society',
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Topic required' : null,
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: _isGenerating ? null : _generate,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate Material'),
              ),

              if (_isGenerating) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],

              if (_generated != null) ...[
                const SizedBox(height: 24),
                _buildPreview(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final g = _generated!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g['content']?['title'] as String? ?? 'Generated Material',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (g['content']?['passage'] != null) ...[
              Text('Passage', style: Theme.of(context).textTheme.titleSmall),
              Text(g['content']['passage'] as String, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            if (g['content']?['script'] != null) ...[
              Text('Script', style: Theme.of(context).textTheme.titleSmall),
              Text(g['content']['script'] as String, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            if ((g['content']?['questions'] as List?)?.isNotEmpty ?? false) ...[
              Text('Questions', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              ...((g['content']['questions'] as List).take(3).map((q) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q['question'] as String? ?? ''),
                      if ((q['options'] as List?) != null)
                        ...(q['options'] as List).take(4).toList().asMap().entries.map((e) =>
                          Text('${String.fromCharCode(65 + e.key)}. ${e.value}', style: const TextStyle(fontSize: 13))
                        ),
                    ],
                  ),
                ),
              ))),
            ],
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _addToSyllabus,
              icon: const Icon(Icons.add),
              label: const Text('Add to Syllabus'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToSyllabus() async {
    if (_generated == null) return;
    try {
      final dio = ApiClient.create();
      // Fetch teacher's syllabi
      final r = await dio.get('/teacher/syllabi');
      final syllabi = (r.data as Map)['syllabi'] as List? ?? [];
      if (syllabi.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No syllabi yet. Create one first.')),
          );
        }
        return;
      }

      // Show dialog to pick a syllabus
      final selectedSyllabus = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Choose Syllabus'),
          content: SizedBox(
            width: 300,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final s in syllabi)
                  ListTile(
                    leading: const Icon(Icons.view_kanban),
                    title: Text((s as Map)['name'] as String? ?? ''),
                    subtitle: Text('${s['target_exam'] ?? '—'}'),
                    onTap: () => Navigator.pop(ctx, s as Map<String, dynamic>),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ],
        ),
      );

      if (selectedSyllabus == null) return;
      final syllabusId = selectedSyllabus['id'] as String;

      // Get next sort order (count existing items)
      final itemsR = await dio.get('/teacher/syllabi/$syllabusId');
      final itemsList = ((itemsR.data as Map)['items'] as List?) ?? [];

      // Build syllabus item from generated content
      final g = _generated!;
      final content = g['content'] as Map<String, dynamic>? ?? {};
      final title = (content['title'] as String?) ?? _topicController.text.trim();
      final itemType = _type == 'mock_test' ? 'mock_test' : _type;
      final payload = {
        'source_type': 'ai_generated',
        'title': title,
        'description': 'AI-generated $_type for $_exam ($_level)',
        'item_type': itemType,
        'section': _type,
        'difficulty': _level,
        'sort_order': itemsList.length,
        'ai_generated_content': content,
      };

      await dio.post('/teacher/syllabi/$syllabusId/items', data: payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to syllabus ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}