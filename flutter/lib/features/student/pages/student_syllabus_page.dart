import 'dart:html' as html;
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
///  - Search bar to filter chapters.
///  - Chapter list (left rail / top): one entry per item.
///  - Reading pane: the selected item rendered as a workbook page.
///  - Prev/next chapter navigation at the bottom.
///  - Done state persisted to localStorage.
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDoneState();
    _load();
  }

  void _loadDoneState() {
    try {
      final stored = html.window.localStorage['doneIds'];
      if (stored != null && stored.isNotEmpty) {
        final ids = stored.split(',');
        _doneIds.addAll(ids.where((s) => s.isNotEmpty));
      }
    } catch (_) {}
  }

  void _saveDoneState() {
    try {
      html.window.localStorage['doneIds'] = _doneIds.join(',');
    } catch (_) {}
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

  void _toggleDone(String id) {
    setState(() {
      if (_doneIds.contains(id)) {
        _doneIds.remove(id);
      } else {
        _doneIds.add(id);
      }
    });
    _saveDoneState();
  }

  void _goToItem(int index) {
    final items = _currentFilteredItems();
    if (index >= 0 && index < items.length) {
      setState(() => _selectedItem = _currentItems().indexOf(items[index]));
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
      bottomNavigationBar: _buildBottomNav(1),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: OseeTheme.paper,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(icon: const Icon(Icons.arrow_back, color: OseeTheme.ink), onPressed: () => context.go('/student'), tooltip: 'Back to dashboard'),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('MY WORKBOOK', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 3, color: OseeTheme.ink)),
          const SizedBox(height: 2),
          Text(_currentSyllabusName(), style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
          const SizedBox(height: 4),
          Container(height: 1, color: OseeTheme.gold),
        ],
      ),
      actions: [IconButton(icon: const Icon(Icons.refresh, color: OseeTheme.ink), onPressed: _load, tooltip: 'Refresh')],
    );
  }

  Widget _buildBottomNav(int selected) {
    final items = [
      {'label': 'Dashboard', 'icon': Icons.home_outlined, 'route': '/student', 'index': 0},
      {'label': 'Workbook', 'icon': Icons.menu_book_outlined, 'route': '/student/syllabus', 'index': 1},
      {'label': 'Practice', 'icon': Icons.quiz_outlined, 'route': '/student/practice', 'index': 2},
      {'label': 'Profile', 'icon': Icons.person_outline, 'route': '/student/profile', 'index': 3},
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: OseeTheme.ink, width: 2))),
      child: Row(
        children: items.map((item) {
          final isActive = item['index'] == selected;
          return Expanded(
            child: InkWell(
              onTap: () => context.go(item['route'] as String),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item['icon'] as IconData, size: 20, color: isActive ? OseeTheme.accent : OseeTheme.stone),
                    const SizedBox(height: 2),
                    Text((item['label'] as String).toUpperCase(), style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: isActive ? OseeTheme.accent : OseeTheme.stone)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
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

  List<Map<String, dynamic>> _currentFilteredItems() {
    final items = _currentItems();
    if (_searchQuery.isEmpty) return items;
    return items.where((item) {
      final title = (item['title'] as String? ?? '').toLowerCase();
      final desc = (item['description'] as String? ?? '').toLowerCase();
      return title.contains(_searchQuery.toLowerCase()) || desc.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Widget _buildWorkbook() {
    final items = _currentItems();
    if (items.isEmpty) {
      return const _EmptyState(message: 'This workbook has no units yet.', action: null);
    }
    final filtered = _currentFilteredItems();
    final done = items.where((i) => _doneIds.contains(i['id'] as String)).length;
    return Column(
      children: [
        // Progress strip
        _ProgressStrip(total: items.length, done: done),
        // Search bar
        _SearchBar(
          query: _searchQuery,
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
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
                    SizedBox(width: 260, child: _ChapterRail(items: filtered, selected: _selectedItem >= filtered.length ? 0 : _selectedItem, onSelect: (i) => setState(() => _selectedItem = _currentItems().indexOf(filtered[i])), doneIds: _doneIds)),
                    Container(width: 1, color: OseeTheme.cloud),
                    Expanded(child: _ReadingPane(
                      item: items[_selectedItem.clamp(0, items.length - 1)],
                      isDone: _doneIds.contains(items[_selectedItem.clamp(0, items.length - 1)]['id'] as String),
                      onToggleDone: () => _toggleDone(items[_selectedItem.clamp(0, items.length - 1)]['id'] as String),
                      onPrev: _selectedItem > 0 ? () => setState(() => _selectedItem--) : null,
                      onNext: _selectedItem < items.length - 1 ? () => setState(() => _selectedItem++) : null,
                    )),
                  ],
                );
              }
              // Narrow: stacked — chapter rail as styled dropdown, reading pane fills
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: OseeTheme.cloud))),
                    child: DropdownButton<int>(
                      value: _selectedItem,
                      isExpanded: true,
                      underline: const SizedBox(),
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink),
                      icon: const Icon(Icons.expand_more, color: OseeTheme.ink),
                      dropdownColor: Colors.white,
                      items: items.asMap().entries.map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key + 1}. ${e.value['title']}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink)))).toList(),
                      onChanged: (i) => setState(() => _selectedItem = i ?? 0),
                    ),
                  ),
                  Expanded(child: _ReadingPane(
                    item: items[_selectedItem.clamp(0, items.length - 1)],
                    isDone: _doneIds.contains(items[_selectedItem.clamp(0, items.length - 1)]['id'] as String),
                    onToggleDone: () => _toggleDone(items[_selectedItem.clamp(0, items.length - 1)]['id'] as String),
                    onPrev: _selectedItem > 0 ? () => setState(() => _selectedItem--) : null,
                    onNext: _selectedItem < items.length - 1 ? () => setState(() => _selectedItem++) : null,
                  )),
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
// Chapter rail — list of units with search results
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
      child: items.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('No matching chapters.', style: TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink.withValues(alpha: 0.5), fontStyle: FontStyle.italic))))
          : ListView.builder(
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
                      child: Text(week.replaceAll('-', ' ').toUpperCase(), style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.accent)),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          border: Border(left: BorderSide(color: isSelected ? OseeTheme.accent : Colors.transparent, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$index.', style: TextStyle(fontFamily: 'Georgia', fontSize: 12, fontWeight: FontWeight.w700, color: isSelected ? OseeTheme.ink : OseeTheme.ink.withValues(alpha: 0.6))),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] as String? ?? '—',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isDone ? OseeTheme.ink.withValues(alpha: 0.5) : OseeTheme.ink,
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
            if (isDone) const Icon(Icons.check_circle, size: 14, color: OseeTheme.sage),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Search bar
// ============================================================

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.query, required this.onChanged});
  final String query;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: OseeTheme.cloud))),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search chapters…',
          hintStyle: TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink.withValues(alpha: 0.4), fontStyle: FontStyle.italic),
          prefixIcon: Icon(Icons.search, size: 16, color: OseeTheme.stone),
          border: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.cloud)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.ink, width: 2)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink),
      ),
    );
  }
}

