import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';
import 'scrapbook_lesson.dart';

/// Student Workbook — magazine-style interactive learning reader.
///
/// Reads GET /api/student/syllabus (returns syllabi with syllabus_items, some
/// with ai_generated_content holding theory + exercises).
///
/// Layout:
///  - Masthead: "MY WORKBOOK" + syllabus name + progress strip.
///  - Chapter list (left rail / top): one entry per item.
///  - Reading pane: the selected item rendered as a workbook page —
///    theory in editorial typography, examples, exercises with tap-to-reveal
///    answers, vocabulary, and a practice prompt. Deep-link button to the
///    source platform for more practice.
///  - For items without ai_generated_content: shows the title/description
///    + deep-link to the source platform.
class StudentSyllabusPage extends ConsumerStatefulWidget {
  const StudentSyllabusPage({super.key});

  @override
  ConsumerState<StudentSyllabusPage> createState() => _StudentSyllabusPageState();
}

class _StudentSyllabusPageState extends ConsumerState<StudentSyllabusPage> {
  List<Map<String, dynamic>> _syllabi = [];
  bool _isLoading = true;
  String? _error;
  int _selectedSyllabus = 0;
  int _selectedItem = 0;
  final Set<String> _doneIds = {};

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
      final r = await dio.get('/student/syllabus');
      final list = (r.data['syllabi'] as List? ?? const []) as List;
      setState(() {
        _syllabi = list.cast<Map<String, dynamic>>();
        _isLoading = false;
        _selectedItem = 0;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load workbook';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseeTheme.paper,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: OseeTheme.ink))
          : _error != null
              ? _ErrorPanel(error: _error!, onRetry: _load)
              : _syllabi.isEmpty
                  ? _EmptyState(
                      message: "Your teacher hasn't published a workbook yet.",
                      action: TextButton(onPressed: () => context.go('/student'), child: const Text('BACK', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.accent))),
                    )
                  : _buildWorkbook(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: OseeTheme.paper,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: OseeTheme.ink), onPressed: () => context.go('/student')),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('MY WORKBOOK', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3, color: OseeTheme.stone)),
          const SizedBox(height: 2),
          Text(_currentSyllabusName(), style: const TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
          const SizedBox(height: 6),
          Container(height: 1, color: OseeTheme.gold),
        ],
      ),
      actions: [IconButton(icon: const Icon(Icons.refresh, color: OseeTheme.ink), onPressed: _load)],
    );
  }

  String _currentSyllabusName() {
    if (_syllabi.isEmpty) return '—';
    return _syllabi[_selectedSyllabus]['name'] as String? ?? '—';
  }

  List<Map<String, dynamic>> _currentItems() {
    if (_syllabi.isEmpty) return [];
    final items = (_syllabi[_selectedSyllabus]['syllabus_items'] as List? ?? const []) as List;
    return items.cast<Map<String, dynamic>>();
  }

  Widget _buildWorkbook() {
    final items = _currentItems();
    if (items.isEmpty) {
      return _EmptyState(message: 'This workbook has no units yet.', action: null);
    }
    final done = items.where((i) => _doneIds.contains(i['id'] as String)).length;
    return Column(
      children: [
        // Progress strip
        _ProgressStrip(total: items.length, done: done),
        // Multi-syllabus switcher
        if (_syllabi.length > 1) _SyllabusSwitcher(syllabi: _syllabi, selected: _selectedSyllabus, onChanged: (i) => setState(() { _selectedSyllabus = i; _selectedItem = 0; })),
        // Chapter rail + reading pane
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final isWide = c.maxWidth >= 900;
              if (isWide) {
                return Row(
                  children: [
                    SizedBox(width: 260, child: _ChapterRail(items: items, selected: _selectedItem, onSelect: (i) => setState(() => _selectedItem = i), doneIds: _doneIds)),
                    Container(width: 1, color: OseeTheme.cloud),
                    Expanded(child: _ReadingPane(item: items[_selectedItem], isDone: _doneIds.contains(items[_selectedItem]['id'] as String), onToggleDone: () => setState(() {
                      final id = items[_selectedItem]['id'] as String;
                      if (_doneIds.contains(id)) _doneIds.remove(id); else _doneIds.add(id);
                    }))),
                  ],
                );
              }
              // Narrow: stacked — chapter rail as dropdown, reading pane fills
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: OseeTheme.cloud))),
                    child: DropdownButton<int>(
                      value: _selectedItem,
                      isExpanded: true,
                      items: items.asMap().entries.map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key + 1}. ${e.value['title']}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13)))).toList(),
                      onChanged: (i) => setState(() => _selectedItem = i ?? 0),
                    ),
                  ),
                  Expanded(child: _ReadingPane(item: items[_selectedItem], isDone: _doneIds.contains(items[_selectedItem]['id'] as String), onToggleDone: () => setState(() {
                    final id = items[_selectedItem]['id'] as String;
                    if (_doneIds.contains(id)) _doneIds.remove(id); else _doneIds.add(id);
                  }))),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Chapter rail — list of units
