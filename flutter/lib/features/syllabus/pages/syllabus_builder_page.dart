import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';
import '../models/catalog.dart';
import '../models/syllabus.dart';
import '../models/labels.dart';
import '../providers/catalog_provider.dart';
import '../providers/syllabus_repository.dart';

/// Vertical "Notion timeline" syllabus builder.
///
/// Layout: magazine AppBar with gold rule + "PUBLISH" stamp, then a vertical,
/// collapsible week list (Week 1 → Week N). No horizontal scrolling anywhere.
///
/// - Each week is a collapsible section: header shows week number, item count,
///   and total estimated minutes; body lists full-width item rows.
/// - Within a week, items reorder vertically via ReorderableListView.
/// - Moving an item between weeks uses the row's overflow menu ("Move to week →").
/// - "Add material" opens a modal bottom sheet (or end drawer on wide screens)
///   containing the catalog; tapping an entry appends it to that week.
/// - Tapping a row opens the Planka-style detail drawer (labels, comments,
///   attachments, rename, delete).
/// - PUBLISH batch-saves via PUT /api/teacher/syllabi/:id/items.
class SyllabusBuilderPage extends ConsumerStatefulWidget {
  const SyllabusBuilderPage({super.key, required this.syllabusId});
  final String syllabusId;

  @override
  ConsumerState<SyllabusBuilderPage> createState() =>
      _SyllabusBuilderPageState();
}

class _SyllabusBuilderPageState extends ConsumerState<SyllabusBuilderPage> {
  static const int _initialWeeks = 4;
  late List<List<SyllabusItem>> _weeks;
  Syllabus? _syllabus;
  bool _isSaving = false;
  bool _isDirty = false;
  String? _error;

  /// Which weeks are expanded. Default: all expanded.
  final Set<int> _collapsedWeeks = <int>{};

  /// Detail drawer state (Planka drawer).
  SyllabusItem? _drawerItem;
  int _drawerWeek = -1;
  int _drawerIdx = -1;

  @override
  void initState() {
    super.initState();
    _weeks = List.generate(_initialWeeks, (_) => <SyllabusItem>[]);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final detail = await ref
          .read(syllabusRepositoryProvider)
          .getSyllabus(widget.syllabusId);
      _syllabus = detail.syllabus;
      // Grow the week list to fit the largest referenced week.
      var maxWeek = _initialWeeks;
      for (final item in detail.items) {
        final wk = _weekForSection(item.section) + 1;
        if (wk > maxWeek) maxWeek = wk;
      }
      _weeks = List.generate(maxWeek, (_) => <SyllabusItem>[]);
      for (final item in detail.items) {
        _weeks[_weekForSection(item.section)].add(item);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load syllabus: $e');
    }
  }

  int _weekForSection(String? section) {
    if (section == null || section.isEmpty) return 0;
    final wk = RegExp(r'week-?(\d+)').firstMatch(section.toLowerCase());
    if (wk != null) {
      final n = int.parse(wk.group(1)!);
      if (n >= 1 && n <= _weeks.length) return n - 1;
    }
    return 0;
  }

  String _weekSectionLabel(int week) => 'week-${week + 1}';

  int _weekMinutes(int week) =>
      _weeks[week].fold(0, (a, i) => a + (i.estimatedMinutes ?? 0));

  // ---------------------- mutations ----------------------

  void _onCatalogAdd(CatalogEntry entry, int week) {
    final tempId =
        'local:${entry.sourceType}:${entry.materialId}:${DateTime.now().microsecondsSinceEpoch}';
    final autoLabel = <String>[];
    final matching = SyllabusLabel.preset.where((l) => l.id == entry.itemType);
    if (matching.isNotEmpty) autoLabel.add(matching.first.id);

    final newItem = SyllabusItem(
      id: tempId,
      syllabusId: widget.syllabusId,
      sortOrder: _weeks[week].length,
      sourceType: entry.sourceType,
      sourceMaterialId: entry.materialId,
      sourcePlatformUrl: null,
      title: entry.title,
      description: entry.description,
      itemType: entry.itemType,
      section: _weekSectionLabel(week),
      difficulty: entry.difficulty,
      estimatedMinutes: entry.estimatedMinutes,
      flavorTag: null,
      temperatureTag: null,
      unlockedAt: null,
      labelIds: autoLabel,
    );
    setState(() {
      _weeks[week].add(newItem);
      _isDirty = true;
    });
  }

