import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';
import '../../../core/mind_board_api.dart';

/// Notion-style block builder for OSEE lesson creation.
class MindMapRecipePage extends ConsumerStatefulWidget {
  const MindMapRecipePage({super.key, required this.syllabusId, this.boardId});
  final String syllabusId;
  final String? boardId;

  @override
  ConsumerState<MindMapRecipePage> createState() => _MindMapRecipePageState();
}

class _MindMapRecipePageState extends ConsumerState<MindMapRecipePage> {
  late final MindBoardApi _api;

  // Board persistence
  String? _boardId;
  String _boardTitle = 'Untitled lesson';
  int _boardVersion = 1;
  String _saveStatus = 'UNSAVED'; // UNSAVED | SAVING... | SAVED v{n} | ERROR
  Timer? _autosaveTimer;
  bool _isDirty = false;
  bool _isLoadingBoard = false;

  // Undo/redo
  final List<Map<String, dynamic>> _undoStack = [];
  final List<Map<String, dynamic>> _redoStack = [];
  static const int _maxUndo = 50;

  // Material library
  final List<Map<String, dynamic>> _materials = [];
  bool _materialsLoading = false;

  // Templates
  final List<Map<String, dynamic>> _templates = [];

  // Difficulty + KP tags (Tier 2)
  String _difficulty = 'medium'; // easy | medium | hard | expert
  final List<Map<String, String>> _kpTags = [];

  // AI critic results
  Map<String, dynamic>? _criticReview;
  bool _isReviewing = false;

  // Comments per node (cached)
  final Map<String, List<Map<String, dynamic>>> _nodeComments = {};

  // Node data
  final Map<String, _NodeData> _nodes = {};

  // Input fields
  final _topicCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  String _exam = 'TOEFL_IBT';
  String _level = 'B2';
  String _itemType = 'grammar';

  bool _isSaving = false;

  // Sources
  final List<_SourceData> _sources = [];
  int _sourceCounter = 0;

  // Text notes (free-form sticky)
  final Map<String, String> _textNotes = {};
  int _textNoteCounter = 0;

  // Image nodes
  final Map<String, _ImageData> _images = {};
  int _imageCounter = 0;

  // BLOCK BUILDER STATE (Notion-style)
  List<String> _blockOrder = ['setup', 'sources', 'theory', 'examples', 'exercises', 'vocabulary', 'practice', 'assessment', 'reading_agent', 'speaking_agent', 'writing_agent'];
  final Map<String, bool> _blockCollapsed = {};
  final _slashCtl = TextEditingController();
  bool _showSlashMenu = false;
  final _scrollCtl = ScrollController();
  final _agentInputCtls = <String, TextEditingController>{};
  final _slashFocus = FocusNode();

  bool _isBlockCollapsed(String id) => _blockCollapsed[id] ?? false;

  void _toggleBlock(String id) => setState(() => _blockCollapsed[id] = !_isBlockCollapsed(id));

  static const Map<String, IconData> _blockIcons = {
    'setup': Icons.tune, 'sources': Icons.folder_open, 'theory': Icons.menu_book,
    'examples': Icons.lightbulb_outline, 'exercises': Icons.quiz_outlined,
    'vocabulary': Icons.translate, 'practice': Icons.fitness_center,
    'assessment': Icons.assignment, 'reading_agent': Icons.menu_book_outlined,
    'speaking_agent': Icons.mic, 'writing_agent': Icons.edit,
  };

  @override
  void initState() {
    super.initState();
    _api = ref.read(mindBoardApiProvider);
    _boardId = widget.boardId;
    _initBlockNodes();
    if (_boardId != null) {
      _hydrateBoard();
    }
    _loadMaterials();
    _loadTemplates();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _scrollCtl.dispose();
    _slashCtl.dispose();
    _slashFocus.dispose();
    super.dispose();
  }

  void _initBlockNodes() {
    _nodes['setup'] = _NodeData(type: 'input', title: 'Setup', color: const Color(0xFF1F2937));
    _nodes['sources'] = _NodeData(type: 'source', title: 'Sources', color: const Color(0xFF6B8E7F));
    _nodes['theory'] = _NodeData(type: 'theory', title: 'Theory', color: const Color(0xFF1E40AF));
    _nodes['examples'] = _NodeData(type: 'examples', title: 'Examples', color: const Color(0xFF1E40AF));
    _nodes['exercises'] = _NodeData(type: 'exercises', title: 'Exercises', color: const Color(0xFF1E40AF));
    _nodes['vocabulary'] = _NodeData(type: 'vocabulary', title: 'Vocabulary', color: const Color(0xFF1E40AF));
    _nodes['practice'] = _NodeData(type: 'practice', title: 'Practice', color: const Color(0xFF1E40AF));
    _nodes['assessment'] = _NodeData(type: 'assessment', title: 'Assessment', color: const Color(0xFFF97316));
    _nodes['reading_agent'] = _NodeData(type: 'agent', title: 'Reading Coach', color: const Color(0xFF059669), agentType: 'reading');
    _nodes['speaking_agent'] = _NodeData(type: 'agent', title: 'Speaking Coach', color: const Color(0xFF059669), agentType: 'speaking');
    _nodes['writing_agent'] = _NodeData(type: 'agent', title: 'Writing Coach', color: const Color(0xFF059669), agentType: 'writing');
  }

  // ============================================================
  // BOARD PERSISTENCE (Tier 1)
  // ============================================================

  Future<void> _hydrateBoard() async {
    if (_boardId == null) return;
    setState(() => _isLoadingBoard = true);
    try {
      final board = await _api.getBoard(_boardId!);
      final canvasState = board['canvas_state'] as Map<String, dynamic>?;
      if (canvasState != null && canvasState.isNotEmpty) {
        _applyCanvasState(canvasState);
      }
      setState(() {
        _boardTitle = (board['title'] as String?) ?? 'Untitled lesson';
        _boardVersion = (board['version'] as num?)?.toInt() ?? 1;
        _saveStatus = 'SAVED v$_boardVersion';
        _isLoadingBoard = false;
      });
    } catch (e) {
      setState(() => _isLoadingBoard = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load board: $e')));
      }
    }
  }

  void _applyCanvasState(Map<String, dynamic> state) {
    _nodes.clear();
    _sources.clear();
    _textNotes.clear();
    _images.clear();
    _sourceCounter = 0;
    _textNoteCounter = 0;
    _imageCounter = 0;

    // Restore block order + collapsed state
    final blocks = state['blocks'] as List?;
    if (blocks != null) {
      _blockOrder = blocks.cast<String>();
    }
    final collapsed = state['collapsed'] as Map<String, dynamic>?;
    if (collapsed != null) {
      _blockCollapsed.clear();
      for (final e in collapsed.entries) {
        _blockCollapsed[e.key] = e.value as bool;
      }
    }

    final nodes = state['nodes'] as Map<String, dynamic>?;
    if (nodes != null) {
      for (final entry in nodes.entries) {
        final id = entry.key;
        final n = entry.value as Map<String, dynamic>;
        final data = n['data'] as Map<String, dynamic>?;
        if (data != null) {
          _nodes[id] = _NodeData(
            type: (data['type'] as String?) ?? 'note',
            title: (data['title'] as String?) ?? 'Node',
            color: _colorFromHex((data['color'] as String?) ?? '#1F2937'),
            headerLabel: data['headerLabel'] as String?,
            model: data['model'] as String?,
            agentType: data['agentType'] as String?,
            content: data['content'] as Map<String, dynamic>?,
            chatHistory: ((data['chatHistory'] as List?) ?? []).cast<Map<String, String>>(),
          );
          // Restore source data
          if (_nodes[id]!.type == 'source') {
            final sd = data['sourceData'] as Map<String, dynamic>?;
            if (sd != null) {
              final s = _SourceData(type: (sd['type'] as String?) ?? 'url', urlOrQuery: (sd['urlOrQuery'] as String?) ?? '');
              s.title = sd['title'] as String?;
              s.text = sd['text'] as String?;
              _sources.add(s);
            }
          }
          // Restore text note
          if (_nodes[id]!.type == 'note') {
            _textNotes[id] = (data['text'] as String?) ?? '';
            _textNoteCounter = math.max(_textNoteCounter, int.tryParse(id.replaceAll('note_', '')) ?? _textNoteCounter);
          }
          // Restore image
          if (_nodes[id]!.type == 'image') {
            final img = _ImageData(
              imageType: (data['imageType'] as String?) ?? 'illustration',
              prompt: data['prompt'] as String?,
              url: data['url'] as String?,
              revisedPrompt: data['revisedPrompt'] as String?,
            );
            _images[id] = img;
            _imageCounter = math.max(_imageCounter, int.tryParse(id.replaceAll('image_', '')) ?? _imageCounter);
          }
        }
      }
    }
    // Restore metadata
    final meta = state['metadata'] as Map<String, dynamic>?;
    if (meta != null) {
      _topicCtl.text = (meta['topic'] as String?) ?? '';
      _notesCtl.text = (meta['notes'] as String?) ?? '';
      _exam = (meta['exam'] as String?) ?? 'TOEFL_IBT';
      _level = (meta['level'] as String?) ?? 'B2';
      _itemType = (meta['item_type'] as String?) ?? 'grammar';
      _difficulty = (meta['difficulty'] as String?) ?? 'medium';
      final kpList = meta['kp_tags'] as List?;
      _kpTags.clear();
      if (kpList != null) {
        for (final kp in kpList) {
          final kpMap = kp as Map<String, dynamic>;
          _kpTags.add({'code': (kpMap['code'] as String?) ?? '', 'label': (kpMap['label'] as String?) ?? ''});
        }
      }
    }
    setState(() {});
  }