// ============================================================

class _ChapterRail extends StatelessWidget {
  const _ChapterRail({required this.items, required this.selected, required this.onSelect, required this.doneIds});
  final List<Map<String, dynamic>> items;
  final int selected;
  final void Function(int) onSelect;
  final Set<String> doneIds;

  @override
  Widget build(BuildContext context) {
    // Group by week
    final byWeek = <String, List<int>>{};
    for (var i = 0; i < items.length; i++) {
      final week = (items[i]['section'] as String?) ?? 'week-1';
      byWeek.putIfAbsent(week, () => []).add(i);
    }
    final weeks = byWeek.keys.toList()..sort();

    return Container(
      color: const Color(0xFFEFEDE6),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: weeks.length,
        itemBuilder: (_, wi) {
          final week = weeks[wi];
          final indices = byWeek[week]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  week.replaceAll('-', ' ').toUpperCase(),
                  style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.accent),
                ),
              ),
              for (final idx in indices)
                _ChapterTile(
                  item: items[idx],
                  index: idx + 1,
                  isSelected: idx == selected,
                  isDone: doneIds.contains(items[idx]['id'] as String),
                  onTap: () => onSelect(idx),
                ),
              if (wi < weeks.length - 1) const Divider(height: 16, color: OseeTheme.cloud),
            ],
          );
        },
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.item, required this.index, required this.isSelected, required this.isDone, required this.onTap});
  final Map<String, dynamic> item;
  final int index;
  final bool isSelected;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasContent = item['ai_generated_content'] != null;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border(left: BorderSide(color: isSelected ? OseeTheme.accent : Colors.transparent, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$index.', style: TextStyle(fontFamily: 'Georgia', fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? OseeTheme.ink : OseeTheme.stone)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] as String? ?? '—',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isDone ? OseeTheme.stone : OseeTheme.ink,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasContent)
                    Text('WORKBOOK', style: TextStyle(fontFamily: 'Helvetica', fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 1, color: OseeTheme.gold)),
                ],
              ),
            ),
            if (isDone) const Icon(Icons.check_circle, size: 12, color: OseeTheme.sage),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Reading pane — the workbook page for the selected item
// ============================================================

class _ReadingPane extends StatelessWidget {
  const _ReadingPane({required this.item, required this.isDone, required this.onToggleDone});
  final Map<String, dynamic> item;
  final bool isDone;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    final content = item['ai_generated_content'] as Map<String, dynamic>?;
    final title = item['title'] as String? ?? '—';
    final desc = item['description'] as String?;
    final src = item['source_type'] as String? ?? '';
    final minutes = item['estimated_minutes'] as int?;

    if (content != null) {
      return ScrapbookLesson(
        title: content['title'] as String? ?? title,
        summary: content['summary'] as String?,
        theory: (content['theory'] as String? ?? '').replaceAll('\\n', '\n'),
        keyPoints: ((content['key_points'] as List?) ?? const []).cast<String>(),
        examples: ((content['examples'] as List?) ?? const []).cast<Map<String, dynamic>>(),
        exercises: ((content['exercises'] as List?) ?? const []).cast<Map<String, dynamic>>(),
        vocabulary: ((content['vocabulary'] as List?) ?? const []).cast<Map<String, dynamic>>(),
        practicePrompt: content['practice_prompt'] as String?,
        sourceLabel: _sourceLabel(src),
        difficulty: item['difficulty'] as String?,
        minutes: minutes,
        onDone: onToggleDone,
        isDone: isDone,
        onDeepLink: _deepLinkUrl(item) != null ? () => _openLink(context, _deepLinkUrl(item)!) : null,
        deepLinkLabel: _deepLinkLabel(src),
      );
    }