  void _reorderWithinWeek(int week, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _weeks[week].removeAt(oldIndex);
      _weeks[week].insert(newIndex, item);
      // Re-stamp sortOrder + section for cleanliness.
      for (var i = 0; i < _weeks[week].length; i++) {
        _weeks[week][i] = _weeks[week][i]
            .copyWith(sortOrder: i, section: _weekSectionLabel(week));
      }
      _isDirty = true;
    });
  }

  void _moveItemToWeek(int fromWeek, int idx, int toWeek) {
    setState(() {
      final item = _weeks[fromWeek].removeAt(idx);
      _weeks[toWeek]
          .add(item.copyWith(section: _weekSectionLabel(toWeek), sortOrder: _weeks[toWeek].length));
      _isDirty = true;
    });
  }

  void _duplicateItem(int week, int idx) {
    final src = _weeks[week][idx];
    final copy = SyllabusItem(
      id: 'local:dup:${DateTime.now().microsecondsSinceEpoch}',
      syllabusId: widget.syllabusId,
      sortOrder: idx + 1,
      sourceType: src.sourceType,
      sourceMaterialId: src.sourceMaterialId,
      sourcePlatformUrl: src.sourcePlatformUrl,
      title: '${src.title} (copy)',
      description: src.description,
      itemType: src.itemType,
      section: _weekSectionLabel(week),
      difficulty: src.difficulty,
      estimatedMinutes: src.estimatedMinutes,
      flavorTag: src.flavorTag,
      temperatureTag: src.temperatureTag,
      unlockedAt: src.unlockedAt,
      labelIds: List.of(src.labelIds),
    );
    setState(() {
      _weeks[week].insert(idx + 1, copy);
      _isDirty = true;
    });
  }

  void _removeItem(int week, int idx) {
    setState(() {
      _weeks[week].removeAt(idx);
      _isDirty = true;
    });
  }

  void _renameItem(int week, int idx) {
    final current = _weeks[week][idx];
    final ctl = TextEditingController(text: current.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename item'),
        content: TextField(controller: ctl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctl.text.trim();
              if (v.isNotEmpty) {
                setState(() {
                  _weeks[week][idx] = current.copyWith(title: v);
                  _isDirty = true;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _toggleLabel(int week, int idx, String labelId) {
    final current = _weeks[week][idx];
    final has = current.labelIds.contains(labelId);
    final next = has
        ? current.labelIds.where((l) => l != labelId).toList(growable: false)
        : [...current.labelIds, labelId];
    setState(() {
      _weeks[week][idx] = current.copyWith(labelIds: next);
      _isDirty = true;
    });
  }

  void _addComment(int week, int idx, String text) {
    final current = _weeks[week][idx];
    final c = SyllabusComment(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      itemId: current.id,
      authorId: _syllabus?.teacherId ?? 'me',
      authorName: 'You',
      text: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _weeks[week][idx] = current.copyWith(comments: [...current.comments, c]);
      _isDirty = true;
    });
  }

  void _addAttachment(int week, int idx, String url, [String? filename]) {
    final current = _weeks[week][idx];
    final a = SyllabusAttachment(
      id: 'a_${DateTime.now().microsecondsSinceEpoch}',
      itemId: current.id,
      url: url,
      filename: filename ?? url.split('/').lastOrNull ?? url,
      mimeType: null,
      sizeBytes: null,
      createdAt: DateTime.now(),
    );
    setState(() {
      _weeks[week][idx] =
          current.copyWith(attachments: [...current.attachments, a]);
      _isDirty = true;
    });
  }

  void _addWeek() {
    setState(() {
      _weeks.add(<SyllabusItem>[]);
      _isDirty = true;
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final flat = <SyllabusItem>[];
      for (var w = 0; w < _weeks.length; w++) {
        for (var i = 0; i < _weeks[w].length; i++) {
          final item = _weeks[w][i].copyWith(
            sortOrder: flat.length,
            section: _weekSectionLabel(w),
          );
          flat.add(item);
        }
      }
      await ref.read(syllabusRepositoryProvider).saveItems(widget.syllabusId, flat);

      // Publish syllabus so students can see it.
      final dio = ApiClient.create();
      await dio.post(
        '/teacher/syllabi/${widget.syllabusId}/publish',
        data: {'published': true},
      );

      setState(() {
        _isDirty = false;
        _syllabus = _syllabus?.copyWith(isPublished: true);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syllabus published! Students can now see it.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------- UI ----------------------

  @override
  Widget build(BuildContext context) {
    final loaded = _syllabus != null;
    return Scaffold(
      backgroundColor: OseeTheme.paper,
      appBar: _buildMagazineAppBar(),
      body: _error != null
          ? _ErrorPanel(message: _error!, onRetry: () => setState(() => _error = null))
          : loaded
              ? _buildTimeline()
              : const Center(child: CircularProgressIndicator()),
      endDrawer: _drawerItem != null
          ? _ItemDetailDrawer(
              item: _drawerItem!,
              onClose: () => setState(() => _drawerItem = null),
              onToggleLabel: (labelId) {
                if (_drawerWeek >= 0 && _drawerIdx >= 0) {
                  _toggleLabel(_drawerWeek, _drawerIdx, labelId);
                  setState(() => _drawerItem = _weeks[_drawerWeek][_drawerIdx]);
                }
              },
              onAddComment: (text) {
                if (_drawerWeek >= 0 && _drawerIdx >= 0) {
                  _addComment(_drawerWeek, _drawerIdx, text);
                  setState(() => _drawerItem = _weeks[_drawerWeek][_drawerIdx]);
                }
              },
              onAddAttachment: (url, filename) {
                if (_drawerWeek >= 0 && _drawerIdx >= 0) {
                  _addAttachment(_drawerWeek, _drawerIdx, url, filename);
                  setState(() => _drawerItem = _weeks[_drawerWeek][_drawerIdx]);
                }
              },
              onRename: () {
                if (_drawerWeek >= 0 && _drawerIdx >= 0) {
                  _renameItem(_drawerWeek, _drawerIdx);
                }
              },
              onDelete: () {
                if (_drawerWeek >= 0 && _drawerIdx >= 0) {
                  _removeItem(_drawerWeek, _drawerIdx);
                  setState(() => _drawerItem = null);
                }
              },
            )
          : null,
    );
  }

  PreferredSizeWidget _buildMagazineAppBar() {
    return AppBar(
      backgroundColor: OseeTheme.paper,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: OseeTheme.ink),
        onPressed: () => context.go('/teacher/syllabi'),
        tooltip: 'Back to syllabi',
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SYLLABUS BUILDER',
            style: TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: OseeTheme.stone,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  _syllabus?.name ?? '—',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: OseeTheme.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_syllabus?.targetExam != null)
                Text(
                  '· ${_syllabus!.targetExam!.replaceAll('_', ' ')}',
                  style: const TextStyle(
                    fontFamily: 'Helvetica',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OseeTheme.gold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: OseeTheme.gold),
        ],
      ),
      actions: [
        if (_isDirty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                'UNSAVED',
                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: OseeTheme.accent,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
          child: _PublishStamp(
            disabled: _isSaving || !_isDirty,
            isSaving: _isSaving,
            onTap: (_isSaving || !_isDirty) ? null : _save,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        for (var w = 0; w < _weeks.length; w++) _buildWeekSection(w),
        const SizedBox(height: 12),
        _AddWeekButton(onTap: _addWeek),
      ],
    );
  }

  Widget _buildWeekSection(int week) {
    final collapsed = _collapsedWeeks.contains(week);
    final items = _weeks[week];
    final minutes = _weekMinutes(week);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: OseeTheme.cloud),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Week header ----
          InkWell(
            onTap: () => setState(() {
              if (collapsed) {
                _collapsedWeeks.remove(week);
              } else {
                _collapsedWeeks.add(week);
              }
            }),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                color: OseeTheme.paper,
                border: Border(
                  left: BorderSide(color: OseeTheme.gold, width: 3),
                  bottom: BorderSide(
                    color: collapsed ? Colors.transparent : OseeTheme.cloud,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    collapsed ? Icons.chevron_right : Icons.expand_more,
                    color: OseeTheme.stone,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Week ${week + 1}',
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: OseeTheme.ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    items.isEmpty
                        ? 'empty'
                        : '${items.length} item${items.length == 1 ? '' : 's'}'
                            '${minutes > 0 ? ' · ${minutes}m' : ''}',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 11,
                      color: OseeTheme.stone,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16, color: OseeTheme.ink),
                    label: const Text(
                      'Add material',
                      style: TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: OseeTheme.ink,
                      ),
                    ),
                    onPressed: () => _openCatalog(week),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ---- Week body ----
          if (!collapsed) ...[
            if (items.isEmpty)
              _EmptyWeekHint(week: week + 1, onAdd: () => _openCatalog(week))
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: items.length,
                onReorder: (o, n) => _reorderWithinWeek(week, o, n),
                itemBuilder: (_, i) => _buildItemRow(week, i, key: ValueKey(items[i].id)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemRow(int week, int idx, {required Key key}) {
    final item = _weeks[week][idx];
    final label = SyllabusLabel.byId(item.itemType);
    final typeColor = label != null ? Color(label.color) : OseeTheme.stone;
    return Material(
      key: key,
      color: Colors.white,
      child: InkWell(
        onTap: () => setState(() {
          _drawerItem = item;
          _drawerWeek = week;
          _drawerIdx = idx;
        }),
        child: Container(
          height: 64,
          padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: OseeTheme.cloud)),
          ),
          child: Row(
            children: [
              // Drag handle (within-week reorder)
              ReorderableDragStartListener(
                index: idx,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 20),
                  child: Icon(Icons.drag_indicator, size: 18, color: OseeTheme.stone),
                ),
              ),
              // Type chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  item.itemType.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Helvetica',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: typeColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Title
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: OseeTheme.ink,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Duration
              if (item.estimatedMinutes != null)
                Text(
                  '${item.estimatedMinutes}m',
                  style: const TextStyle(
                    fontFamily: 'Helvetica',
                    fontSize: 11,
                    color: OseeTheme.stone,
                  ),
                ),
              const SizedBox(width: 8),
              // Difficulty chip
              if (item.difficulty != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: OseeTheme.cloud),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    item.difficulty!,
                    style: const TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: OseeTheme.stone,
                    ),
                  ),
                ),
              // Overflow menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: OseeTheme.stone),
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  switch (v) {
                    case 'rename':
                      _renameItem(week, idx);
                      break;
                    case 'move':
                      _showMoveToWeek(week, idx);
                      break;
                    case 'duplicate':
                      _duplicateItem(week, idx);
                      break;
                    case 'delete':
                      _removeItem(week, idx);
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'move', child: Text('Move to week →')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoveToWeek(int week, int idx) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Move to week',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (var w = 0; w < _weeks.length; w++)
              if (w != week)
                ListTile(
                  title: Text('Week ${w + 1}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _moveItemToWeek(week, idx, w);
                  },
                ),
          ],
        ),
      ),
    );
  }

  void _openCatalog(int week) {
    final wide = MediaQuery.of(context).size.width > 1200;
    final catalog = ref
        .read(catalogProvider)
        .maybeWhen(data: (d) => d, orElse: () => kMaterialCatalog);

    final content = _CatalogPicker(
      catalog: catalog,
      sourceIcon: _sourceIcon,
      onPick: (entry) {
        Navigator.of(context, rootNavigator: true).pop();
        _onCatalogAdd(entry, week);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Added to Week ${week + 1}: ${entry.title}'),
          ),
        );
      },
    );

    if (wide) {
      showGeneralDialog<void>(
        context: context,
        barrierLabel: 'Catalog',
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: OseeTheme.paper,
            child: SizedBox(
              width: 420,
              height: double.infinity,
              child: content,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: OseeTheme.paper,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: content),
      );
    }
  }

  IconData _sourceIcon(String source) {
    switch (source) {
      case 'platform_ibt':
        return Icons.school;
      case 'platform_itp':
        return Icons.quiz;
      case 'platform_ielts':
        return Icons.language;
      case 'platform_toeic':
        return Icons.work;
      case 'edubot':
        return Icons.smart_toy;
      case 'ai_generated':
        return Icons.auto_awesome;
      default:
        return Icons.book;
    }
  }
}

// ============================ _CatalogPicker ============================

class _CatalogPicker extends StatefulWidget {
  const _CatalogPicker({
    required this.catalog,
    required this.sourceIcon,
    required this.onPick,
  });

  final List<CatalogEntry> catalog;
  final IconData Function(String) sourceIcon;
  final void Function(CatalogEntry) onPick;

  @override
  State<_CatalogPicker> createState() => _CatalogPickerState();
}

class _CatalogPickerState extends State<_CatalogPicker> {
  String _query = '';
  String? _sourceFilter;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.catalog.where((e) {
      if (_sourceFilter != null && e.sourceType != _sourceFilter) return false;
      if (_query.isEmpty) return true;
      return e.title.toLowerCase().contains(_query.toLowerCase()) ||
          (e.description?.toLowerCase().contains(_query.toLowerCase()) ?? false);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: OseeTheme.cloud)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MATERIAL LIBRARY',
                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: OseeTheme.stone,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Add to syllabus',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: OseeTheme.ink,
                ),
              ),
            ],
          ),
        ),
        // Search + filters
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search materials...',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _filterChip('All', _sourceFilter == null, () => setState(() => _sourceFilter = null)),
              _filterChip('iBT', _sourceFilter == 'platform_ibt',
                  () => setState(() => _sourceFilter = 'platform_ibt')),
              _filterChip('ITP', _sourceFilter == 'platform_itp',
                  () => setState(() => _sourceFilter = 'platform_itp')),
              _filterChip('IELTS', _sourceFilter == 'platform_ielts',
                  () => setState(() => _sourceFilter = 'platform_ielts')),
              _filterChip('TOEIC', _sourceFilter == 'platform_toeic',
                  () => setState(() => _sourceFilter = 'platform_toeic')),
              _filterChip('AI', _sourceFilter == 'ai_generated',
                  () => setState(() => _sourceFilter = 'ai_generated')),
            ],
          ),
        ),
        // List
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No materials match.'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final entry = filtered[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(widget.sourceIcon(entry.sourceType), size: 20),
                      title: Text(entry.title, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '${entry.itemType} · ${entry.difficulty ?? '—'}'
                        '${entry.estimatedMinutes != null ? ' · ${entry.estimatedMinutes}m' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.add_circle_outline, size: 20),
                      onTap: () => widget.onPick(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

// ============================ small widgets ============================

class _EmptyWeekHint extends StatelessWidget {
  const _EmptyWeekHint({required this.week, required this.onAdd});
  final int week;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.add, size: 16, color: OseeTheme.stone),
        label: Text(
          'Add material to Week $week',
          style: const TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 13,
            color: OseeTheme.stone,
          ),
        ),
        onPressed: onAdd,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: OseeTheme.cloud, style: BorderStyle.solid),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _AddWeekButton extends StatelessWidget {
  const _AddWeekButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.add, size: 16, color: OseeTheme.ink),
      label: const Text(
        'Add week',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: OseeTheme.ink,
        ),
      ),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: OseeTheme.gold, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

