import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voo_kanban/voo_kanban.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';
import '../models/catalog.dart';
import '../models/syllabus.dart';
import '../models/labels.dart';
import '../providers/syllabus_repository.dart';

/// Magazine-style Kanban syllabus builder.
///
/// Layout: editorial AppBar with gold rule + "PUBLISH" stamp,
/// center: VooKanbanBoard with asymmetric lane widths (weeks 1..N),
/// right rail: "DEPARTMENTS" catalog sidebar (drag-source).
///
/// Drag from catalog into a lane creates a new [SyllabusItem].
/// Drag between lanes moves the item.
/// Ctrl+Z / Ctrl+Y for undo/redo (from voo_kanban).
/// Save button batch-saves via PUT /api/teacher/syllabi/:id/items.
class SyllabusBuilderPage extends ConsumerStatefulWidget {
  const SyllabusBuilderPage({super.key, required this.syllabusId});
  final String syllabusId;

  @override
  ConsumerState<SyllabusBuilderPage> createState() =>
      _SyllabusBuilderPageState();
}

class _SyllabusBuilderPageState extends ConsumerState<SyllabusBuilderPage> {
  static const int _initialColumns = 8;
  late List<List<SyllabusItem>> _columns;
  Syllabus? _syllabus;
  bool _isSaving = false;
  bool _isDirty = false;
  String? _error;

  /// Catalog filters
  String _catalogQuery = '';
  String? _catalogSourceFilter;

  /// Planka-style item detail drawer
  SyllabusItem? _drawerItem;
  int _drawerCol = -1;
  int _drawerIdx = -1;

  late KanbanController<SyllabusItem> _kanbanController;