    // No AI content — simple link card
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 26, fontWeight: FontWeight.w700, color: OseeTheme.ink, height: 1.2)),
        const SizedBox(height: 8),
        Container(height: 1, color: OseeTheme.gold),
        const SizedBox(height: 16),
        if (desc != null && desc.isNotEmpty) ...[
          Text(desc, style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 14, color: OseeTheme.stone, height: 1.5)),
          const SizedBox(height: 16),
        ],
        Text('This is a practice item from ${_sourceLabel(src)}. Open the platform to start.', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5)),
        const SizedBox(height: 16),
        _DeepLinkButton(item: item),
        const SizedBox(height: 20),
        _DoneButton(isDone: isDone, onToggle: onToggleDone),
      ],
    );
  }

  String _sourceLabel(String src) {
    switch (src) {
      case 'platform_ibt': return 'iBT';
      case 'platform_itp': return 'ITP';
      case 'platform_ielts': return 'IELTS';
      case 'platform_toeic': return 'TOEIC';
      case 'edubot': return 'EduBot';
      case 'ai_generated': return 'AI';
      case 'video_lesson': return 'Video';
      case 'live_class': return 'Live';
      default: return 'Custom';
    }
  }

  String? _deepLinkUrl(Map<String, dynamic> item) {
    final url = item['source_platform_url'] as String?;
    if (url != null && url.isNotEmpty) return url;
    final src = item['source_type'] as String? ?? '';
    final matId = item['source_material_id'] as String? ?? '';
    switch (src) {
      case 'platform_ibt': return 'https://ibt.osee.co.id/material/$matId';
      case 'platform_itp': return 'https://test.osee.co.id/material/$matId';
      case 'platform_ielts': return 'https://ielts.osee.co.id/material/$matId';
      case 'platform_toeic': return 'https://toeic.osee.co.id/material/$matId';
      case 'edubot': return null;
      case 'video_lesson': return 'https://youtube.com/watch?v=$matId';
      default: return null;
    }
  }

  String? _deepLinkLabel(String src) {
    switch (src) {
      case 'platform_ibt': return 'practice on ibt';
      case 'platform_itp': return 'practice on itp';
      case 'platform_ielts': return 'practice on ielts';
      case 'platform_toeic': return 'practice on toeic';
      case 'video_lesson': return 'watch on youtube';
      case 'edubot': return null;
      default: return null;
    }
  }

  void _openLink(BuildContext context, String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Open: $url'), duration: const Duration(seconds: 4)),
    );
  }
}

// ============================================================
// Workbook page — theory + examples + exercises + vocab
// ============================================================