class _PublishStamp extends StatelessWidget {
  const _PublishStamp({
    required this.disabled,
    required this.isSaving,
    required this.onTap,
  });
  final bool disabled;
  final bool isSaving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = !disabled;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? OseeTheme.ink : OseeTheme.cloud,
            border: Border.all(
              color: active ? OseeTheme.gold : OseeTheme.stone,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSaving)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                )
              else
                const Icon(Icons.save, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'PUBLISH',
                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: active ? Colors.white : OseeTheme.stone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: OseeTheme.accent),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Dismiss')),
        ],
      ),
    );
  }
}

// ============================ _ItemDetailDrawer ============================
// (unchanged Planka-style drawer, reused from the previous implementation)

class _ItemDetailDrawer extends StatelessWidget {
  const _ItemDetailDrawer({
    required this.item,
    required this.onClose,
    required this.onToggleLabel,
    required this.onAddComment,
    required this.onAddAttachment,
    required this.onRename,
    required this.onDelete,
  });

  final SyllabusItem item;
  final VoidCallback onClose;
  final void Function(String labelId) onToggleLabel;
  final void Function(String text) onAddComment;
  final void Function(String url, String? filename) onAddAttachment;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: OseeTheme.paper,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              decoration: const BoxDecoration(
                color: OseeTheme.ink,
                border: Border(bottom: BorderSide(color: OseeTheme.gold, width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.itemType.replaceAll('_', ' ')} · ${item.difficulty ?? '—'}'
                    '${item.estimatedMinutes != null ? ' · ${item.estimatedMinutes}m' : ''}',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Rename'),
                          onPressed: onRename,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 16, color: OseeTheme.accent),
                          label: const Text('Delete', style: TextStyle(color: OseeTheme.accent)),
                          onPressed: onDelete,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: OseeTheme.accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const _SectionLabel('DESCRIPTION'),
                    const SizedBox(height: 6),
                    Text(item.description!, style: const TextStyle(fontSize: 14, height: 1.4)),
                    const SizedBox(height: 20),
                  ],
                  // Labels
                  const _SectionLabel('LABELS'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final label in SyllabusLabel.preset)
                        FilterChip(
                          label: Text(label.name, style: const TextStyle(fontSize: 12)),
                          selected: item.labelIds.contains(label.id),
                          onSelected: (_) => onToggleLabel(label.id),
                          selectedColor: Color(label.color).withValues(alpha: 0.15),
                          checkmarkColor: Color(label.color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Comments
                  const _SectionLabel('COMMENTS'),
                  const SizedBox(height: 8),
                  if (item.comments.isEmpty)
                    const Text('No comments yet.', style: TextStyle(color: OseeTheme.stone)),
                  for (final c in item.comments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.authorName ?? 'You',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          Text(c.text, style: const TextStyle(fontSize: 13, height: 1.3)),
                        ],
                      ),
                    ),
                  _AddCommentField(onSubmit: onAddComment),
                  const SizedBox(height: 20),
                  // Attachments
                  const _SectionLabel('ATTACHMENTS'),
                  const SizedBox(height: 8),
                  if (item.attachments.isEmpty)
                    const Text('No attachments.', style: TextStyle(color: OseeTheme.stone)),
                  for (final a in item.attachments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file, size: 16, color: OseeTheme.stone),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              a.filename ?? a.url,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _AddAttachmentField(onSubmit: (url, filename) => onAddAttachment(url, filename)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Helvetica',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: OseeTheme.stone,
      ),
    );
  }
}