  @override
  void initState() {
    super.initState();
    _columns = List.generate(_initialColumns, (_) => <SyllabusItem>[]);
    _kanbanController = KanbanController<SyllabusItem>();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final detail = await ref
          .read(syllabusRepositoryProvider)
          .getSyllabus(widget.syllabusId);
      _syllabus = detail.syllabus;
      _columns = List.generate(_initialColumns, (_) => <SyllabusItem>[]);
      for (final item in detail.items) {
        final col = _columnForSection(item.section);
        _columns[col].add(item);
      }
      // Sync controller dengan data yang baru di-load
      _kanbanController.setLanes(_buildLanes());
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load syllabus: $e');
    }
  }

  int _columnForSection(String? section) {
    if (section == null || section.isEmpty) return 0;
    final wk = RegExp(r'week-?(\d+)').firstMatch(section.toLowerCase());
    if (wk != null) {
      final n = int.parse(wk.group(1)!);
      if (n >= 1 && n <= _columns.length) return n - 1;
    }
    return 0;
  }

  String _columnSectionLabel(int col) => 'week-${col + 1}';

  // ---------------------- mutations ----------------------

  void _onCatalogDrop(CatalogEntry entry, int targetCol) {
    final tempId =
        'local:${entry.sourceType}:${entry.materialId}:${DateTime.now().microsecondsSinceEpoch}';
    // Auto-attach the matching label by item_type when possible.
    final autoLabel = <String>[];
    final matching = SyllabusLabel.preset.where((l) => l.id == entry.itemType);
    if (matching.isNotEmpty) autoLabel.add(matching.first.id);

    final newItem = SyllabusItem(
      id: tempId,
      syllabusId: widget.syllabusId,
      sortOrder: _columns[targetCol].length,
      sourceType: entry.sourceType,
      sourceMaterialId: entry.materialId,
      sourcePlatformUrl: null,
      title: entry.title,
      description: entry.description,
      itemType: entry.itemType,
      section: _columnSectionLabel(targetCol),
      difficulty: entry.difficulty,
      estimatedMinutes: entry.estimatedMinutes,
      flavorTag: null,
      temperatureTag: null,
      unlockedAt: null,
      labelIds: autoLabel,
    );
    _columns[targetCol].add(newItem);
    _isDirty = true;

    // Rebuild lanes + sync controller
    final lanes = _buildLanes();
    _kanbanController.setLanes(lanes);
    setState(() {});
  }

  /// Build KanbanLane list from _columns (shared between board + controller sync).
  List<KanbanLane<SyllabusItem>> _buildLanes() {
    final widths = <double>[320, 280, 360, 280, 320, 280, 360, 240, 320, 280, 360, 280];
    final lanes = <KanbanLane<SyllabusItem>>[];
    for (var c = 0; c < _columns.length; c++) {
      final w = widths[c % widths.length];
      final totalMin = _columns[c].fold<int>(0, (a, i) => a + (i.estimatedMinutes ?? 0));
      lanes.add(
        KanbanLane<SyllabusItem>(
          id: c.toString(),
          title: 'Week ${c + 1}',
          subtitle: _columns[c].isEmpty ? '—' : '${_columns[c].length} · ${totalMin}m',
          cards: [
            for (var i = 0; i < _columns[c].length; i++)
              KanbanCard<SyllabusItem>(
                id: _columns[c][i].id,
                data: _columns[c][i],
                laneId: c.toString(),
                index: i,
              ),
          ],
          metadata: {'width': w, 'columnIndex': c},
        ),
      );
    }
    return lanes;
  }

  /// Show dialog to pick a material from the catalog and add to a lane.
  void _showAddMaterialDialog(int targetCol) {
    showDialog(
      context: context,
      builder: (ctx) {
        String query = '';
        String? sourceFilter;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            var filtered = kMaterialCatalog.where((e) {
              if (sourceFilter != null && e.sourceType != sourceFilter) return false;
              if (query.isEmpty) return true;
              return e.title.toLowerCase().contains(query.toLowerCase()) ||
                  (e.description?.toLowerCase().contains(query.toLowerCase()) ?? false);
            }).toList();
            return AlertDialog(
              title: const Text('Add Material'),
              content: SizedBox(
                width: 500,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search materials...',
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                      onChanged: (v) => setDialogState(() => query = v),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: [
                        FilterChip(label: const Text('All'), selected: sourceFilter == null, onSelected: (_) => setDialogState(() => sourceFilter = null)),
                        FilterChip(label: const Text('iBT'), selected: sourceFilter == 'platform_ibt', onSelected: (_) => setDialogState(() => sourceFilter = 'platform_ibt')),
                        FilterChip(label: const Text('ITP'), selected: sourceFilter == 'platform_itp', onSelected: (_) => setDialogState(() => sourceFilter = 'platform_itp')),
                        FilterChip(label: const Text('IELTS'), selected: sourceFilter == 'platform_ielts', onSelected: (_) => setDialogState(() => sourceFilter = 'platform_ielts')),
                        FilterChip(label: const Text('TOEIC'), selected: sourceFilter == 'platform_toeic', onSelected: (_) => setDialogState(() => sourceFilter = 'platform_toeic')),
                        FilterChip(label: const Text('AI'), selected: sourceFilter == 'ai_generated', onSelected: (_) => setDialogState(() => sourceFilter = 'ai_generated')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final entry = filtered[i];
                          return ListTile(
                            leading: Icon(_sourceIcon(entry.sourceType), size: 20),
                            title: Text(entry.title, style: const TextStyle(fontSize: 14)),
                            subtitle: Text('${entry.itemType} · ${entry.difficulty ?? '—'}', style: const TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.add_circle_outline, size: 20),
                            onTap: () {
                              Navigator.pop(ctx);
                              _onCatalogDrop(entry, targetCol);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 1),
                                  content: Text('Added: ${entry.title}'),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ],
            );
          },
        );
      },
    );
  }

  IconData _sourceIcon(String source) {
    switch (source) {
      case 'platform_ibt': return Icons.school;
      case 'platform_itp': return Icons.quiz;
      case 'platform_ielts': return Icons.language;
      case 'platform_toeic': return Icons.work;
      case 'edubot': return Icons.smart_toy;
      case 'ai_generated': return Icons.auto_awesome;
      default: return Icons.book;
    }
  }

  void _onCardMoved(
    KanbanCard<SyllabusItem> card,
    String fromLaneId,
    String toLaneId,
    int newIndex,
  ) {
    setState(() {
      final from = int.parse(fromLaneId);
      final to = int.parse(toLaneId);
      if (from == to) {
        if (newIndex >= 0 && newIndex < _columns[from].length) {
          final item = _columns[from].removeAt(card.index);
          _columns[from].insert(
            newIndex,
            item.copyWith(section: _columnSectionLabel(to)),
          );
        }
      } else {
        if (card.index >= 0 && card.index < _columns[from].length) {
          final item = _columns[from].removeAt(card.index);
          final updated = item.copyWith(section: _columnSectionLabel(to));
          final clamped = newIndex.clamp(0, _columns[to].length);
          _columns[to].insert(clamped, updated);
        }
      }
      _isDirty = true;
    });
  }

  void _removeItem(int col, int idx) {
    _columns[col].removeAt(idx);
    _isDirty = true;
    _kanbanController.setLanes(_buildLanes());
    setState(() {});
  }

  void _renameItem(int col, int idx) {
    final current = _columns[col][idx];
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
                  _columns[col][idx] = current.copyWith(title: v);
                  _isDirty = true;
                });
                _kanbanController.setLanes(_buildLanes());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _toggleLabel(int col, int idx, String labelId) {
    final current = _columns[col][idx];
    final has = current.labelIds.contains(labelId);
    final next = has
        ? current.labelIds.where((l) => l != labelId).toList(growable: false)
        : [...current.labelIds, labelId];
    setState(() {
      _columns[col][idx] = current.copyWith(labelIds: next);
      _isDirty = true;
    });
  }

  void _addComment(int col, int idx, String text) {
    final current = _columns[col][idx];
    final c = SyllabusComment(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      itemId: current.id,
      authorId: _syllabus?.teacherId ?? 'me',
      authorName: 'You',
      text: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _columns[col][idx] = current.copyWith(comments: [...current.comments, c]);
      _isDirty = true;
    });
  }

  void _addAttachment(int col, int idx, String url, [String? filename]) {
    final current = _columns[col][idx];
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
      _columns[col][idx] = current.copyWith(
        attachments: [...current.attachments, a],
      );
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
      for (var c = 0; c < _columns.length; c++) {
        for (var i = 0; i < _columns[c].length; i++) {
          final item = _columns[c][i].copyWith(
            sortOrder: flat.length,
            section: _columnSectionLabel(c),
          );
          flat.add(item);
        }
      }
      await ref
          .read(syllabusRepositoryProvider)
          .saveItems(widget.syllabusId, flat);

      // Publish syllabus so students can see it
      final dio = ApiClient.create();
      await dio.post('/teacher/syllabi/${widget.syllabusId}/publish', data: {'published': true});

      setState(() {
        _isDirty = false;
        _syllabus = _syllabus?.copyWith(isPublished: true);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Syllabus published! Students can now see it.')));
    } catch (e) {
      if (mounted) setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addColumn() {
    setState(() {
      _columns.add(<SyllabusItem>[]);
      _isDirty = true;
    });
  }

  // ---------------------- UI ----------------------

  @override
  Widget build(BuildContext context) {
    final loaded = _syllabus != null;
    return Scaffold(
      backgroundColor: OseeTheme.paper,
      appBar: _buildMagazineAppBar(),
      body: _error != null
          ? _ErrorPanel(
              message: _error!,
              onRetry: () => setState(() => _error = null),
            )
          : loaded
          ? _buildBody()
          : const Center(child: CircularProgressIndicator()),
      endDrawer: _drawerItem != null
          ? _ItemDetailDrawer(
              item: _drawerItem!,
              onClose: () => setState(() => _drawerItem = null),
              onToggleLabel: (labelId) {
                if (_drawerCol >= 0 && _drawerIdx >= 0) {
                  _toggleLabel(_drawerCol, _drawerIdx, labelId);
                  setState(
                    () => _drawerItem = _columns[_drawerCol][_drawerIdx],
                  );
                }
              },
              onAddComment: (text) {
                if (_drawerCol >= 0 && _drawerIdx >= 0) {
                  _addComment(_drawerCol, _drawerIdx, text);
                  setState(
                    () => _drawerItem = _columns[_drawerCol][_drawerIdx],
                  );
                }
              },
              onAddAttachment: (url, filename) {
                if (_drawerCol >= 0 && _drawerIdx >= 0) {
                  _addAttachment(_drawerCol, _drawerIdx, url, filename);
                  setState(
                    () => _drawerItem = _columns[_drawerCol][_drawerIdx],
                  );
                }
              },
              onRename: () {
                if (_drawerCol >= 0 && _drawerIdx >= 0) {
                  _renameItem(_drawerCol, _drawerIdx);
                }
              },
              onDelete: () {
                if (_drawerCol >= 0 && _drawerIdx >= 0) {
                  _removeItem(_drawerCol, _drawerIdx);
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
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: OseeTheme.stone,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _syllabus?.name ?? '—',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: OseeTheme.ink,
                ),
              ),
              const SizedBox(width: 8),
              if (_syllabus?.targetExam != null)
                Text(
                  '· ${_syllabus!.targetExam!.replaceAll('_', ' ')}',
                  style: const TextStyle(
                    fontFamily: 'Helvetica',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: OseeTheme.gold,
                    letterSpacing: 0,
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
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: OseeTheme.accent,
                ),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.add_box_outlined, color: OseeTheme.ink),
          tooltip: 'Add column',
          onPressed: _addColumn,
        ),
        const SizedBox(width: 6),
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

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 1100;
        if (isWide) {
          // Wide layout: board (left) + catalog sidebar (right)
          return Row(
            children: [
              Expanded(child: _buildBoardArea()),
              Container(width: 1, color: OseeTheme.cloud),
              SizedBox(width: 340, child: _buildCatalog()),
            ],
          );
        }
        // Narrow layout: catalog (top, collapsible) + board (below)
        return Column(
          children: [
            SizedBox(
              width: c.maxWidth,
              height: 280,
              child: _buildCatalog(),
            ),
            Container(height: 1, color: OseeTheme.cloud),
            Expanded(child: _buildBoardArea()),
          ],
        );
      },
    );
  }

  Widget _buildBoardArea() {
    final lanes = _buildLanes();

    return Container(
      color: OseeTheme.paper,
      child: VooKanbanBoard<SyllabusItem>(
        lanes: lanes,
        controller: _kanbanController,
        config: const KanbanConfig(
          enableUndo: true,
          maxUndoSteps: 50,
          enableKeyboardNavigation: true,
          enableAnimations: true,
          animationDuration: Duration(milliseconds: 250),
          defaultLaneWidth: 300,
          minLaneWidth: 220,
          maxLaneWidth: 380,
          laneSpacing: 14,
          cardSpacing: 10,
        ),
        cardBuilder: (ctx, card, isSelected) => _MagazineCard(
          card: card,
          selected: isSelected,
          onTap: () {
            final col = int.parse(card.laneId);
            setState(() {
              _drawerItem = card.data;
              _drawerCol = col;
              _drawerIdx = card.index;
            });
            Scaffold.of(ctx).openEndDrawer();
          },
        ),
        laneHeaderBuilder: (ctx, lane) => _MagazineLaneHeader(
          lane: lane,
          onAddMaterial: () => _showAddMaterialDialog(int.parse(lane.id)),
        ),
        emptyLaneBuilder: (ctx, lane) => _MagazineEmptyLane(lane: lane),
        onCardMoved: _onCardMoved,
        onCardTap: (card) {
          final col = int.parse(card.laneId);
          setState(() {
            _drawerItem = card.data;
            _drawerCol = col;
            _drawerIdx = card.index;
          });
          Scaffold.of(context).openEndDrawer();
        },
      ),
    );
  }

  Widget _buildCatalog() {
    final filtered = kMaterialCatalog.where((e) {
      if (_catalogSourceFilter != null && e.sourceType != _catalogSourceFilter)
        return false;
      if (_catalogQuery.isEmpty) return true;
      return e.title.toLowerCase().contains(_catalogQuery.toLowerCase()) ||
          (e.description?.toLowerCase().contains(_catalogQuery.toLowerCase()) ??
              false);
    }).toList();

    return Container(
      color: const Color(0xFFEFEDE6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Magazine sidebar header — "DEPARTMENTS" with vertical rule
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: OseeTheme.ink, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 2, height: 28, color: OseeTheme.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DEPARTMENTS',
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                              color: OseeTheme.stone,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Material Library',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: OseeTheme.ink,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                  Text(
                    'Tap any item to add it to Week 1.',
                    style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                    color: OseeTheme.stone,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(
                  Icons.search,
                  size: 16,
                  color: OseeTheme.stone,
                ),
                hintText: 'Search the library…',
                hintStyle: TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: OseeTheme.stone,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2),
                  borderSide: const BorderSide(color: OseeTheme.cloud),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2),
                  borderSide: const BorderSide(color: OseeTheme.ink, width: 1),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 13),
              onChanged: (v) => setState(() => _catalogQuery = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', null),
                  _filterChip('iBT', 'platform_ibt'),
                  _filterChip('ITP', 'platform_itp'),
                  _filterChip('IELTS', 'platform_ielts'),
                  _filterChip('TOEIC', 'platform_toeic'),
                  _filterChip('EduBot', 'edubot'),
                  _filterChip('AI', 'ai_generated'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: OseeTheme.cloud),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                // Asymmetric padding — alternate 12/8/12/8 for editorial rhythm.
                final pad = i.isEven ? 12.0 : 8.0;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: pad / 2),
                  child: _MagazineCatalogCard(
                    entry: filtered[i],
                    index: i + 1,
                    onTap: () => _onCatalogDrop(filtered[i], 0),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? src) {
    final selected = _catalogSourceFilter == src;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 10, fontFamily: 'Helvetica'),
        ),
        selected: selected,
        selectedColor: OseeTheme.ink,
        labelStyle: TextStyle(
          color: selected ? Colors.white : OseeTheme.ink,
          fontFamily: 'Helvetica',
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
        onSelected: (_) => setState(() => _catalogSourceFilter = src),
      ),
    );
  }
}

