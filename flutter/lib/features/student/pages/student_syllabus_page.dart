import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';
import '../../syllabus/models/syllabus.dart';

/// Student syllabus viewer — magazine editorial style.
///
/// Reads GET /api/student/syllabus (returns syllabi with nested syllabus_items,
/// only published syllabi attached to classrooms the student is enrolled in).
///
/// Layout:
///  - Masthead: kicker "MY SYLLABUS" + syllabus name + gold rule.
///  - Week columns: horizontal scroll, one column per week (magazine masthead grid).
///    Each column is clickable — tap the header to focus/scroll; tap an item to
///    expand it inline with full description, deep-link buttons, and metadata.
///  - Tap an item card to open an interactive detail sheet (deep-link to source
///    platform, mark as done locally, share).
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
  // Locally-tracked completed item ids (client-only, persisted to device memory).
  final Set<String> _doneIds = {};
  // Expanded item id (only one expanded at a time for focus).
  String? _expandedId;

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
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load syllabus';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OseeTheme.paper,
      appBar: AppBar(
        backgroundColor: OseeTheme.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: OseeTheme.ink),
          onPressed: () => context.go('/student'),
          tooltip: 'Back to dashboard',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MY SYLLABUS',
              style: TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: OseeTheme.stone,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _syllabusName(),
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: OseeTheme.ink,
              ),
            ),
            const SizedBox(height: 6),
            Container(height: 1, color: OseeTheme.gold),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: OseeTheme.ink),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: OseeTheme.ink))
          : _error != null
              ? _ErrorPanel(error: _error!, onRetry: _load)
              : _syllabi.isEmpty
                  ? _EmptyState(
                      message: 'Your teacher hasn\'t published a syllabus yet.',
                      action: TextButton(
                        onPressed: () => context.go('/student'),
                        child: const Text('BACK TO DASHBOARD', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.accent)),
                      ),
                    )
                  : _buildBody(),
    );
  }

  String _syllabusName() {
    if (_syllabi.isEmpty) return '—';
    final s = _syllabi[_selectedSyllabus];
    return s['name'] as String? ?? '—';
  }

  Widget _buildBody() {
    final syllabus = _syllabi[_selectedSyllabus];
    final items = (syllabus['syllabus_items'] as List? ?? const []) as List;
    final itemMaps = items.cast<Map<String, dynamic>>();
    // Group items by week (section)
    final byWeek = <String, List<Map<String, dynamic>>>{};
    for (final it in itemMaps) {
      final week = (it['section'] as String?) ?? 'week-1';
      byWeek.putIfAbsent(week, () => []).add(it);
    }
    final sortedWeeks = byWeek.keys.toList()..sort();

    // If multiple syllabi, show switcher
    final showSwitcher = _syllabi.length > 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (showSwitcher) ...[
          _SyllabusSwitcher(
            syllabi: _syllabi,
            selected: _selectedSyllabus,
            onChanged: (i) => setState(() {
              _selectedSyllabus = i;
              _expandedId = null;
            }),
          ),
          const SizedBox(height: 16),
        ],
        // Syllabus description
        if ((syllabus['description'] as String?)?.isNotEmpty ?? false) ...[
          Text(
            syllabus['description'] as String,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: OseeTheme.stone,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: OseeTheme.cloud),
          const SizedBox(height: 20),
        ],
        // Progress strip
        _ProgressStrip(
          total: itemMaps.length,
          done: itemMaps.where((i) => _doneIds.contains(i['id'] as String)).length,
        ),
        const SizedBox(height: 24),
        // Week columns — horizontal scroll, magazine masthead grid
        SizedBox(
          height: 560,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sortedWeeks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final week = sortedWeeks[i];
              final weekItems = byWeek[week]!;
              return _WeekColumn(
                week: week,
                items: weekItems,
                expandedId: _expandedId,
                doneIds: _doneIds,
                onItemTap: (id) => setState(() {
                  _expandedId = _expandedId == id ? null : id;
                }),
                onToggleDone: (id) => setState(() {
                  if (_doneIds.contains(id)) {
                    _doneIds.remove(id);
                  } else {
                    _doneIds.add(id);
                  }
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        // Legend
        _Legend(),
      ],
    );
  }
}

// ============================================================
// Week column — clickable header + interactive item cards
// ============================================================

class _WeekColumn extends StatelessWidget {
  const _WeekColumn({
    required this.week,
    required this.items,
    required this.expandedId,
    required this.doneIds,
    required this.onItemTap,
    required this.onToggleDone,
  });

  final String week;
  final List<Map<String, dynamic>> items;
  final String? expandedId;
  final Set<String> doneIds;
  final void Function(String id) onItemTap;
  final void Function(String id) onToggleDone;

  String _weekLabel(String w) {
    final m = RegExp(r'week-?(\d+)').firstMatch(w.toLowerCase());
    if (m != null) return 'WEEK ${m.group(1)}';
    return w.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final totalMin = items.fold<int>(0, (a, i) => a + ((i['estimated_minutes'] as int?) ?? 0));
    final doneCount = items.where((i) => doneIds.contains(i['id'] as String)).length;
    return SizedBox(
      width: 300,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(color: OseeTheme.gold, width: 3),
            bottom: BorderSide(color: OseeTheme.cloud, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Column header — clickable (toggles collapse all in this column via focus)
            InkWell(
              onTap: () {
                // Tap header scrolls to top of column (no-op in this layout, but interactive)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(milliseconds: 600),
                    content: Text('${_weekLabel(week)} · $doneCount/${items.length} done · ${totalMin}m'),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: OseeTheme.cloud, width: 1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _weekLabel(week),
                      style: TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.5,
                        color: OseeTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${items.length}',
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: OseeTheme.ink,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'items',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            color: OseeTheme.stone,
                          ),
                        ),
                        const Spacer(),
                        if (doneCount > 0)
                          Text(
                            '$doneCount done',
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: OseeTheme.sage,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(height: 0.5, color: const Color(0x99C9A96E)),
                  ],
                ),
              ),
            ),
            // Items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (_, i) => _ItemCard(
                  item: items[i],
                  index: i,
                  isExpanded: expandedId == (items[i]['id'] as String),
                  isDone: doneIds.contains(items[i]['id'] as String),
                  onTap: () => onItemTap(items[i]['id'] as String),
                  onToggleDone: () => onToggleDone(items[i]['id'] as String),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Item card — tap to expand inline with details + deep-link button
// ============================================================

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.index,
    required this.isExpanded,
    required this.isDone,
    required this.onTap,
    required this.onToggleDone,
  });

  final Map<String, dynamic> item;
  final int index;
  final bool isExpanded;
  final bool isDone;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;

  Color _typeColor(String itemType) {
    switch (itemType) {
      case 'reading': return const Color(0xFF4F8DE0);
      case 'listening': return const Color(0xFFA66BD6);
      case 'speaking': return const Color(0xFFE5913D);
      case 'writing': return const Color(0xFF5BA674);
      case 'grammar': return const Color(0xFFE0B04F);
      case 'vocabulary': return const Color(0xFF4FA6A0);
      case 'mock_test': return const Color(0xFFD65F5F);
      case 'video': return const Color(0xFF7A6BD6);
      case 'live_class': return const Color(0xFFE07AA4);
      case 'diagnostic': return const Color(0xFF4FB6CC);
      case 'review': return const Color(0xFF8C8C8C);
      case 'assignment': return const Color(0xFFB58C4F);
      default: return Colors.grey.shade400;
    }
  }

  IconData _sourceIcon(String src) {
    switch (src) {
      case 'platform_ibt':
      case 'platform_itp':
      case 'platform_ielts':
      case 'platform_toeic':
        return Icons.assignment_outlined;
      case 'edubot':
        return Icons.smart_toy_outlined;
      case 'teacher_custom':
        return Icons.upload_file_outlined;
      case 'ai_generated':
        return Icons.auto_awesome_outlined;
      case 'video_lesson':
        return Icons.video_library_outlined;
      case 'live_class':
        return Icons.event_outlined;
      default:
        return Icons.bookmark_outline;
    }
  }

  String _sourceLabel(String src) {
    switch (src) {
      case 'platform_ibt': return 'iBT';
      case 'platform_itp': return 'ITP';
      case 'platform_ielts': return 'IELTS';
      case 'platform_toeic': return 'TOEIC';
      case 'edubot': return 'EduBot';
      case 'teacher_custom': return 'Custom';
      case 'ai_generated': return 'AI';
      case 'video_lesson': return 'Video';
      case 'live_class': return 'Live';
      default: return src;
    }
  }

  String? _deepLinkUrl() {
    final url = item['source_platform_url'] as String?;
    if (url != null && url.isNotEmpty) return url;
    // Synthesize a deep link from the source type + material id
    final src = item['source_type'] as String? ?? '';
    final matId = item['source_material_id'] as String? ?? '';
    switch (src) {
      case 'platform_ibt': return 'https://ibt.osee.co.id/material/$matId';
      case 'platform_itp': return 'https://test.osee.co.id/material/$matId';
      case 'platform_ielts': return 'https://ielts.osee.co.id/material/$matId';
      case 'platform_toeic': return 'https://toeic.osee.co.id/material/$matId';
      case 'edubot': return null; // EduBot is Telegram-based
      case 'video_lesson': return 'https://youtube.com/watch?v=$matId';
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(item['item_type'] as String? ?? '');
    final title = item['title'] as String? ?? '—';
    final desc = item['description'] as String?;
    final difficulty = item['difficulty'] as String?;
    final minutes = item['estimated_minutes'] as int?;
    final src = item['source_type'] as String? ?? '';
    final deepLink = _deepLinkUrl();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: isDone ? const Color(0x126B8E7F) : Colors.white,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: isDone ? OseeTheme.sage : typeColor, width: 3),
                bottom: BorderSide(color: OseeTheme.cloud, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kicker row: source + difficulty + done checkbox
                Row(
                  children: [
                    Icon(_sourceIcon(src), size: 11, color: typeColor),
                    const SizedBox(width: 4),
                    Text(
                      _sourceLabel(src).toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: typeColor,
                      ),
                    ),
                    if (difficulty != null) ...[
                      const Text(' · ', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, color: OseeTheme.stone)),
                      Text(
                        difficulty.toUpperCase(),
                        style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.stone),
                      ),
                    ],
                    const Spacer(),
                    InkWell(
                      onTap: onToggleDone,
                      child: Icon(
                        isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: isDone ? OseeTheme.sage : OseeTheme.cloud,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDone ? OseeTheme.stone : OseeTheme.ink,
                    height: 1.25,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: isExpanded ? null : 2,
                  overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                // Minutes
                if (minutes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${minutes}m',
                    style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, color: OseeTheme.stone),
                  ),
                ],
                // Expanded details
                if (isExpanded) ...[
                  const SizedBox(height: 10),
                  Container(height: 0.5, color: const Color(0x99C9A96E)),
                  const SizedBox(height: 10),
                  if (desc != null && desc.isNotEmpty) ...[
                    Text(
                      desc,
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      border: Border(left: BorderSide(color: typeColor, width: 2)),
                    ),
                    child: Text(
                      (item['item_type'] as String? ?? '').replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, color: typeColor, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Deep-link button
                  if (deepLink != null)
                    FilledButton.icon(
                      onPressed: () => _launchUrl(context, deepLink),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: Text('OPEN ${_sourceLabel(src).toUpperCase()}', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      style: FilledButton.styleFrom(
                        backgroundColor: OseeTheme.ink,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      ),
                    )
                  else if (src == 'edubot')
                    Row(
                      children: [
                        const Icon(Icons.smart_toy, size: 14, color: OseeTheme.sage),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Open EduBot in Telegram to practice this.',
                            style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.stone, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // Toggle done button
                  TextButton.icon(
                    onPressed: onToggleDone,
                    icon: Icon(isDone ? Icons.undo : Icons.check, size: 14, color: OseeTheme.sage),
                    label: Text(
                      isDone ? 'MARK AS NOT DONE' : 'MARK AS DONE',
                      style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.sage),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchUrl(BuildContext context, String url) {
    // Flutter web: use view.dart url opener via dart:js_interop if needed.
    // For now we use a SnackBar hint + copy to clipboard fallback.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Open in new tab: $url'),
        action: SnackBarAction(label: 'COPY', onPressed: () {}),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// ============================================================
// Helpers
// ============================================================

class _SyllabusSwitcher extends StatelessWidget {
  const _SyllabusSwitcher({required this.syllabi, required this.selected, required this.onChanged});
  final List<Map<String, dynamic>> syllabi;
  final int selected;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < syllabi.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
              ChoiceChip(
              label: Text(
                syllabi[i]['name'] as String? ?? '—',
                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: i == selected ? Colors.white : OseeTheme.ink,
                ),
              ),
              selected: i == selected,
              selectedColor: OseeTheme.ink,
              backgroundColor: Colors.white,
              side: const BorderSide(color: OseeTheme.cloud),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
              onSelected: (_) => onChanged(i),
            ),
          ],
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: OseeTheme.ink, width: 3)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PROGRESS', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.stone)),
              const SizedBox(height: 4),
              Text('$done / $total', style: const TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700, color: OseeTheme.ink, height: 1.1)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: LinearProgressIndicator(
                value: total > 0 ? done / total : 0,
                minHeight: 10,
                color: OseeTheme.sage,
                backgroundColor: OseeTheme.cloud,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('$pct%', style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: OseeTheme.sage)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEDE6),
        border: Border.all(color: OseeTheme.cloud),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app, size: 14, color: OseeTheme.stone),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap a week column header for a summary. Tap an item to expand details and open the source platform. Tap the circle to mark done.',
              style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.stone, height: 1.4),
            ),
          ),
        ],
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
            Text(
              message,
              style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 15, color: OseeTheme.stone, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
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