class _WorkbookPage extends StatelessWidget {
  const _WorkbookPage({required this.item, required this.content, required this.isDone, required this.onToggleDone});
  final Map<String, dynamic> item;
  final Map<String, dynamic> content;
  final bool isDone;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    final title = content['title'] as String? ?? item['title'] as String? ?? '—';
    final summary = content['summary'] as String?;
    final theory = (content['theory'] as String? ?? '').replaceAll('\\n', '\n');
    final keyPoints = (content['key_points'] as List? ?? const []) as List;
    final examples = (content['examples'] as List? ?? const []) as List;
    final exercises = (content['exercises'] as List? ?? const []) as List;
    final vocab = (content['vocabulary'] as List? ?? const []) as List;
    final practice = content['practice_prompt'] as String?;
    final src = item['source_type'] as String? ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
      children: [
        // Kicker
        Row(
          children: [
            Text(_sourceLabel(src).toUpperCase(), style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: OseeTheme.accent)),
            if (item['difficulty'] != null) ...[
              const Text(' · ', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, color: OseeTheme.stone)),
              Text((item['difficulty'] as String).toUpperCase(), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.stone)),
            ],
            if (item['estimated_minutes'] != null) ...[
              const Text(' · ', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, color: OseeTheme.stone)),
              Text('${item['estimated_minutes']}m', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, color: OseeTheme.stone)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Title
        Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 32, fontWeight: FontWeight.w700, color: OseeTheme.ink, height: 1.15)),
        const SizedBox(height: 8),
        Container(height: 2, color: OseeTheme.gold),
        const SizedBox(height: 16),
        // Summary
        if (summary != null && summary.isNotEmpty) ...[
          Text(summary, style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 15, color: OseeTheme.stone, height: 1.5)),
          const SizedBox(height: 20),
        ],
        // Theory
        if (theory.isNotEmpty) ...[
          const _SectionLabel('THEORY'),
          const SizedBox(height: 10),
          Text(theory, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, color: OseeTheme.ink, height: 1.7)),
          const SizedBox(height: 24),
        ],
        // Key points
        if (keyPoints.isNotEmpty) ...[
          const _SectionLabel('KEY POINTS'),
          const SizedBox(height: 10),
          for (final p in keyPoints)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 8), decoration: const BoxDecoration(color: OseeTheme.accent, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(p as String, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5))),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
        // Examples
        if (examples.isNotEmpty) ...[
          const _SectionLabel('EXAMPLES'),
          const SizedBox(height: 10),
          for (final e in examples)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, border: Border(left: BorderSide(color: OseeTheme.sage, width: 2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((e as Map<String, dynamic>)['input'] as String? ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, fontStyle: FontStyle.italic, height: 1.4)),
                  const SizedBox(height: 6),
                  Text('→ ${e['output']}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: OseeTheme.sage)),
                  if ((e['explanation'] as String?)?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(e['explanation'] as String, style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.stone, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
        // Exercises
        if (exercises.isNotEmpty) ...[
          const _SectionLabel('EXERCISES'),
          const SizedBox(height: 10),
          for (var i = 0; i < exercises.length; i++)
            _ExerciseWidget(index: i + 1, exercise: exercises[i] as Map<String, dynamic>),
          const SizedBox(height: 24),
        ],
        // Vocabulary
        if (vocab.isNotEmpty) ...[
          const _SectionLabel('VOCABULARY'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: OseeTheme.cloud)),
            child: Column(
              children: [
                for (final v in vocab)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((v as Map<String, dynamic>)['word'] as String? ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v['definition'] as String? ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, height: 1.4)),
                              if ((v['example'] as String?)?.isNotEmpty ?? false) ...[
                                const SizedBox(height: 2),
                                Text('"${v['example']}"', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.stone, height: 1.3)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        // Practice prompt
        if (practice != null && practice.isNotEmpty) ...[
          const _SectionLabel('PRACTICE TASK'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0x1AE63946), border: Border(left: BorderSide(color: OseeTheme.accent, width: 2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.edit_note, size: 20, color: OseeTheme.accent),
                const SizedBox(height: 8),
                Text(practice, style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 14, color: OseeTheme.ink, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        // Deep link + done
        _DeepLinkButton(item: item),
        const SizedBox(height: 16),
        _DoneButton(isDone: isDone, onToggle: onToggleDone),
      ],
    );
  }

  String _sourceLabel(String src) {
    switch (src) {
      case 'platform_ibt': return 'iBT';
      case 'platform_itp': return 'ITP';
      case 'platform_ielts': return 'IELTS';
      case 'platform_toeic': return 'TOEIC';
      case 'edubot': return 'EduBot';
      case 'ai_generated': return 'AI';
      case 'video_lesson': return 'Video';
      case 'live_class': return 'Live';
      default: return src;
    }
  }
}

// ============================================================
// Exercise widget — interactive, tap to reveal answer
// ============================================================

class _ExerciseWidget extends StatefulWidget {
  const _ExerciseWidget({required this.index, required this.exercise});
  final int index;
  final Map<String, dynamic> exercise;

  @override
  State<_ExerciseWidget> createState() => _ExerciseWidgetState();
}

class _ExerciseWidgetState extends State<_ExerciseWidget> {
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: OseeTheme.cloud)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Number + type badge
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: OseeTheme.ink, borderRadius: BorderRadius.circular(2)),
                  child: Center(child: Text('${widget.index}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                ),
                const SizedBox(width: 8),
                Text(type.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.stone)),
              ],
            ),
            const SizedBox(height: 10),
            // Question
            Text(question, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, color: OseeTheme.ink, height: 1.4)),
            // Options (multiple choice)
            if (options != null && options.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (var i = 0; i < options.length; i++)
                InkWell(
                  onTap: () => setState(() => _selected = options[i]),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selected == options[i] ? const Color(0x22E63946) : Colors.transparent,
                      border: Border.all(color: _selected == options[i] ? OseeTheme.accent : OseeTheme.cloud),
                    ),
                    child: Row(
                      children: [
                        Text(String.fromCharCode(65 + i), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(options[i], style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink))),
                      ],
                    ),
                  ),
                ),
            ],
            // Answer reveal
            if (_showAnswer) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0x226B8E7F), border: Border(left: BorderSide(color: OseeTheme.sage, width: 2))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: OseeTheme.sage),
                        const SizedBox(width: 6),
                        Expanded(child: Text(answer, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: OseeTheme.sage))),
                      ],
                    ),
                    if (explanation.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(explanation, style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.stone, fontStyle: FontStyle.italic, height: 1.4)),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showAnswer = !_showAnswer),
                icon: Icon(_showAnswer ? Icons.visibility_off : Icons.visibility, size: 14, color: OseeTheme.sage),
                label: Text(_showAnswer ? 'HIDE ANSWER' : 'SHOW ANSWER', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.sage)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Helpers