// ============================================================
// Magazine-styled components
// ============================================================

/// The "PUBLISH" stamp — a magazine-style bordered button with letter-spaced
/// Helvetica uppercase, gold border, ink background when active.
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
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white,
                  ),
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
                  letterSpacing: 0,
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

/// Magazine-styled Kanban card. Mixed Georgia/Helvetica, gold rule, label chips,
/// comments/attachments counts. Tappable to open detail drawer.
class _MagazineCard extends StatelessWidget {
  const _MagazineCard({
    required this.card,
    required this.selected,
    required this.onTap,
  });
  final KanbanCard<SyllabusItem> card;
  final bool selected;
  final VoidCallback onTap;

  Color _typeColor(String itemType) {
    final l = SyllabusLabel.byId(itemType);
    return l != null ? Color(l.color) : Colors.grey.shade300;
  }

  @override
  Widget build(BuildContext context) {
    final item = card.data;
    final typeColor = _typeColor(item.itemType);
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: typeColor, width: 3),
              bottom: BorderSide(color: OseeTheme.cloud, width: 1),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kicker — source type + difficulty
              Row(
                children: [
                  Text(
                    _sourceLabel(item.sourceType).toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      color: typeColor,
                    ),
                  ),
                  if (item.difficulty != null) ...[
                    const Text(
                      ' · ',
                      style: TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 8,
                        color: OseeTheme.stone,
                      ),
                    ),
                    Text(
                      item.difficulty!.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        color: OseeTheme.stone,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              // Title — Georgia, mixed size based on length
              Text(
                item.title,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: item.title.length > 30 ? 12 : 14,
                  fontWeight: FontWeight.w700,
                  color: OseeTheme.ink,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.description!,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 10,
                    color: OseeTheme.stone,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 6),
              // Gold rule
              Container(height: 0.5, color: OseeTheme.gold.withOpacity(0.6)),
              const SizedBox(height: 6),
              // Labels row
              if (item.labelIds.isNotEmpty)
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (final labelId in item.labelIds.take(4))
                      if (SyllabusLabel.byId(labelId) case final l?)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Color(l.color).withOpacity(0.15),
                            border: Border(
                              left: BorderSide(color: Color(l.color), width: 2),
                            ),
                          ),
                          child: Text(
                            l.name,
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: Color(l.color),
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                  ],
                ),
              // Bottom meta — minutes + comments + attachments
              const SizedBox(height: 6),
              Row(
                children: [
                  if (item.estimatedMinutes != null)
                    Text(
                      '${item.estimatedMinutes}m',
                      style: const TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: OseeTheme.stone,
                      ),
                    ),
                  const Spacer(),
                  if (item.comments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 10,
                            color: OseeTheme.stone,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${item.comments.length}',
                            style: const TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 9,
                              color: OseeTheme.stone,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (item.attachments.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.attach_file,
                          size: 10,
                          color: OseeTheme.stone,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${item.attachments.length}',
                          style: const TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 9,
                            color: OseeTheme.stone,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLabel(String src) {
    switch (src) {
      case 'platform_ibt':
        return 'iBT';
      case 'platform_itp':
        return 'ITP';
      case 'platform_ielts':
        return 'IELTS';
      case 'platform_toeic':
        return 'TOEIC';
      case 'edubot':
        return 'EduBot';
      case 'teacher_custom':
        return 'Custom';
      case 'ai_generated':
        return 'AI';
      case 'video_lesson':
        return 'Video';
      case 'live_class':
        return 'Live';
      default:
        return src;
    }
  }
}

/// Magazine-styled lane header — kicker "WEEK" + big Georgia number + thin gold rule.
class _MagazineLaneHeader extends StatelessWidget {
  const _MagazineLaneHeader({required this.lane, this.onAddMaterial});
  final KanbanLane<SyllabusItem> lane;
  final VoidCallback? onAddMaterial;

  @override
  Widget build(BuildContext context) {
    final col = int.parse(lane.id);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 8, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: OseeTheme.cloud, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'WEEK',
                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: OseeTheme.accent,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${col + 1}',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: OseeTheme.ink,
                  height: 1,
                ),
              ),
              const Spacer(),
              if (onAddMaterial != null)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 18, color: OseeTheme.primary),
                  onPressed: onAddMaterial,
                  tooltip: 'Add material',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              if (lane.subtitle != null && lane.subtitle != '—')
                Text(
                  lane.subtitle!,
                  style: const TextStyle(
                    fontFamily: 'Helvetica',
                    fontSize: 9,
                    color: OseeTheme.stone,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 0.5, color: OseeTheme.gold.withOpacity(0.7)),
        ],
      ),
    );
  }
}

