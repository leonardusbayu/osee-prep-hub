import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';

/// Mind-Map Recipe page — inspired by remalt.com's "dump ideas → AI generates"
/// pattern. Teacher enters a topic + free-form notes, picks exam/level/type,
/// AI generates a structured workbook unit (theory, examples, exercises, vocab),
/// then the teacher saves it as a custom syllabus item.
///
/// POST /api/ai/mind-map-recipe → recipe
/// POST /api/teacher/syllabi/:id/items → save as item with ai_generated_content
class MindMapRecipePage extends ConsumerStatefulWidget {
  const MindMapRecipePage({super.key, required this.syllabusId});
  final String syllabusId;

  @override
  ConsumerState<MindMapRecipePage> createState() => _MindMapRecipePageState();
}

class _MindMapRecipePageState extends ConsumerState<MindMapRecipePage> {
  final _topicCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  String? _exam = 'TOEFL_IBT';
  String _level = 'B2';
  String _itemType = 'grammar';
  bool _isGenerating = false;
  bool _isSaving = false;
  Map<String, dynamic>? _recipe;
  String? _error;

  @override
  void dispose() {
    _topicCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_topicCtl.text.trim().isEmpty || _notesCtl.text.trim().isEmpty) return;
    setState(() {
      _isGenerating = true;
      _error = null;
      _recipe = null;
    });
    try {
      final dio = ApiClient.create();
      final r = await dio.post('/ai/mind-map-recipe', data: {
        'topic': _topicCtl.text.trim(),
        'notes': _notesCtl.text.trim(),
        'exam': _exam,
        'level': _level,
        'item_type': _itemType,
      });
      setState(() {
        _recipe = r.data as Map<String, dynamic>?;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Generation failed: $e';
        _isGenerating = false;
      });
    }
  }

  Future<void> _saveToSyllabus() async {
    if (_recipe == null) return;
    setState(() => _isSaving = true);
    try {
      final dio = ApiClient.create();
      await dio.post('/teacher/syllabi/${widget.syllabusId}/items', data: {
        'title': _recipe!['title'],
        'description': _recipe!['summary'],
        'source_type': 'ai_generated',
        'item_type': _itemType,
        'section': 'week-1',
        'difficulty': _level,
        'estimated_minutes': 25,
        'ai_generated_content': _recipe!['ai_generated_content'] ?? _recipe,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to syllabus as AI-generated item'), backgroundColor: OseeTheme.sage),
      );
      context.go('/teacher/syllabi/${widget.syllabusId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: OseeTheme.accent));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseeTheme.paper,
      appBar: AppBar(
        backgroundColor: OseeTheme.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: OseeTheme.ink),
          onPressed: () => context.go('/teacher/syllabi/${widget.syllabusId}'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MIND-MAP RECIPE', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3, color: OseeTheme.stone)),
            const SizedBox(height: 2),
            const Text('AI Material Builder', style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
            const SizedBox(height: 4),
            Container(height: 1, color: OseeTheme.gold),
          ],
        ),
      ),
      body: _recipe != null
          ? _buildRecipePreview()
          : _buildInputForm(),
    );
  }

  // ---------- Input form (remalt-style dump canvas) ----------

  Widget _buildInputForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Dump your ideas. AI generates the material.',
          style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 14, color: OseeTheme.stone, height: 1.4),
        ),
        const SizedBox(height: 20),

        // Topic
        TextField(
          controller: _topicCtl,
          decoration: const InputDecoration(
            labelText: 'TOPIC',
            labelStyle: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.stone),
            hintText: 'e.g. Conditional sentences, paraphrasing, academic vocabulary…',
            border: OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, color: OseeTheme.ink),
        ),
        const SizedBox(height: 16),

        // Notes — the "dump" canvas
        const Text('YOUR NOTES', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.stone)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: OseeTheme.cloud)),
          child: TextField(
            controller: _notesCtl,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: 'Type anything: bullet points, goals, student struggles, examples you want included, scenarios…\n\nThe more you dump, the better the AI output.',
              hintStyle: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 13, color: OseeTheme.stone.withOpacity(0.5), height: 1.5),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, color: OseeTheme.ink, height: 1.5),
          ),
        ),
        const SizedBox(height: 16),

        // Exam + level + type
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _exam,
                decoration: const InputDecoration(labelText: 'Exam', border: OutlineInputBorder(borderRadius: BorderRadius.zero)),
                items: const [
                  DropdownMenuItem(value: 'GENERAL', child: Text('General')),
                  DropdownMenuItem(value: 'TOEFL_IBT', child: Text('TOEFL iBT')),
                  DropdownMenuItem(value: 'IELTS', child: Text('IELTS')),
                  DropdownMenuItem(value: 'TOEIC', child: Text('TOEIC')),
                ],
                onChanged: (v) => setState(() => _exam = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _level,
                decoration: const InputDecoration(labelText: 'Level', border: OutlineInputBorder(borderRadius: BorderRadius.zero)),
                items: const [
                  DropdownMenuItem(value: 'A2', child: Text('A2')),
                  DropdownMenuItem(value: 'B1', child: Text('B1')),
                  DropdownMenuItem(value: 'B2', child: Text('B2')),
                  DropdownMenuItem(value: 'C1', child: Text('C1')),
                ],
                onChanged: (v) => setState(() => _level = v ?? 'B2'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _itemType,
                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder(borderRadius: BorderRadius.zero)),
                items: const [
                  DropdownMenuItem(value: 'grammar', child: Text('Grammar')),
                  DropdownMenuItem(value: 'vocabulary', child: Text('Vocab')),
                  DropdownMenuItem(value: 'reading', child: Text('Reading')),
                  DropdownMenuItem(value: 'writing', child: Text('Writing')),
                  DropdownMenuItem(value: 'speaking', child: Text('Speaking')),
                ],
                onChanged: (v) => setState(() => _itemType = v ?? 'grammar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: OseeTheme.accent, fontFamily: 'Georgia', fontSize: 12)),
          const SizedBox(height: 12),
        ],

        // Generate button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isGenerating ? null : _generate,
            icon: _isGenerating
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(
              _isGenerating ? 'GENERATING…' : 'GENERATE MATERIAL',
              style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: OseeTheme.ink,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2), side: const BorderSide(color: OseeTheme.gold, width: 1.5)),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Recipe preview ----------

  Widget _buildRecipePreview() {
    final r = _recipe!;
    final exercises = (r['exercises'] as List? ?? const []) as List;
    final vocab = (r['vocabulary'] as List? ?? const []) as List;
    final keyPoints = (r['key_points'] as List? ?? const []) as List;
    final examples = (r['examples'] as List? ?? const []) as List;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Title
        Text(r['title'] as String? ?? '—', style: const TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.w700, color: OseeTheme.ink, height: 1.2)),
        const SizedBox(height: 8),
        Text(r['summary'] as String? ?? '', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 13, color: OseeTheme.stone, height: 1.5)),
        const SizedBox(height: 12),
        Container(height: 1, color: OseeTheme.gold),
        const SizedBox(height: 20),

        // Theory
        const _SectionLabel('THEORY'),
        const SizedBox(height: 8),
        Text(
          (r['theory'] as String? ?? '').replaceAll('\\n', '\n'),
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.6),
        ),
        const SizedBox(height: 20),

        // Key points
        if (keyPoints.isNotEmpty) ...[
          const _SectionLabel('KEY POINTS'),
          const SizedBox(height: 8),
          for (final p in keyPoints)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.accent)),
                  Expanded(child: Text(p as String, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.4))),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],

        // Examples
        if (examples.isNotEmpty) ...[
          const _SectionLabel('EXAMPLES'),
          const SizedBox(height: 8),
          for (final e in examples)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: OseeTheme.sage, width: 2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((e as Map<String, dynamic>)['input'] as String? ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                  Text('→ ${e['output']}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: OseeTheme.sage)),
                  if ((e['explanation'] as String?)?.isNotEmpty ?? false)
                    Text(e['explanation'] as String, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: OseeTheme.stone)),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],

        // Exercises
        if (exercises.isNotEmpty) ...[
          const _SectionLabel('EXERCISES'),
          const SizedBox(height: 8),
          for (var i = 0; i < exercises.length; i++)
            _ExercisePreview(index: i + 1, exercise: exercises[i] as Map<String, dynamic>),
          const SizedBox(height: 20),
        ],

        // Vocabulary
        if (vocab.isNotEmpty) ...[
          const _SectionLabel('VOCABULARY'),
          const SizedBox(height: 8),
          for (final v in vocab)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: OseeTheme.cloud)),
              child: Row(
                children: [
                  Text((v as Map<String, dynamic>)['word'] as String? ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(v['definition'] as String? ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.stone))),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],

        // Practice prompt
        if ((r['practice_prompt'] as String?)?.isNotEmpty ?? false) ...[
          const _SectionLabel('PRACTICE TASK'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0x1AE63946), border: Border(left: BorderSide(color: OseeTheme.accent, width: 2))),
            child: Text(r['practice_prompt'] as String, style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 13, color: OseeTheme.ink, height: 1.5)),
          ),
          const SizedBox(height: 24),
        ],

        // Actions
        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _recipe = null),
              child: const Text('DISCARD & REDO'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveToSyllabus,
                icon: _isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                    : const Icon(Icons.save, size: 16),
                label: Text(_isSaving ? 'SAVING…' : 'SAVE TO SYLLABUS', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                style: FilledButton.styleFrom(
                  backgroundColor: OseeTheme.ink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2), side: const BorderSide(color: OseeTheme.gold, width: 1.5)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 1, color: OseeTheme.ink),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.ink)),
      ],
    );
  }
}