// ============================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 14, height: 1, color: OseeTheme.ink),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2.5, color: OseeTheme.ink)),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: OseeTheme.cloud, thickness: 1, height: 1)),
      ],
    );
  }
}

class _DeepLinkButton extends StatelessWidget {
  const _DeepLinkButton({required this.item});
  final Map<String, dynamic> item;

  String? _url() {
    final url = item['source_platform_url'] as String?;
    if (url != null && url.isNotEmpty) return url;
    final src = item['source_type'] as String? ?? '';
    final matId = item['source_material_id'] as String? ?? '';
    switch (src) {
      case 'platform_ibt': return 'https://ibt.osee.co.id/material/$matId';
      case 'platform_itp': return 'https://test.osee.co.id/material/$matId';
      case 'platform_ielts': return 'https://ielts.osee.co.id/material/$matId';
      case 'platform_toeic': return 'https://toeic.osee.co.id/material/$matId';
      case 'edubot': return null;
      case 'video_lesson': return 'https://youtube.com/watch?v=$matId';
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _url();
    final src = item['source_type'] as String? ?? '';
    if (url == null && src == 'edubot') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0x1A6B8E7F), border: Border.all(color: OseeTheme.sage)),
        child: Row(
          children: [
            const Icon(Icons.smart_toy, size: 16, color: OseeTheme.sage),
            const SizedBox(width: 10),
            Expanded(child: Text('Open EduBot in Telegram for more practice.', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 12, color: OseeTheme.stone))),
          ],
        ),
      );
    }
    if (url == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open: $url'), duration: const Duration(seconds: 4))),
        icon: const Icon(Icons.open_in_new, size: 14),
        label: Text('PRACTICE ON ${_label(src)}', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        style: FilledButton.styleFrom(backgroundColor: OseeTheme.ink, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
      ),
    );
  }

  String _label(String src) {
    switch (src) {
      case 'platform_ibt': return 'iBT';
      case 'platform_itp': return 'ITP';
      case 'platform_ielts': return 'IELTS';
      case 'platform_toeic': return 'TOEIC';
      case 'video_lesson': return 'YOUTUBE';
      default: return 'PLATFORM';
    }
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.isDone, required this.onToggle});
  final bool isDone;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onToggle,
        icon: Icon(isDone ? Icons.undo : Icons.check_circle_outline, size: 16, color: OseeTheme.sage),
        label: Text(isDone ? 'MARK AS NOT DONE' : 'MARK AS DONE', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.sage)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: OseeTheme.sage), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.total, required this.done});
  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (done / total * 100).round() : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: OseeTheme.cloud))),
      child: Row(
        children: [
          Text('$done / $total done', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
          const SizedBox(width: 16),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(1), child: LinearProgressIndicator(value: total > 0 ? done / total : 0, minHeight: 6, color: OseeTheme.sage, backgroundColor: OseeTheme.cloud))),
          const SizedBox(width: 12),
          Text('$pct%', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: OseeTheme.sage)),
        ],
      ),
    );
  }
}

class _SyllabusSwitcher extends StatelessWidget {
  const _SyllabusSwitcher({required this.syllabi, required this.selected, required this.onChanged});
  final List<Map<String, dynamic>> syllabi;
  final int selected;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: OseeTheme.cloud))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < syllabi.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              ChoiceChip(
                label: Text(syllabi[i]['name'] as String? ?? '—', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, color: i == selected ? Colors.white : OseeTheme.ink)),
                selected: i == selected,
                selectedColor: OseeTheme.ink,
                onSelected: (_) => onChanged(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.book_outlined, size: 56, color: OseeTheme.cloud),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 15, color: OseeTheme.stone, height: 1.5), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: OseeTheme.accent),
          const SizedBox(height: 16),
          Text(error, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, color: OseeTheme.ink)),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}