  Map<String, dynamic> _serializeCanvasState() {
    final nodes = <String, dynamic>{};
    for (final id in _nodes.keys) {
      final node = _nodes[id]!;
      final data = <String, dynamic>{
        'type': node.type,
        'title': node.title,
        'color': _hexFromColor(node.color),
        'headerLabel': node.headerLabel,
        'model': node.model,
        'agentType': node.agentType,
        'content': node.content,
        'chatHistory': node.chatHistory,
      };
      if (node.type == 'source') {
        final srcIdx = _sources.length > 0 ? _sources.length - 1 : 0;
        final sd = srcIdx < _sources.length ? _sources[srcIdx] : _SourceData();
        data['sourceData'] = {
          'type': sd.type,
          'urlOrQuery': sd.urlOrQuery,
          'title': sd.title,
          'text': sd.text,
        };
      }
      if (node.type == 'note' && _textNotes.containsKey(id)) {
        data['text'] = _textNotes[id];
      }
      if (node.type == 'image' && _images.containsKey(id)) {
        final img = _images[id]!;
        data['imageType'] = img.imageType;
        data['prompt'] = img.prompt;
        data['url'] = img.url;
        data['revisedPrompt'] = img.revisedPrompt;
      }
      nodes[id] = {'data': data};
    }
    return {
      'blocks': _blockOrder,
      'collapsed': _blockCollapsed,
      'nodes': nodes,
      'metadata': {
        'topic': _topicCtl.text,
        'notes': _notesCtl.text,
        'exam': _exam,
        'level': _level,
        'item_type': _itemType,
        'difficulty': _difficulty,
        'kp_tags': _kpTags,
      },
    };
  }