class _AddCommentField extends StatefulWidget {
  const _AddCommentField({required this.onSubmit});
  final void Function(String) onSubmit;
  @override
  State<_AddCommentField> createState() => _AddCommentFieldState();
}

class _AddCommentFieldState extends State<_AddCommentField> {
  final _ctl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctl,
            decoration: const InputDecoration(
              hintText: 'Add a comment...',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send, size: 18),
          onPressed: () {
            final v = _ctl.text.trim();
            if (v.isNotEmpty) {
              widget.onSubmit(v);
              _ctl.clear();
            }
          },
        ),
      ],
    );
  }
}

class _AddAttachmentField extends StatefulWidget {
  const _AddAttachmentField({required this.onSubmit});
  final void Function(String url, String? filename) onSubmit;
  @override
  State<_AddAttachmentField> createState() => _AddAttachmentFieldState();
}

class _AddAttachmentFieldState extends State<_AddAttachmentField> {
  final _urlCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _urlCtl,
          decoration: const InputDecoration(
            hintText: 'Attachment URL',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameCtl,
                decoration: const InputDecoration(
                  hintText: 'Filename (optional)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_link, size: 18),
              onPressed: () {
                final u = _urlCtl.text.trim();
                if (u.isNotEmpty) {
                  widget.onSubmit(u, _nameCtl.text.trim().isEmpty ? null : _nameCtl.text.trim());
                  _urlCtl.clear();
                  _nameCtl.clear();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}