class _ExercisePreview extends StatefulWidget {
  const _ExercisePreview({required this.index, required this.exercise});
  final int index;
  final Map<String, dynamic> exercise;

  @override
  State<_ExercisePreview> createState() => _ExercisePreviewState();
}

class _ExercisePreviewState extends State<_ExercisePreview> {
  String? _selected;
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final type = ex['type'] as String? ?? 'short_answer';
    final question = ex['question'] as String? ?? '';
    final options = (ex['options'] as List?)?.cast<String>();
    final answer = ex['answer'] as String? ?? '';
    final explanation = ex['explanation'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: OseeTheme.cloud)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: OseeTheme.ink,
                child: Text('${widget.index}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Text(type.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: OseeTheme.stone)),
            ],
          ),
          const SizedBox(height: 8),
          Text(question, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.4)),
          if (options != null && options.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < options.length; i++)
              InkWell(
                onTap: () => setState(() => _selected = options[i]),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _selected == options[i] ? const Color(0x22E63946) : Colors.white,
                    border: Border.all(color: _selected == options[i] ? OseeTheme.accent : OseeTheme.cloud),
                  ),
                  child: Row(
                    children: [
                      Text(String.fromCharCode(65 + i), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(options[i], style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink))),
                    ],
                  ),
                ),
              ),
          ],
          if (_showAnswer) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0x226B8E7F), border: Border(left: BorderSide(color: OseeTheme.sage, width: 2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Answer: $answer', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, fontWeight: FontWeight.w700, color: OseeTheme.sage)),
                  if (explanation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(explanation, style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.stone, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() => _showAnswer = !_showAnswer),
            child: Text(_showAnswer ? 'HIDE ANSWER' : 'SHOW ANSWER', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.sage)),
          ),
        ],
      ),
    );
  }
}