// ============================================================
// Reading pane — the workbook page for the selected item
// ============================================================

class _ReadingPane extends StatelessWidget {
  const _ReadingPane({required this.item, required this.isDone, required this.onToggleDone, this.onPrev, this.onNext});
  final Map<String, dynamic> item;
  final bool isDone;
  final VoidCallback onToggleDone;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

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
        onPrev: onPrev,
        onNext: onNext,
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
          Text(desc, style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 14, color: OseeTheme.ink.withValues(alpha: 0.6), height: 1.5)),
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
    try {
      html.window.open(url, '_blank');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open: $url'), duration: const Duration(seconds: 4)));
    }
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
        decoration: BoxDecoration(color: OseeTheme.sage.withValues(alpha: 0.08), border: Border.all(color: OseeTheme.sage)),
        child: Row(
          children: [
            const Icon(Icons.smart_toy, size: 16, color: OseeTheme.sage),
            const SizedBox(width: 10),
            Expanded(child: Text('Open EduBot in Telegram for more practice.', style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 12, color: OseeTheme.ink))),
          ],
        ),
      );
    }
    if (url == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          try { html.window.open(url, '_blank'); } catch (_) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open: $url'), duration: const Duration(seconds: 4)));
          }
        },
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
              InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: i == selected ? OseeTheme.ink : Colors.white,
                    border: Border.all(color: i == selected ? OseeTheme.ink : OseeTheme.cloud),
                  ),
                  child: Text(syllabi[i]['name'] as String? ?? '—', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: i == selected ? Colors.white : OseeTheme.ink)),
                ),
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
            Text(message, style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 15, color: OseeTheme.ink.withValues(alpha: 0.5), height: 1.5), textAlign: TextAlign.center),
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
          FilledButton(onPressed: onRetry, style: FilledButton.styleFrom(backgroundColor: OseeTheme.ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))), child: const Text('Retry')),
        ],
      ),
    );
  }
}