/// Magazine empty-lane state — italic pull-quote instead of "drop here".
class _MagazineEmptyLane extends StatelessWidget {
  const _MagazineEmptyLane({required this.lane});
  final KanbanLane<SyllabusItem> lane;

  static const _quotes = [
    'The opening act.',
    'Set the stage.',
    'Where it begins.',
    'A blank canvas.',
    'The first move.',
    'Plant the seed.',
    'Find the rhythm.',
    'Step into the story.',
    'Compose the chapter.',
    'Sketch the outline.',
    'Lay the groundwork.',
    'The quiet before.',
  ];

  @override
  Widget build(BuildContext context) {
    final col = int.parse(lane.id);
    final quote = _quotes[col % _quotes.length];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"$quote"',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 13,
              color: OseeTheme.stone,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.drag_indicator, size: 14, color: OseeTheme.cloud),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Drag material here',
                  style: TextStyle(
                    fontFamily: 'Helvetica',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: OseeTheme.cloud,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Magazine-styled catalog card — asymmetric padding, rotated index number,
/// serif title, sans caption, gold rule.
class _MagazineCatalogCard extends StatelessWidget {
  const _MagazineCatalogCard({required this.entry, required this.index, this.onTap});
  final CatalogEntry entry;
  final int index;
  final VoidCallback? onTap;

  IconData _iconFor(String src) {
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: _buildInner(),
    );
  }

  Widget _buildInner({bool emitShadow = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: OseeTheme.gold.withOpacity(0.5), width: 1),
          bottom: BorderSide(color: OseeTheme.cloud, width: 1),
        ),
        boxShadow: emitShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index number — magazine-style, rotated -3deg
            Transform.rotate(
              angle: -0.06,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  border: Border.all(color: OseeTheme.ink, width: 1),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: OseeTheme.ink,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _iconFor(entry.sourceType),
                        size: 11,
                        color: OseeTheme.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _sourceLabel(entry.sourceType).toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: OseeTheme.stone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.title,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: OseeTheme.ink,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.description!,
                      style: const TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 9,
                        color: OseeTheme.stone,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (entry.difficulty != null)
                        Text(
                          entry.difficulty!,
                          style: const TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: OseeTheme.gold,
                            letterSpacing: 0,
                          ),
                        ),
                      if (entry.difficulty != null &&
                          entry.estimatedMinutes > 0)
                        const Text(
                          ' · ',
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 8,
                            color: OseeTheme.stone,
                          ),
                        ),
                      if (entry.estimatedMinutes > 0)
                        Text(
                          '${entry.estimatedMinutes}m',
                          style: const TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: OseeTheme.stone,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(String src) {
    switch (src) {
      case 'platform_ibt':
        return 'iBT';
      case 'platform_itp':
        return 'ITP';
      case 'platform_ielts':
        return 'IELTS';
      case 'platform_toeic':
        return 'TOEIC';
      case 'edubot':
        return 'EduBot';
      case 'teacher_custom':
        return 'Custom';
      case 'ai_generated':
        return 'AI';
      case 'video_lesson':
        return 'Video';
      case 'live_class':
        return 'Live';
      default:
        return src;
    }
  }
}

// ============================================================
// Planka-style item detail drawer
// ============================================================

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
                border: Border(
                  bottom: BorderSide(color: OseeTheme.gold, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'ITEM',
                        style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          color: OseeTheme.gold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: onClose,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.description!,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Body — scrollable
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Labels section
                  _SectionLabel('LABELS'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final l in SyllabusLabel.preset)
                        _LabelToggle(
                          label: l,
                          selected: item.labelIds.contains(l.id),
                          onTap: () => onToggleLabel(l.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Comments section
                  _SectionLabel('COMMENTS'),
                  const SizedBox(height: 8),
                  for (final c in item.comments) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          left: BorderSide(color: OseeTheme.gold, width: 2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                c.authorName ?? 'Someone',
                                style: const TextStyle(
                                  fontFamily: 'Helvetica',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: OseeTheme.ink,
                                  letterSpacing: 0,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${c.createdAt.day}/${c.createdAt.month}',
                                style: const TextStyle(
                                  fontFamily: 'Helvetica',
                                  fontSize: 9,
                                  color: OseeTheme.stone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.text,
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 12,
                              color: OseeTheme.ink,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _AddCommentBar(onSubmit: onAddComment),
                  const SizedBox(height: 28),
                  // Attachments section
                  _SectionLabel('ATTACHMENTS'),
                  const SizedBox(height: 8),
                  for (final a in item.attachments)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: OseeTheme.cloud),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link,
                            size: 14,
                            color: OseeTheme.accent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              a.filename ?? a.url,
                              style: const TextStyle(
                                fontFamily: 'Helvetica',
                                fontSize: 10,
                                color: OseeTheme.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  _AddAttachmentBar(onSubmit: onAddAttachment),
                  const SizedBox(height: 28),
                  // Actions
                  _SectionLabel('ACTIONS'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: onRename,
                        icon: const Icon(Icons.edit, size: 14),
                        label: const Text('Rename'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: OseeTheme.accent,
                          side: const BorderSide(color: OseeTheme.accent),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: const Text('Delete'),
                      ),
                    ],
                  ),
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
    return Row(
      children: [
        Container(width: 12, height: 1, color: OseeTheme.ink),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            color: OseeTheme.ink,
          ),
        ),
      ],
    );
  }
}

class _LabelToggle extends StatelessWidget {
  const _LabelToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final SyllabusLabel label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(label.color);
    return Material(
      color: selected ? color.withOpacity(0.15) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color, width: 2),
              top: BorderSide(
                color: selected ? color : Colors.transparent,
                width: 1,
              ),
              right: BorderSide(
                color: selected ? color : Colors.transparent,
                width: 1,
              ),
              bottom: BorderSide(
                color: selected ? color : Colors.transparent,
                width: 1,
              ),
            ),
          ),
          child: Text(
            label.name,
            style: TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: selected ? color : OseeTheme.stone,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddCommentBar extends StatefulWidget {
  const _AddCommentBar({required this.onSubmit});
  final void Function(String) onSubmit;
  @override
  State<_AddCommentBar> createState() => _AddCommentBarState();
}

class _AddCommentBarState extends State<_AddCommentBar> {
  final _ctl = TextEditingController();
  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctl,
            decoration: InputDecoration(
              hintText: 'Write a comment…',
              hintStyle: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: 11,
                color: OseeTheme.stone,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: OseeTheme.cloud),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: OseeTheme.ink),
              ),
            ),
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 12),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) {
                widget.onSubmit(v.trim());
                _ctl.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            final v = _ctl.text.trim();
            if (v.isNotEmpty) {
              widget.onSubmit(v);
              _ctl.clear();
            }
          },
          icon: const Icon(Icons.send, color: OseeTheme.ink, size: 18),
        ),
      ],
    );
  }
}

class _AddAttachmentBar extends StatefulWidget {
  const _AddAttachmentBar({required this.onSubmit});
  final void Function(String url, String? filename) onSubmit;
  @override
  State<_AddAttachmentBar> createState() => _AddAttachmentBarState();
}

class _AddAttachmentBarState extends State<_AddAttachmentBar> {
  final _ctl = TextEditingController();
  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctl,
            decoration: InputDecoration(
              hintText: 'Paste a URL…',
              hintStyle: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: 11,
                color: OseeTheme.stone,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: OseeTheme.cloud),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: const BorderSide(color: OseeTheme.ink),
              ),
            ),
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 12),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) {
                widget.onSubmit(v.trim(), null);
                _ctl.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            final v = _ctl.text.trim();
            if (v.isNotEmpty) {
              widget.onSubmit(v, null);
              _ctl.clear();
            }
          },
          icon: const Icon(Icons.add_link, color: OseeTheme.ink, size: 18),
        ),
      ],
    );
  }
}

// ============================================================
// Errors
// ============================================================

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