  void _markDirty() {
    _isDirty = true;
    setState(() => _saveStatus = 'UNSAVED');
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 3), () => _autosave());
  }

  Future<void> _autosave() async {
    if (_boardId == null || !_isDirty) return;
    setState(() => _saveStatus = 'SAVING...');
    try {
      final state = _serializeCanvasState();
      final result = await _api.saveCanvas(_boardId!, state, autosave: true);
      setState(() {
        _isDirty = false;
        _boardVersion = (result['version'] as num?)?.toInt() ?? _boardVersion;
        _saveStatus = 'SAVED v$_boardVersion';
      });
    } catch (e) {
      setState(() => _saveStatus = 'ERROR');
    }
  }

  Future<void> _explicitSave({String? label}) async {
    // Create board if it doesn't exist yet
    if (_boardId == null) {
      try {
        final board = await _api.createBoard(
          title: _topicCtl.text.trim().isEmpty ? 'Untitled lesson' : _topicCtl.text.trim(),
          syllabusId: widget.syllabusId,
          targetExam: _exam,
          cefrLevel: _level,
          kpTags: _kpTags,
        );
        _boardId = board['id'] as String?;
        _boardTitle = (board['title'] as String?) ?? _boardTitle;
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create board failed: $e')));
        return;
      }
    }
    setState(() => _saveStatus = 'SAVING...');
    try {
      final state = _serializeCanvasState();
      final result = await _api.saveCanvas(_boardId!, state, autosave: false, label: label ?? 'manual save');
      setState(() {
        _isDirty = false;
        _boardVersion = (result['version'] as num?)?.toInt() ?? _boardVersion;
        _saveStatus = 'SAVED v$_boardVersion';
      });
    } catch (e) {
      setState(() => _saveStatus = 'ERROR');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  // ---- Undo/Redo (Tier 1) ----

  void _pushUndoSnapshot() {
    _undoStack.add(_serializeCanvasState());
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_serializeCanvasState());
    final prev = _undoStack.removeLast();
    _applyCanvasState(prev);
    _markDirty();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_serializeCanvasState());
    final next = _redoStack.removeLast();
    _applyCanvasState(next);
    _markDirty();
  }

  // ============================================================
  // MATERIAL LIBRARY (Tier 1)
  // ============================================================

  Future<void> _loadMaterials() async {
    setState(() => _materialsLoading = true);
    try {
      final mats = await _api.listMaterials();
      setState(() {
        _materials.clear();
        _materials.addAll(mats);
        _materialsLoading = false;
      });
    } catch (e) {
      setState(() => _materialsLoading = false);
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final tpls = await _api.listTemplates();
      setState(() => _templates.clear());
      setState(() => _templates.addAll(tpls));
    } catch (e) {
      // Templates are optional — fail silently.
    }
  }

  void _addSourceNodeFromMaterial(Map<String, dynamic> material) {
    final id = 'source_$_sourceCounter';
    _sourceCounter++;
    final source = _SourceData(
      type: (material['type'] as String?) ?? 'url',
      urlOrQuery: (material['source_url'] as String?) ?? '',
    );
    source.title = (material['name'] as String?) ?? 'Material';
    source.text = material['extracted_text'] as String?;
    _sources.add(source);
    _nodes[id] = _NodeData(type: 'source', title: source.title ?? 'Source', color: const Color(0xFF6B8E7F), headerLabel: 'URL');
    _pushUndoSnapshot();
    _markDirty();
  }

  // ============================================================
  // COLOR HELPERS
  // ============================================================

  static Color _colorFromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) {
      return Color(int.parse('FF$h', radix: 16));
    } else if (h.length == 8) {
      return Color(int.parse(h, radix: 16));
    }
    return const Color(0xFF1F2937);
  }

  static String _hexFromColor(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  // ---- RAG source collection for AI calls ----

  List<Map<String, String>> get _sourcesAsJson {
    final list = <Map<String, String>>[];
    for (final s in _sources.where((s) => s.text != null && s.text!.isNotEmpty)) {
      list.add({'type': s.type, 'title': s.title ?? s.urlOrQuery, 'text': s.text!});
    }
    for (final entry in _textNotes.entries.where((e) => e.value.trim().isNotEmpty)) {
      list.add({'type': 'text', 'title': 'Sticky note', 'text': entry.value});
    }
    return list;
  }

  // ---- Node generation ----

  Future<void> _generateNode(String nodeId) async {
    if (_topicCtl.text.trim().isEmpty || _notesCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter topic and notes first')));
      return;
    }
    final node = _nodes[nodeId];
    if (node == null || node.type == 'input' || node.type == 'agent' || node.type == 'source' || node.type == 'note' || node.type == 'image') return;

    setState(() {
      node.isGenerating = true;
      node.error = null;
    });

    String? nodeContext;
    if (nodeId != 'theory' && _nodes['theory']?.content != null) {
      final t = _nodes['theory']!.content!;
      nodeContext = (t['theory'] as String?) ?? (t['title'] as String?);
    }

    try {
      final result = await _api.generateNode(
        type: node.type,
        topic: _topicCtl.text.trim(),
        notes: _notesCtl.text.trim(),
        exam: _exam,
        level: _level,
        itemType: _itemType,
        context: nodeContext,
        sources: _sourcesAsJson,
        useRag: true,
        difficulty: _difficulty,
        kpTags: _kpTags,
      );
      setState(() {
        node.content = result['content'] as Map<String, dynamic>?;
        node.isGenerating = false;
      });
      _markDirty();
    } catch (e) {
      setState(() {
        node.error = 'Generation failed';
        node.isGenerating = false;
      });
    }
  }

  Future<void> _sendAgentMessage(String nodeId, String message) async {
    final node = _nodes[nodeId];
    if (node == null) return;

    final contextParts = <String>[];
    for (final entry in _nodes.entries) {
      if (entry.value.type != 'input' && entry.value.type != 'agent' && entry.value.type != 'source' && entry.value.type != 'note' && entry.value.type != 'image' && entry.value.content != null) {
        contextParts.add('${entry.key}: ${entry.value.content.toString()}');
      }
    }

    setState(() {
      node.chatHistory.add({'role': 'user', 'content': message});
      node.isGenerating = true;
    });

    try {
      final result = await _api.agentChat(
        agent: node.agentType ?? 'general',
        message: message,
        context: contextParts.join('\n\n'),
        topic: _topicCtl.text,
        exam: _exam,
        level: _level,
        history: node.chatHistory.where((h) => h['role'] != 'user' || h['content'] != message).toList(),
        sources: _sourcesAsJson.isNotEmpty ? _sourcesAsJson : null,
      );
      setState(() {
        node.chatHistory.add({'role': 'assistant', 'content': (result['reply'] as String?) ?? ''});
        node.isGenerating = false;
      });
      _markDirty();
    } catch (e) {
      setState(() {
        node.chatHistory.add({'role': 'assistant', 'content': 'Error: could not get a response.'});
        node.isGenerating = false;
      });
    }
  }

  Future<void> _generateImage(String nodeId) async {
    final imgNode = _images[nodeId];
    final node = _nodes[nodeId];
    if (imgNode == null || node == null) return;
    if (_topicCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a topic first')));
      return;
    }
    setState(() {
      imgNode.isGenerating = true;
      imgNode.error = null;
    });
    try {
      final data = await _api.generateImage(
        type: imgNode.imageType,
        topic: _topicCtl.text.trim(),
        description: imgNode.prompt,
        exam: _exam,
        level: _level,
        size: '1024x1024',
      );
      setState(() {
        imgNode.url = data['url'] as String?;
        imgNode.revisedPrompt = data['revised_prompt'] as String?;
        imgNode.isGenerating = false;
      });
      _markDirty();
    } catch (e) {
      setState(() {
        imgNode.error = 'Image generation failed';
        imgNode.isGenerating = false;
      });
    }
  }

  // ---- Save to syllabus ----

  Future<void> _saveToSyllabus() async {
    final assembled = <String, dynamic>{};
    String title = _topicCtl.text.trim();

    final theory = _nodes['theory']?.content;
    if (theory != null) {
      assembled['theory'] = theory['theory'] ?? '';
      assembled['key_points'] = theory['key_points'] ?? [];
      if (theory['title'] != null) title = theory['title'] as String;
      if (theory['summary'] != null) assembled['summary'] = theory['summary'];
    }
    final examples = _nodes['examples']?.content;
    if (examples != null) assembled['examples'] = examples['examples'] ?? [];
    final exercises = _nodes['exercises']?.content;
    if (exercises != null) assembled['exercises'] = exercises['exercises'] ?? [];
    final vocab = _nodes['vocabulary']?.content;
    if (vocab != null) assembled['vocabulary'] = vocab['vocabulary'] ?? [];
    final practice = _nodes['practice']?.content;
    if (practice != null) assembled['practice_prompt'] = practice['practice_prompt'] ?? '';

    if (assembled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generate at least one node first')));
      return;
    }

    setState(() => _isSaving = true);
    // First, save the board canvas (creates board if needed)
    await _explicitSave(label: 'before syllabus export');
    try {
      final dio = ApiClient.create();
      await dio.post('/teacher/syllabi/${widget.syllabusId}/items', data: {
        'title': title,
        'description': assembled['summary'] ?? '',
        'source_type': 'ai_generated',
        'item_type': _itemType,
        'section': 'week-1',
        'difficulty': _level,
        'estimated_minutes': 25,
        'ai_generated_content': assembled,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to syllabus'), backgroundColor: OseeTheme.sage));
      context.go('/teacher/syllabi/${widget.syllabusId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: OseeTheme.accent));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ============================================================
  // BUILD — Notion-style block document
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: OseeTheme.paper,
        appBar: _buildAppBar(),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: _isLoadingBoard
                ? const Center(child: CircularProgressIndicator(color: OseeTheme.ink))
                : Stack(
                    children: [
                      ReorderableListView.builder(
                        key: const PageStorageKey('blocks'),
                        scrollController: _scrollCtl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _blockOrder.length + 1,
                        buildDefaultDragHandles: false,
                        onReorder: _onReorder,
                        proxyDecorator: (child, index, anim) => AnimatedBuilder(
                          animation: anim,
                          builder: (_, c) => Material(
                            color: Colors.transparent,
                            elevation: anim.value * 6,
                            child: c,
                          ),
                          child: child,
                        ),
                        itemBuilder: (ctx, index) {
                          if (index >= _blockOrder.length) {
                            return _buildSlashBar();
                          }
                          final blockId = _blockOrder[index];
                          return _buildBlock(blockId, index);
                        },
                      ),
                      _buildSlashMenu(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final saveColor = _saveStatus.startsWith('SAVED')
        ? OseeTheme.sage
        : _saveStatus == 'SAVING...'
            ? OseeTheme.gold
            : _saveStatus == 'ERROR'
                ? OseeTheme.accent
                : OseeTheme.stone;
    return AppBar(
      backgroundColor: OseeTheme.paper,
      elevation: 0,
      shape: Border(bottom: BorderSide(color: OseeTheme.ink, width: 2)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: OseeTheme.ink),
        onPressed: () => context.go('/teacher/syllabi/${widget.syllabusId}'),
      ),
      title: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OSEE', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: OseeTheme.ink, letterSpacing: -0.5)),
          Container(margin: const EdgeInsets.only(top: 2), width: 28, height: 2, color: OseeTheme.accent),
        ]),
        Container(margin: const EdgeInsets.symmetric(horizontal: 12), width: 1, height: 24, color: OseeTheme.cloud),
        Expanded(child: Text(_boardTitle.isEmpty ? 'Lesson Builder' : _boardTitle, style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, color: OseeTheme.ink, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: saveColor, borderRadius: BorderRadius.zero),
          child: Text(_saveStatus, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white)),
        ),
      ]),
      actions: [
        IconButton(icon: const Icon(Icons.dashboard_outlined, size: 18, color: OseeTheme.ink), tooltip: 'Templates', onPressed: _showTemplatesDialog),
        IconButton(icon: const Icon(Icons.history, size: 18, color: OseeTheme.ink), tooltip: 'Version History', onPressed: _showVersionHistory),
        IconButton(icon: const Icon(Icons.shield_outlined, size: 18, color: OseeTheme.ink), tooltip: 'AI Critic', onPressed: _runCriticReview),
        IconButton(icon: const Icon(Icons.share_outlined, size: 18, color: OseeTheme.ink), tooltip: 'Share', onPressed: _showShareDialog),
        IconButton(icon: const Icon(Icons.download_outlined, size: 18, color: OseeTheme.ink), tooltip: 'Export', onPressed: _showExportDialog),
        const SizedBox(width: 4),
        FilledButton.icon(
          onPressed: _isSaving ? null : () => _explicitSave(label: 'manual save'),
          icon: _isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white)) : const Icon(Icons.save, size: 14, color: Colors.white),
          label: Text(_isSaving ? 'SAVING…' : 'Save', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          style: FilledButton.styleFrom(backgroundColor: OseeTheme.ink, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    // 'setup' is always first — can't move it or move anything before it
    if (oldIndex == 0 || newIndex == 0) return;
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _blockOrder.removeAt(oldIndex);
      _blockOrder.insert(newIndex, item);
    });
    _markDirty();
  }

  // ---- Slash command bar — editor's note style ----
  Widget _buildSlashBar() {
    return Container(
      key: const ValueKey('slash'),
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _slashCtl,
        focusNode: _slashFocus,
        decoration: InputDecoration(
          hintText: 'Type / to add a block…',
          hintStyle: TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.stone.withValues(alpha: 0.6), fontStyle: FontStyle.italic),
          prefixIcon: Icon(Icons.add, size: 18, color: OseeTheme.gold),
          border: UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.cloud, width: 1)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.gold, width: 2)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: false,
        ),
        style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink),
        onTap: () {
          if (_slashCtl.text.isEmpty) {
            setState(() => _showSlashMenu = true);
          }
        },
        onChanged: (v) {
          setState(() => _showSlashMenu = v.startsWith('/'));
        },
      ),
    );
  }

  void _addBlockAfter(String afterId, String newBlockType) {
    final newId = '${newBlockType}_${DateTime.now().microsecondsSinceEpoch}';
    final idx = _blockOrder.indexOf(afterId);
    _blockOrder.insert(idx + 1, newId);
    final titles = {
      'theory': 'Theory', 'examples': 'Examples', 'exercises': 'Exercises',
      'vocabulary': 'Vocabulary', 'practice': 'Practice', 'assessment': 'Assessment',
      'reading_agent': 'Reading Coach', 'speaking_agent': 'Speaking Coach', 'writing_agent': 'Writing Coach',
      'source': 'Source', 'note': 'Note', 'image': 'Image',
    };
    final colors = {
      'theory': const Color(0xFF1E40AF), 'examples': const Color(0xFF1E40AF),
      'exercises': const Color(0xFF1E40AF), 'vocabulary': const Color(0xFF1E40AF),
      'practice': const Color(0xFF1E40AF), 'assessment': const Color(0xFFF97316),
      'reading_agent': const Color(0xFF059669), 'speaking_agent': const Color(0xFF059669),
      'writing_agent': const Color(0xFF059669), 'source': const Color(0xFF6B8E7F),
      'note': const Color(0xFFFBBF24), 'image': const Color(0xFFA66BD6),
    };
    _nodes[newId] = _NodeData(type: newBlockType, title: titles[newBlockType] ?? newBlockType, color: colors[newBlockType] ?? const Color(0xFF1F2937), agentType: newBlockType.contains('agent') ? newBlockType.split('_')[0] : null);
    _blockCollapsed[newId] = false;
    setState(() {
      _showSlashMenu = false;
      _slashCtl.clear();
    });
    _markDirty();
  }

  // ---- Individual block card — magazine section style ----
  Widget _buildBlock(String blockId, int index) {
    final node = _nodes[blockId];
    if (node == null) return const SizedBox.shrink();
    final collapsed = _isBlockCollapsed(blockId);
    final icon = _blockIcons[blockId] ?? Icons.widgets;
    final isSetup = blockId == 'setup';
    final hasContent = node.content != null;
    final status = node.isGenerating
        ? 'Generating'
        : hasContent
            ? 'Ready'
            : node.error != null
                ? 'Error'
                : '';
    final statusColor = node.isGenerating
        ? OseeTheme.gold
        : hasContent
            ? OseeTheme.sage
            : node.error != null
                ? OseeTheme.accent
                : OseeTheme.stone;

    // Block type determines visual treatment
    final isAgent = node.type == 'agent';
    final isAssessment = node.type == 'assessment';
    final isSource = node.type == 'source';
    final accentColor = isSetup
        ? OseeTheme.ink
        : isAgent
            ? OseeTheme.sage
            : isAssessment
                ? OseeTheme.accent
                : isSource
                    ? OseeTheme.sage
                    : node.color;
    final cardBg = isAgent
        ? OseeTheme.polaroidWhite
        : isSetup
            ? OseeTheme.ink
            : Colors.white;
    final headerBg = isSetup
        ? OseeTheme.ink
        : isAgent
            ? const Color(0xFFF0EDE5)
            : isAssessment
                ? const Color(0xFFFDF2F2)
                : OseeTheme.parchment.withValues(alpha: 0.4);
    final titleColor = isSetup ? Colors.white : OseeTheme.ink;
    final labelColor = isSetup ? OseeTheme.gold : OseeTheme.stone;

    return Container(
      key: ValueKey(blockId),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(2),
        border: Border(
          top: BorderSide(color: accentColor, width: 3),
          bottom: BorderSide(color: OseeTheme.cloud, width: 1),
          left: BorderSide(color: OseeTheme.cloud, width: 1),
          right: BorderSide(color: OseeTheme.cloud, width: 1),
        ),
        boxShadow: [
          BoxShadow(color: OseeTheme.ink.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
          BoxShadow(color: OseeTheme.ink.withValues(alpha: 0.03), blurRadius: 1, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          // Header — magazine section style
          InkWell(
            onTap: () => _toggleBlock(blockId),
            borderRadius: BorderRadius.zero,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: headerBg),
              child: Row(
                children: [
                  if (!isSetup)
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.drag_indicator, size: 16, color: OseeTheme.stone)),
                    )
                  else
                    const SizedBox(width: 20),
                  const SizedBox(width: 4),
                  Icon(icon, size: 18, color: isSetup ? OseeTheme.gold : accentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(blockId.toUpperCase().split('_').join(' '), style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: labelColor)),
                        Text(node.title, style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.w600, color: titleColor, height: 1.2)),
                      ],
                    ),
                  ),
                  if (status.isNotEmpty) ...[
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(status, style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1, color: isSetup ? Colors.white70 : statusColor)),
                  ],
                  const SizedBox(width: 6),
                  Icon(collapsed ? Icons.add : Icons.remove, size: 16, color: isSetup ? OseeTheme.gold : OseeTheme.stone),
                ],
              ),
            ),
          ),
          // Body — with animated expand/collapse
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: !collapsed
                ? Padding(padding: const EdgeInsets.all(16), child: _buildBlockBody(blockId, node))
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockBody(String blockId, _NodeData node) {
    switch (node.type) {
      case 'input': return _blockSetup();
      case 'source': return _blockSources(blockId);
      case 'theory':
      case 'examples':
      case 'exercises':
      case 'vocabulary':
      case 'practice':
        return _blockGenerate(blockId, node);
      case 'assessment': return _blockAssessment();
      case 'agent': return _blockAgent(blockId, node);
      default: return const SizedBox.shrink();
    }
  }

  // ---- Setup block — editorial form ----
  Widget _blockSetup() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _topicCtl,
        decoration: InputDecoration(
          labelText: 'LESSON TOPIC',
          labelStyle: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.stone),
          hintText: 'e.g. Conditional Sentences',
          hintStyle: TextStyle(fontFamily: 'Georgia', fontSize: 15, color: OseeTheme.stone.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
          border: UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.cloud, width: 1)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.ink, width: 2)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, color: OseeTheme.ink, height: 1.4),
        onChanged: (_) => _markDirty(),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _notesCtl,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: 'TEACHER NOTES',
          labelStyle: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.stone),
          hintText: 'What should this lesson cover?',
          hintStyle: TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.stone.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
          border: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.cloud, width: 1)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.ink, width: 2)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5),
        onChanged: (_) => _markDirty(),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _magDropdown('Exam', _exam, {'TOEFL_IBT': 'TOEFL iBT', 'TOEFL_ITP': 'TOEFL ITP', 'IELTS': 'IELTS', 'TOEIC': 'TOEIC', 'GENERAL': 'General'}, (v) { setState(() { _exam = v; _markDirty(); }); }),
        _magDropdown('Level', _level, {'A1': 'A1', 'A2': 'A2', 'B1': 'B1', 'B2': 'B2', 'C1': 'C1', 'C2': 'C2'}, (v) { setState(() { _level = v; _markDirty(); }); }),
        _magDropdown('Type', _itemType, {'grammar': 'Grammar', 'reading': 'Reading', 'writing': 'Writing', 'listening': 'Listening', 'speaking': 'Speaking', 'vocabulary': 'Vocabulary'}, (v) { setState(() { _itemType = v; _markDirty(); }); }),
        _magDropdown('Difficulty', _difficulty, {'easy': 'Easy', 'medium': 'Medium', 'hard': 'Hard', 'expert': 'Expert'}, (v) { setState(() { _difficulty = v; _markDirty(); }); }),
      ]),
    ]);
  }

  // ---- Sources block — magazine clippings style ----
  Widget _blockSources(String blockId) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_sources.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: OseeTheme.parchment.withValues(alpha: 0.3),
            border: Border.all(color: OseeTheme.cloud, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(children: [
            Icon(Icons.collections_bookmark_outlined, size: 28, color: OseeTheme.gold),
            const SizedBox(width: 12),
            Expanded(child: Text('No sources yet. Add a URL, paste text, or drag files to feed the AI with context.', style: TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.stone, fontStyle: FontStyle.italic, height: 1.5))),
          ]),
        )
      else
        ..._sources.asMap().entries.map((e) {
          final s = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: OseeTheme.polaroidWhite,
              border: Border(left: BorderSide(color: OseeTheme.sage, width: 3), top: BorderSide(color: OseeTheme.cloud, width: 1), bottom: BorderSide(color: OseeTheme.cloud, width: 1), right: BorderSide(color: OseeTheme.cloud, width: 1)),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: OseeTheme.ink.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1))],
            ),
            child: Row(children: [
              Icon(s.type == 'youtube' ? Icons.play_circle_outline : s.type == 'text' ? Icons.text_snippet : Icons.link, color: OseeTheme.sage, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.title ?? s.urlOrQuery, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, fontWeight: FontWeight.w600, color: OseeTheme.ink, fontStyle: FontStyle.italic)),
                Text(s.text != null ? '${s.text!.length} chars extracted' : 'Not fetched yet', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: OseeTheme.stone, letterSpacing: 0.5)),
              ])),
              if (s.text == null)
                TextButton(onPressed: () => _ingestSource('source_${e.key}', s), style: TextButton.styleFrom(foregroundColor: OseeTheme.accent, padding: const EdgeInsets.symmetric(horizontal: 8)), child: const Text('Fetch', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, decoration: TextDecoration.underline)))
              else
                Icon(Icons.check_circle, color: OseeTheme.sage, size: 16),
              const SizedBox(width: 4),
              IconButton(icon: const Icon(Icons.close, size: 12, color: OseeTheme.stone), onPressed: () { setState(() => _sources.removeAt(e.key)); _markDirty(); }, iconSize: 12, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
            ]),
          );
        }),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: FilledButton.tonalIcon(
          onPressed: _showAddMaterialDialog,
          icon: Icon(Icons.add_link, size: 14, color: OseeTheme.sage),
          label: const Text('Add URL / Text', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(backgroundColor: OseeTheme.parchment.withValues(alpha: 0.5), foregroundColor: OseeTheme.ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), padding: const EdgeInsets.symmetric(vertical: 10)),
        )),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          onPressed: _showBrainDumpDialog,
          icon: Icon(Icons.auto_awesome, size: 14, color: OseeTheme.gold),
          label: const Text('Brain Dump', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6), foregroundColor: OseeTheme.ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), padding: const EdgeInsets.symmetric(vertical: 10)),
        ),
      ]),
    ]);
  }

  // ---- Generate block — editorial AI generation ----
  Widget _blockGenerate(String blockId, _NodeData node) {
    final hasContent = node.content != null;
    final descriptions = {
      'theory': 'Generate the theory explanation — 3-5 paragraphs with key points.',
      'examples': 'Generate worked examples that demonstrate the concept.',
      'exercises': 'Generate 6-8 practice exercises mixing question types.',
      'vocabulary': 'Generate 5-8 key vocabulary terms with definitions and examples.',
      'practice': 'Generate a free-form practice task for students.',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!hasContent && !node.isGenerating)
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: OseeTheme.parchment.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
          child: Row(children: [
            Icon(Icons.auto_awesome, size: 20, color: OseeTheme.gold),
            const SizedBox(width: 10),
            Expanded(child: Text(descriptions[blockId] ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.stone, height: 1.5, fontStyle: FontStyle.italic))),
          ]),
        ),
      if (node.isGenerating)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(color: OseeTheme.parchment.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: node.color)),
            const SizedBox(height: 10),
            const Text('Generating…', style: TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.stone, fontStyle: FontStyle.italic)),
          ])),
        )
      else if (hasContent)
        ..._buildContentCards(node.content!, node.type)
      else
        Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: FilledButton.icon(
          onPressed: () => _generateNode(blockId),
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: const Text('Generate', style: TextStyle(fontFamily: 'Helvetica', fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
          style: FilledButton.styleFrom(backgroundColor: OseeTheme.ink, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
        ))),
      if (hasContent && !node.isGenerating)
        Padding(padding: const EdgeInsets.only(top: 10), child: OutlinedButton.icon(
          onPressed: () => _generateNode(blockId),
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('Regenerate', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          style: OutlinedButton.styleFrom(foregroundColor: OseeTheme.ink, side: BorderSide(color: OseeTheme.cloud, width: 1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
        )),
      if (node.error != null)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(node.error!, style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.accent, fontStyle: FontStyle.italic))),
    ]);
  }

  // ---- Assessment block ----
  Widget _blockAssessment() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: const Color(0xFFFDF2F2), borderRadius: BorderRadius.circular(2), border: Border(left: BorderSide(color: OseeTheme.accent, width: 2))),
        child: Row(children: [
          Icon(Icons.assignment, size: 20, color: OseeTheme.accent),
          const SizedBox(width: 10),
          Expanded(child: Text('Generate assessment artifacts from your lesson content.', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, height: 1.5, fontStyle: FontStyle.italic))),
        ]),
      ),
      _assessButton('Answer Key', 'answer_key', Icons.vpn_key),
      _assessButton('Rubric', 'rubric', Icons.grading),
      _assessButton('Exit Ticket', 'exit_ticket', Icons.confirmation_number),
      _assessButton('Quiz', 'quiz', Icons.quiz),
    ]);
  }

  // ---- Agent chat block — magazine sidebar style ----
  Widget _blockAgent(String blockId, _NodeData node) {
    _agentInputCtls.putIfAbsent(blockId, () => TextEditingController());
    final ctl = _agentInputCtls[blockId]!;
    return StatefulBuilder(
      builder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (node.chatHistory.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: OseeTheme.parchment.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              child: Row(children: [
                Icon(Icons.chat_bubble_outline, size: 18, color: OseeTheme.sage),
                const SizedBox(width: 8),
                Expanded(child: Text('Type a message below to start coaching with the ${node.title}.', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.stone, fontStyle: FontStyle.italic, height: 1.5))),
              ]),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 320),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFF5F3ED), borderRadius: BorderRadius.circular(2), border: Border.all(color: OseeTheme.cloud, width: 1)),
              child: ListView.builder(
                shrinkWrap: true,
                reverse: true,
                itemCount: node.chatHistory.length,
                itemBuilder: (_, i) {
                  final idx = node.chatHistory.length - 1 - i;
                  final msg = node.chatHistory[idx];
                  final isUser = msg['role'] == 'user';
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: isUser ? OseeTheme.sage.withValues(alpha: 0.12) : Colors.white,
                          border: isUser ? Border.all(color: OseeTheme.sage.withValues(alpha: 0.3), width: 1) : Border.all(color: OseeTheme.cloud, width: 1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(msg['content'] ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, height: 1.5)),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (node.isGenerating)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: OseeTheme.sage)))),
          Row(children: [
            Expanded(child: TextField(
              controller: ctl,
              decoration: InputDecoration(
                hintText: 'Ask the ${node.title}…',
                hintStyle: TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.stone.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
                border: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.cloud, width: 1)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.sage, width: 2)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              ),
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  _sendAgentMessage(blockId, v.trim());
                  ctl.clear();
                  setLocal(() {});
                }
              },
            )),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: node.isGenerating ? null : () {
                if (ctl.text.trim().isNotEmpty) {
                  _sendAgentMessage(blockId, ctl.text.trim());
                  ctl.clear();
                  setLocal(() {});
                }
              },
              style: FilledButton.styleFrom(backgroundColor: OseeTheme.sage, foregroundColor: Colors.white, minimumSize: const Size(42, 42), padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
              child: const Icon(Icons.send, size: 14, color: Colors.white),
            ),
          ]),
        ],
      ),
    );
  }

  // ---- Keyboard shortcuts ----
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;
    if (isCtrl && key == LogicalKeyboardKey.keyZ && !isShift) { _undo(); return KeyEventResult.handled; }
    if ((isCtrl && key == LogicalKeyboardKey.keyZ && isShift) || (isCtrl && key == LogicalKeyboardKey.keyY)) { _redo(); return KeyEventResult.handled; }
    if (isCtrl && key == LogicalKeyboardKey.keyS) { _explicitSave(label: 'keyboard save'); return KeyEventResult.handled; }
    if (key == LogicalKeyboardKey.escape) { FocusScope.of(context).unfocus(); return KeyEventResult.handled; }
    return KeyEventResult.ignored;
  }

  // ---- Slash menu overlay ----
  Widget _buildSlashMenu() {
    if (!_showSlashMenu) return const SizedBox.shrink();
    final options = [
      ('theory', 'Theory', Icons.menu_book, OseeTheme.ink),
      ('examples', 'Examples', Icons.lightbulb_outline, OseeTheme.ink),
      ('exercises', 'Exercises', Icons.quiz_outlined, OseeTheme.ink),
      ('vocabulary', 'Vocabulary', Icons.translate, OseeTheme.ink),
      ('practice', 'Practice', Icons.fitness_center, OseeTheme.ink),
      ('assessment', 'Assessment', Icons.assignment, OseeTheme.accent),
      ('reading_agent', 'Reading Coach', Icons.menu_book_outlined, OseeTheme.sage),
      ('speaking_agent', 'Speaking Coach', Icons.mic, OseeTheme.sage),
      ('writing_agent', 'Writing Coach', Icons.edit, OseeTheme.sage),
    ];
    return Positioned(
      bottom: 60,
      left: 0,
      right: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
              border: Border(top: BorderSide(color: OseeTheme.ink, width: 2), bottom: BorderSide(color: OseeTheme.cloud, width: 1), left: BorderSide(color: OseeTheme.cloud, width: 1), right: BorderSide(color: OseeTheme.cloud, width: 1)),
              boxShadow: [BoxShadow(color: OseeTheme.ink.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(10), child: Text('ADD BLOCK', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.stone))),
              Container(height: 1, color: OseeTheme.cloud),
              ...options.map((o) => ListTile(
                dense: true,
                leading: Icon(o.$3, size: 16, color: o.$4),
                title: Text(o.$2, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w600, color: OseeTheme.ink)),
                onTap: () {
                  _addBlockAfter(_blockOrder.last, o.$1);
                  setState(() => _showSlashMenu = false);
                  _slashCtl.clear();
                },
              )),
            ]),
          ),
        ),
      ),
    );
  }

  // ---- Magazine-styled dropdown ----
  Widget _magDropdown(String label, String value, Map<String, String> items, void Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 2, bottom: 2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: OseeTheme.cloud, width: 1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.stone)),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          isExpanded: true,
          isDense: true,
          dropdownColor: Colors.white,
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, fontWeight: FontWeight.w600),
          icon: const Icon(Icons.expand_more, size: 14, color: OseeTheme.stone),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, fontWeight: FontWeight.w500)))).toList(),
          onChanged: (v) => onChanged(v ?? value),
        ),
      ]),
    );
  }

  // ============================================================
  // SHARED WIDGETS (used by block builder)
  // ============================================================

  Widget _mobileDropdown(String label, String value, Map<String, String> items, void Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD1D5DB)), borderRadius: BorderRadius.circular(4)),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        isExpanded: true,
        isDense: true,
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 12, color: Color(0xFF1F2937))))).toList(),
        onChanged: (v) => onChanged(v ?? value),
      ),
    );
  }

  // ============================================================
  // CONTENT RENDERING
  // ============================================================

  List<Widget> _buildContentCards(Map<String, dynamic> content, String type) {
    final cards = <Widget>[];
    switch (type) {
      case 'theory':
        if (content['title'] != null) cards.add(_contentCard('Title', content['title'].toString()));
        if (content['summary'] != null) cards.add(_contentCard('Summary', content['summary'].toString()));
        if (content['theory'] != null) cards.add(_contentCard('Theory', content['theory'].toString()));
        if (content['key_points'] is List) cards.add(_contentListCard('Key Points', (content['key_points'] as List).cast<String>()));
      case 'examples':
        if (content['examples'] is List) {
          for (var i = 0; i < (content['examples'] as List).length; i++) {
            final ex = (content['examples'] as List)[i] as Map;
            cards.add(_contentCard('Example ${i + 1}', '${ex['input'] ?? ''}\n→ ${ex['output'] ?? ''}\n${ex['explanation'] ?? ''}'));
          }
        }
      case 'exercises':
        if (content['exercises'] is List) {
          for (var i = 0; i < (content['exercises'] as List).length; i++) {
            final ex = (content['exercises'] as List)[i] as Map;
            cards.add(_contentCard('Q${i + 1} (${ex['type'] ?? 'question'})', '${ex['question'] ?? ''}\nAnswer: ${ex['answer'] ?? ''}'));
          }
        }
      case 'vocabulary':
        if (content['vocabulary'] is List) {
          for (var i = 0; i < (content['vocabulary'] as List).length; i++) {
            final v = (content['vocabulary'] as List)[i] as Map;
            cards.add(_contentCard(v['word']?.toString() ?? 'Word', '${v['definition'] ?? ''}\nExample: ${v['example'] ?? ''}'));
          }
        }
      case 'practice':
        if (content['practice_prompt'] != null) cards.add(_contentCard('Practice Task', content['practice_prompt'].toString()));
        if (content['practice_type'] != null) cards.add(_contentCard('Type', content['practice_type'].toString()));
      default:
        cards.add(_contentCard('Content', content.toString()));
    }
    return cards;
  }

  Widget _contentCard(String label, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: OseeTheme.gold, width: 2), top: BorderSide(color: OseeTheme.cloud, width: 1), bottom: BorderSide(color: OseeTheme.cloud, width: 1), right: BorderSide(color: OseeTheme.cloud, width: 1)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty && label != 'Content')
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label.toUpperCase(), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.stone))),
          Text(body, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.6)),
        ],
      ),
    );
  }

  Widget _contentListCard(String label, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OseeTheme.polaroidWhite,
        border: Border(left: BorderSide(color: OseeTheme.accent, width: 2), top: BorderSide(color: OseeTheme.cloud, width: 1), bottom: BorderSide(color: OseeTheme.cloud, width: 1), right: BorderSide(color: OseeTheme.cloud, width: 1)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label.toUpperCase(), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.stone))),
          ...items.map((item) => Padding(padding: const EdgeInsets.only(top: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(margin: const EdgeInsets.only(top: 5, right: 8), width: 4, height: 4, decoration: const BoxDecoration(color: OseeTheme.accent, shape: BoxShape.circle)),
            Expanded(child: Text(item, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, height: 1.5))),
          ]))),
        ],
      ),
    );
  }

  Widget _assessButton(String label, String type, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: _boardId == null ? null : () async {
          try {
            final result = await _api.generateAssessment(_boardId!, type: type, topic: _topicCtl.text.trim(), level: _level, exam: _exam, nodeContent: _nodes['exercises']?.content);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label generated'), backgroundColor: OseeTheme.sage));
              _showAssessmentResult(label, result['content'] as Map<String, dynamic>? ?? {});
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
          }
        },
        icon: Icon(icon, size: 16, color: OseeTheme.gold),
        label: Text(label, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w600, color: OseeTheme.ink)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: OseeTheme.cloud, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }

  void _showAssessmentResult(String label, Map<String, dynamic> content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, sc) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Expanded(child: ListView(children: _buildContentCards(content, 'assessment'))),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TEMPLATES DIALOG (Tier 2)
  // ============================================================

  Future<void> _showTemplatesDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB))),
        title: const Text('STARTER TEMPLATES', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFF1F2937))),
        content: SizedBox(width: 520, child: _templates.isEmpty
            ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5)))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: _templates.map((tpl) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(6)),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: const Color(0xFFF3F4F6), child: Icon(Icons.dashboard_outlined, size: 16, color: (tpl['is_official'] as bool? ?? false) ? const Color(0xFF059669) : const Color(0xFF6B7280))),
                      title: Text(tpl['name'] as String? ?? 'Template', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: Text(tpl['description'] as String? ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Georgia', fontSize: 10, color: Color(0xFF6B7280))),
                      trailing: FilledButton(
                        onPressed: () async {
                          final tplId = tpl['id'] as String;
                          try {
                            final full = await _api.getTemplate(tplId);
                            final canvasState = full['canvas_state'] as Map<String, dynamic>?;
                            if (canvasState != null) {
                              _pushUndoSnapshot();
                              _applyCanvasState(canvasState);
                              _markDirty();
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Load failed: $e')));
                          }
                        },
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF072c1f), padding: const EdgeInsets.symmetric(horizontal: 12)),
                        child: const Text('Use', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  );
                }).toList(),
              )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF6B7280))))],
      ),
    );
  }

  // ============================================================
  // VERSION HISTORY (Tier 1)
  // ============================================================

  Future<void> _showVersionHistory() async {
    if (_boardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save the board first to enable version history')));
      return;
    }
    List<Map<String, dynamic>> versions = [];
    bool loading = true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          if (loading) {
            () async {
              try {
                versions = await _api.listVersions(_boardId!);
              } catch (e) {
                // ignore
              }
              setLocal(() => loading = false);
            }();
            return const AlertDialog(content: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5))));
          }
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB))),
            title: const Text('VERSION HISTORY', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFF1F2937))),
            content: SizedBox(width: 440, child: versions.isEmpty
                ? const Text('No saved versions yet. Use "Save" to create a version snapshot.', style: TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Color(0xFF6B7280)))
                : ListView.builder(shrinkWrap: true, itemCount: versions.length, itemBuilder: (_, i) {
                    final v = versions[i];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: const Color(0xFFF3F4F6), child: Text('v${v['version']}', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700))),
                      title: Text(v['label'] as String? ?? 'Version ${v['version']}', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w600)),
                      subtitle: Text(v['created_at'] as String? ?? '', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: Color(0xFF9CA3AF))),
                      trailing: TextButton(
                        onPressed: () async {
                          try {
                            final restored = await _api.restoreVersion(_boardId!, v['id'] as String);
                            final canvasState = restored['canvas_state'] as Map<String, dynamic>?;
                            if (canvasState != null) _applyCanvasState(canvasState);
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
                          }
                        },
                        child: const Text('Restore'),
                      ),
                    );
                  })),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF6B7280))))],
          );
        },
      ),
    );
  }

  // ============================================================
  // AI CRITIC REVIEW (Tier 2)
  // ============================================================

  Future<void> _runCriticReview() async {
    if (_boardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save the board first')));
      return;
    }
    final genNodes = _nodes.entries.where((e) => e.value.content != null && e.value.type != 'input' && e.value.type != 'source' && e.value.type != 'note' && e.value.type != 'image').map((e) => {
      'id': e.key, 'type': e.value.type, 'title': e.value.title, 'content': e.value.content,
    }).toList();
    if (genNodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generate at least one node first')));
      return;
    }
    setState(() => _isReviewing = true);
    try {
      final review = await _api.reviewLesson(_boardId!, nodes: genNodes, targetExam: _exam, cefrLevel: _level, kpTags: _kpTags);
      setState(() {
        _criticReview = review;
        _isReviewing = false;
      });
      _showCriticResultsDialog(review);
    } catch (e) {
      setState(() => _isReviewing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Review failed: $e')));
    }
  }

  Future<void> _showCriticResultsDialog(Map<String, dynamic> review) async {
    final score = (review['overall_score'] as num?)?.toInt() ?? 0;
    final findings = (review['findings'] as List?) ?? [];
    final summary = review['summary'] as String? ?? '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB))),
        title: Row(children: [
          const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF1F2937)),
          const SizedBox(width: 6),
          const Text('AI CRITIC REVIEW', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFF1F2937))),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: score >= 80 ? const Color(0xFF059669) : score >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444), borderRadius: BorderRadius.circular(12)), child: Text('$score/100', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
        ]),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(summary, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Color(0xFF1F2937), height: 1.5)),
          const SizedBox(height: 14),
          const Text('FINDINGS', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          ...findings.map((f) {
            final fm = f as Map<String, dynamic>;
            final sev = fm['severity'] as String? ?? 'info';
            final sevColor = sev == 'critical' ? const Color(0xFFEF4444) : sev == 'error' ? const Color(0xFFF97316) : sev == 'warning' ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6);
            return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: sevColor.withValues(alpha: 0.06), border: Border(left: BorderSide(color: sevColor, width: 3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(sev == 'critical' || sev == 'error' ? Icons.error_outline : sev == 'warning' ? Icons.warning_amber : Icons.info_outline, size: 12, color: sevColor), const SizedBox(width: 4), Text('${fm['category'] ?? 'other'}', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, color: sevColor)), const Spacer(), Text('node: ${fm['node_id']}', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, color: Color(0xFF9CA3AF)))]),
              const SizedBox(height: 4),
              Text(fm['message'] as String? ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF1F2937), height: 1.4)),
              if (fm['suggestion'] != null) ...[const SizedBox(height: 2), Text('→ ${fm['suggestion']}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 10, color: Color(0xFF6B7280), fontStyle: FontStyle.italic))],
            ]));
          }),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF6B7280))))],
      ),
    );
  }

  // ============================================================
  // SHARE DIALOG (Tier 3)
  // ============================================================

  Future<void> _showShareDialog() async {
    if (_boardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save the board first')));
      return;
    }
    final emailCtl = TextEditingController();
    String permission = 'view';
    List<Map<String, dynamic>> shares = [];
    bool loading = true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          if (loading) {
            () async {
              try { shares = await _api.listShares(_boardId!); } catch (e) {}
              setLocal(() => loading = false);
            }();
          }
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB))),
            title: const Text('SHARE BOARD', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFF1F2937))),
            content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: emailCtl, decoration: const InputDecoration(labelText: 'Teacher email', border: OutlineInputBorder(), isDense: true), style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Color(0xFF1F2937))),
              const SizedBox(height: 8),
              Row(children: [_mobileDropdown('Permission', permission, const {'view': 'View only', 'edit': 'Can edit', 'admin': 'Admin'}, (v) => setLocal(() => permission = v))]),
              const SizedBox(height: 12),
              if (shares.isNotEmpty) ...[
                const Text('CURRENT SHARES', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Color(0xFF6B7280))),
                const SizedBox(height: 6),
                ...shares.map((s) => ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(s['shared_with_email'] as String? ?? '', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11)), subtitle: Text('${s['permission']} · ${s['status']}', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: Color(0xFF9CA3AF))), trailing: IconButton(icon: const Icon(Icons.close, size: 12), onPressed: () async { await _api.revokeShare(_boardId!, s['id'] as String); setLocal(() => shares.removeWhere((x) => x['id'] == s['id'])); }))),
              ],
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF6B7280)))),
              FilledButton(
                onPressed: () async {
                  if (emailCtl.text.trim().isEmpty) return;
                  try {
                    final share = await _api.shareBoard(_boardId!, emailCtl.text.trim(), permission);
                    setLocal(() { shares.insert(0, share); emailCtl.clear(); });
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Share failed: $e')));
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF072c1f)),
                child: const Text('Send Invite'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // EXPORT DIALOG (Tier 3)
  // ============================================================

  Future<void> _showExportDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB))),
        title: const Text('EXPORT', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFF1F2937))),
        content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.picture_as_pdf, size: 18), title: const Text('Export as PDF', style: TextStyle(fontFamily: 'Helvetica', fontSize: 12)), onTap: () { Navigator.pop(ctx); _exportPdf(); }),
          ListTile(leading: const Icon(Icons.data_object, size: 18), title: const Text('Export as JSON', style: TextStyle(fontFamily: 'Helvetica', fontSize: 12)), onTap: () { Navigator.pop(ctx); _exportJson(); }),
          ListTile(leading: const Icon(Icons.school, size: 18), title: const Text('Save to Syllabus', style: TextStyle(fontFamily: 'Helvetica', fontSize: 12)), onTap: () { Navigator.pop(ctx); _saveToSyllabus(); }),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF6B7280))))],
      ),
    );
  }

  void _exportJson() {
    final state = _serializeCanvasState();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(state);
    final blob = html.Blob([jsonStr], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)..download = '${_boardTitle.replaceAll(' ', '_')}_board.json'..click();
    html.Url.revokeObjectUrl(url);
  }

  void _exportPdf() {
    // Use browser print on the current view
    html.window.print();
  }

  // ============================================================
  // SHORTCUTS HELP (Tier 3)
  // ============================================================

  Future<void> _showShortcutsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB))),
        title: const Text('KEYBOARD SHORTCUTS', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFF1F2937))),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: const [
          Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Row(children: [Text('Ctrl+Z', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w600)), SizedBox(width: 12), Text('Undo', style: TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF6B7280)))])),
          Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Row(children: [Text('Ctrl+Shift+Z', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w600)), SizedBox(width: 12), Text('Redo', style: TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF6B7280)))])),
          Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Row(children: [Text('Ctrl+S', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w600)), SizedBox(width: 12), Text('Save', style: TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF6B7280)))])),
          Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Row(children: [Text('Esc', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w600)), SizedBox(width: 12), Text('Unfocus', style: TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF6B7280)))])),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF6B7280))))],
      ),
    );
  }

  // ============================================================
  // BRAIN DUMP DIALOG — batch ingest multiple sources
  // ============================================================

  Future<void> _showBrainDumpDialog() async {
    final urlsCtl = TextEditingController();
    final textCtl = TextEditingController();
    final clusterCtl = TextEditingController();
    bool isIngesting = false;
    String? resultText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB))),
          title: const Text('BRAIN DUMP', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFF1F2937))),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dump all your sources at once — URLs, YouTube links, and text — and the AI will auto-embed them into your knowledge base for semantic search across all future lesson generations.', style: TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Color(0xFF6B7280), height: 1.5)),
                const SizedBox(height: 16),
                TextField(controller: clusterCtl, decoration: const InputDecoration(labelText: 'Cluster label (optional)', border: OutlineInputBorder()), style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: Color(0xFF1F2937))),
                const SizedBox(height: 12),
                const Text('URLS / YOUTUBE LINKS (one per line)', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                TextField(controller: urlsCtl, maxLines: 5, decoration: const InputDecoration(hintText: 'https://en.wikipedia.org/wiki/Conditional_sentence\nhttps://youtube.com/watch?v=...', border: OutlineInputBorder()), style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Color(0xFF1F2937))),
                const SizedBox(height: 12),
                const Text('PASTED TEXT', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                TextField(controller: textCtl, maxLines: 5, decoration: const InputDecoration(hintText: 'Paste any text content — transcripts, notes, textbook excerpts…', border: OutlineInputBorder()), style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Color(0xFF1F2937))),
                if (resultText != null) ...[
                  const SizedBox(height: 12),
                  Text(resultText!, style: TextStyle(fontFamily: 'Georgia', fontSize: 11, color: isIngesting ? const Color(0xFF6B7280) : const Color(0xFF059669), fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
            FilledButton.icon(
              onPressed: isIngesting ? null : () async {
                final urls = urlsCtl.text.split('\n').where((l) => l.trim().isNotEmpty).map((l) => l.trim()).toList();
                final textContent = textCtl.text.trim();
                if (urls.isEmpty && textContent.isEmpty) return;
                setLocal(() { isIngesting = true; resultText = 'Ingesting ${urls.length} URLs + text...'; });
                final sources = <Map<String, dynamic>>[];
                for (final url in urls) {
                  if (url.contains('youtube.com') || url.contains('youtu.be')) {
                    sources.add({'type': 'youtube', 'url': url});
                  } else {
                    sources.add({'type': 'url', 'url': url});
                  }
                }
                if (textContent.isNotEmpty) sources.add({'type': 'text', 'content': textContent});
                try {
                  final dio = ApiClient.create();
                  final r = await dio.post('/ai/batch-ingest', data: {
                    'sources': sources,
                    if (clusterCtl.text.trim().isNotEmpty) 'cluster_label': clusterCtl.text.trim(),
                  });
                  final data = r.data as Map<String, dynamic>;
                  final ingested = data['ingested'] as List? ?? [];
                  final embedded = data['embedded_count'] as int? ?? 0;
                  final errors = data['errors'] as List? ?? [];
                  for (var i = 0; i < ingested.length; i++) {
                    final src = ingested[i] as Map<String, dynamic>;
                    _sourceCounter++;
                    final source = _SourceData(type: src['type'] as String? ?? 'url');
                    source.title = src['title'] as String?;
                    source.text = src['text'] as String?;
                    _sources.add(source);
                  }
                  setLocal(() { isIngesting = false; resultText = '${ingested.length} ingested, $embedded embedded into RAG${errors.isNotEmpty ? ', ${errors.length} errors' : ''}'; });
                  setState(() {});
                  await Future.delayed(const Duration(seconds: 2));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setLocal(() { isIngesting = false; resultText = 'Failed: $e'; });
                }
              },
              icon: isIngesting
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 12),
              label: Text(isIngesting ? 'DUMPING…' : 'DUMP & EMBED', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF072c1f)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ADD MATERIAL DIALOG
  // ============================================================

  Future<void> _showAddMaterialDialog() async {
    final nameCtl = TextEditingController();
    final urlCtl = TextEditingController();
    final textCtl = TextEditingController();
    String type = 'url';
    bool isIngesting = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE5E7EB))),
          title: const Text('ADD MATERIAL', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFF1F2937))),
          content: SizedBox(width: 440, child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: nameCtl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), isDense: true), style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Color(0xFF1F2937))),
              const SizedBox(height: 10),
              Row(children: [
                _mobileDropdown('Type', type, const {'url': 'URL', 'youtube': 'YouTube', 'text': 'Text'}, (v) => setLocal(() => type = v)),
              ]),
              const SizedBox(height: 10),
              if (type == 'text')
                TextField(controller: textCtl, maxLines: 5, decoration: const InputDecoration(hintText: 'Paste text content…', border: OutlineInputBorder(), isDense: true), style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Color(0xFF1F2937)))
              else
                TextField(controller: urlCtl, decoration: InputDecoration(hintText: type == 'youtube' ? 'https://youtube.com/watch?v=…' : 'https://…', border: const OutlineInputBorder(), isDense: true), style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Color(0xFF1F2937))),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
            FilledButton.icon(
              onPressed: isIngesting ? null : () async {
                if (nameCtl.text.trim().isEmpty) return;
                setLocal(() => isIngesting = true);
                try {
                  final mat = await _api.ingestMaterial(
                    name: nameCtl.text.trim(),
                    type: type,
                    url: type != 'text' ? urlCtl.text.trim() : null,
                    content: type == 'text' ? textCtl.text.trim() : null,
                  );
                  setState(() => _materials.insert(0, mat));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setLocal(() => isIngesting = false);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
              icon: isIngesting ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white)) : const Icon(Icons.add, size: 12),
              label: Text(isIngesting ? 'ADDING…' : 'ADD', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF072c1f)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final input = html.FileUploadInputElement()..accept = '.pdf,.txt,.docx,text/*,application/pdf';
    input.click();
    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return;
    for (final file in files) {
      final name = file.name;
      final isPdf = name.toLowerCase().endsWith('.pdf');
      final type = isPdf ? 'pdf' : 'text';
      final reader = html.FileReader();
      final completer = Completer<String>();
      reader.onLoadEnd.listen((_) {
        final result = reader.result;
        if (result is String) {
          completer.complete(result);
        } else if (result is ByteBuffer) {
          final bytes = result.asUint8List();
          completer.complete(base64Encode(bytes));
        } else {
          completer.complete('');
        }
      });
      reader.onError.listen((_) => completer.complete(''));
      if (isPdf) {
        reader.readAsArrayBuffer(file);
      } else {
        reader.readAsText(file);
      }
      final content = await completer.future;
      if (content.isEmpty) continue;
      try {
        final mat = await _api.ingestMaterial(
          name: name,
          type: type,
          content: content,
          filename: name,
        );
        setState(() => _materials.insert(0, mat));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _ingestMaterialToRag(String materialId) async {
    try {
      final result = await _api.ingestMaterialToRag(materialId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${result['embedded_chunks'] ?? 0} chunks embedded into RAG'),
          backgroundColor: const Color(0xFF059669),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('RAG ingest failed: $e')));
    }
  }

  Future<void> _deleteMaterial(String materialId) async {
    try {
      await _api.deleteMaterial(materialId);
      setState(() => _materials.removeWhere((m) => m['id'] == materialId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _ingestSource(String nodeId, _SourceData source) async {
    setState(() => source.isIngesting = true);
    try {
      final dio = ApiClient.create();
      final r = await dio.post('/ai/ingest-source', data: {
        'type': source.type,
        if (source.type == 'text') 'content': source.urlOrQuery,
        if (source.type != 'text') 'url': source.urlOrQuery,
      });
      final data = r.data as Map<String, dynamic>;
      setState(() {
        source.title = data['title'] as String?;
        source.text = data['text'] as String?;
        source.isIngesting = false;
      });
      _markDirty();
    } catch (e) {
      setState(() {
        source.text = null;
        source.error = 'Failed to ingest';
        source.isIngesting = false;
      });
    }
  }
}

// ============================================================
// MODELS
// ============================================================

class _NodeData {
  final String type; // input | theory | examples | exercises | vocabulary | practice | agent | source | note | image
  final String title;
  final Color color;
  final String? headerLabel; // Remalt-style: "Remalt AI Prompt", "Remalt Chat"
  final String? model; // "remic", "gpt-image-1"
  final String? agentType; // for agent nodes
  Map<String, dynamic>? content;
  bool isGenerating;
  String? error;
  final List<Map<String, String>> chatHistory;

  _NodeData({
    required this.type,
    required this.title,
    required this.color,
    this.headerLabel,
    this.model,
    this.agentType,
    this.content,
    this.isGenerating = false,
    this.error,
    this.chatHistory = const [],
  });
}

class _SourceData {
  String type;
  String urlOrQuery;
  String? title;
  String? text;
  String? error;
  bool isIngesting;

  _SourceData({this.type = 'url', this.urlOrQuery = '', this.title, this.text, this.error, this.isIngesting = false});
}

class _ImageData {
  String imageType;
  String? prompt;
  String? url;
  String? revisedPrompt;
  bool isGenerating;
  String? error;

  _ImageData({this.imageType = 'illustration', this.prompt, this.url, this.revisedPrompt, this.isGenerating = false, this.error});
}

// ============================================================
// IMAGE DECODER — handle base64 data URIs from gpt-image-1
// ============================================================

Uint8List _decodeImage(String url) {
  if (url.startsWith('data:image/')) {
    final comma = url.indexOf(',');
    if (comma != -1) {
      final b64 = url.substring(comma + 1);
      return base64Decode(b64);
    }
  }
  return Uint8List(0);
}