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

/// Remalt-style mind-map canvas for OSEE lesson creation.
///
/// Visual design adapted from remalt.com:
///  - Light/white canvas background with subtle dot grid (like Miro/remalt)
///  - Large spacious node cards (360x270+)
///  - Remalt-style colored node headers with model names
///  - Sticky note nodes (yellow cards for labels/annotations)
///  - Image nodes (generated via gpt-image-1)
///  - Smoothstep bezier edges in teal/green
///  - Floating toolbar with node-type buttons
///  - Zoom controls + fit-to-screen
///  - Multi-select bounding box
///  - Resizable nodes
///  - Drag visual feedback (shadow + scale)
///
/// Workflow: source nodes → input → per-output AI generation nodes → text
/// output nodes → specialist agent chat nodes. All connected by edges.
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
  bool _libraryOpen = true;

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

  // Snap-to-grid + alignment
  bool _snapToGrid = true;
  static const double _gridSize = 20.0;
  Offset? _alignGuideX;
  Offset? _alignGuideY;

  // Onboarding
  bool _showOnboarding = false;
  int _onboardingStep = 0;

  // Canvas transform
  Offset _pan = Offset.zero;
  double _zoom = 1.0;
  Offset? _dragStart;

  // Node positions (in canvas space, before transform)
  final Map<String, Offset> _nodePositions = {};
  // Node sizes (resizable)
  final Map<String, Size> _nodeSizes = {};
  // Node data
  final Map<String, _NodeData> _nodes = {};
  String? _selectedNode;
  String? _draggingNode;
  bool _isDraggingNode = false;
  String? _resizingNode;

  // Multi-select
  final Set<String> _selectedNodes = {};
  Offset? _selectionStart;
  Rect? _selectionRect;

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

  @override
  void initState() {
    super.initState();
    _api = ref.read(mindBoardApiProvider);
    _boardId = widget.boardId;
    _initNodes();
    _setupFileDrop();
    if (_boardId != null) {
      _hydrateBoard();
    } else {
      _showOnboarding = true;
    }
    _loadMaterials();
    _loadTemplates();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _teardownFileDrop();
    super.dispose();
  }

  // ---- File drag-drop (HTML5) ----
  bool _isDraggingFile = false;
  void _setupFileDrop() {
    html.document.onDragOver.listen((e) {
      e.preventDefault();
      if (!_isDraggingFile) setState(() => _isDraggingFile = true);
    });
    html.document.onDragLeave.listen((e) {
      e.preventDefault();
      if (e.relatedTarget == null) setState(() => _isDraggingFile = false);
    });
    html.document.onDrop.listen((e) {
      e.preventDefault();
      setState(() => _isDraggingFile = false);
      _handleDroppedFiles(e.dataTransfer?.files ?? <html.File>[]);
    });
  }

  void _teardownFileDrop() {
    // Listeners are auto-cleaned when the element is GC'd; nothing explicit needed.
  }

  Future<void> _handleDroppedFiles(List<html.File> files) async {
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
    _nodePositions.clear();
    _nodeSizes.clear();
    _nodes.clear();
    _sources.clear();
    _textNotes.clear();
    _images.clear();
    _sourceCounter = 0;
    _textNoteCounter = 0;
    _imageCounter = 0;

    final nodes = state['nodes'] as Map<String, dynamic>?;
    if (nodes != null) {
      for (final entry in nodes.entries) {
        final id = entry.key;
        final n = entry.value as Map<String, dynamic>;
        final pos = n['position'] as Map<String, dynamic>?;
        final sz = n['size'] as Map<String, dynamic>?;
        final data = n['data'] as Map<String, dynamic>?;
        if (pos != null) {
          _nodePositions[id] = Offset((pos['x'] as num).toDouble(), (pos['y'] as num).toDouble());
        }
        if (sz != null) {
          _nodeSizes[id] = Size((sz['w'] as num).toDouble(), (sz['h'] as num).toDouble());
        }
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
      final pos = _nodePositions[id];
      final sz = _nodeSizes[id];
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
      nodes[id] = {
        'position': {'x': pos?.dx ?? 0, 'y': pos?.dy ?? 0},
        'size': {'w': sz?.width ?? 360, 'h': sz?.height ?? 200},
        'data': data,
      };
    }
    return {
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
    _nodePositions[id] = Offset(-400, 220.0 + (_sources.length * 150));
    final source = _SourceData(
      type: (material['type'] as String?) ?? 'url',
      urlOrQuery: (material['source_url'] as String?) ?? '',
    );
    source.title = (material['name'] as String?) ?? 'Material';
    source.text = material['extracted_text'] as String?;
    _sources.add(source);
    _nodes[id] = _NodeData(type: 'source', title: source.title ?? 'Source', color: const Color(0xFF6B8E7F), headerLabel: 'URL');
    _nodeSizes[id] = const Size(280, 120);
    _pushUndoSnapshot();
    setState(() => _selectedNode = id);
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

  void _initNodes() {
    // Layout like remalt: source on left, input, output prompts in center column, agent chats on right
    _nodePositions['input'] = const Offset(40, 220);
    _nodePositions['theory'] = const Offset(440, 60);
    _nodePositions['examples'] = const Offset(440, 280);
    _nodePositions['exercises'] = const Offset(440, 500);
    _nodePositions['vocabulary'] = const Offset(440, 720);
    _nodePositions['practice'] = const Offset(440, 940);
    _nodePositions['reading_agent'] = const Offset(880, 140);
    _nodePositions['speaking_agent'] = const Offset(880, 400);
    _nodePositions['writing_agent'] = const Offset(880, 660);

    // Remalt-style prompt nodes — model is "remic" / "Remalt AI Prompt"
    _nodes['input'] = _NodeData(type: 'input', title: 'INPUT', color: const Color(0xFF1F2937), headerLabel: 'Remalt AI · Config');
    _nodes['theory'] = _NodeData(type: 'theory', title: 'Theory', color: const Color(0xFF1E40AF), headerLabel: 'Remalt AI Prompt', model: 'remic');
    _nodes['examples'] = _NodeData(type: 'examples', title: 'Examples', color: const Color(0xFF1E40AF), headerLabel: 'Remalt AI Prompt', model: 'remic');
    _nodes['exercises'] = _NodeData(type: 'exercises', title: 'Exercises', color: const Color(0xFF1E40AF), headerLabel: 'Remalt AI Prompt', model: 'remic');
    _nodes['vocabulary'] = _NodeData(type: 'vocabulary', title: 'Vocabulary', color: const Color(0xFF1E40AF), headerLabel: 'Remalt AI Prompt', model: 'remic');
    _nodes['practice'] = _NodeData(type: 'practice', title: 'Practice', color: const Color(0xFF1E40AF), headerLabel: 'Remalt AI Prompt', model: 'remic');
    // Chat agents — green header like remalt
    _nodes['reading_agent'] = _NodeData(type: 'agent', title: 'Reading Coach', color: const Color(0xFF059669), headerLabel: 'Remalt Chat', model: 'remic', agentType: 'reading');
    _nodes['speaking_agent'] = _NodeData(type: 'agent', title: 'Speaking Coach', color: const Color(0xFF059669), headerLabel: 'Remalt Chat', model: 'remic', agentType: 'speaking');
    _nodes['writing_agent'] = _NodeData(type: 'agent', title: 'Writing Coach', color: const Color(0xFF059669), headerLabel: 'Remalt Chat', model: 'remic', agentType: 'writing');

    // Larger node sizes (remalt-style: prompt nodes are 360x270+)
    for (final id in ['input', 'theory', 'examples', 'exercises', 'vocabulary', 'practice']) {
      _nodeSizes[id] = const Size(360, 200);
    }
    for (final id in ['reading_agent', 'speaking_agent', 'writing_agent']) {
      _nodeSizes[id] = const Size(360, 220);
    }
  }

  // ---- Edges: sources → input, input → outputs, outputs → agents ----
  List<_Edge> get _edges {
    final e = <_Edge>[];
    for (var i = 0; i < _sources.length; i++) {
      e.add(_Edge(from: 'source_$i', to: 'input', faded: true));
    }
    for (var i = 0; i < _textNotes.length; i++) {
      e.add(_Edge(from: 'note_$i', to: 'input', faded: true));
    }
    for (var i = 0; i < _images.length; i++) {
      e.add(_Edge(from: 'image_$i', to: 'input', faded: true));
    }
    final outputs = ['theory', 'examples', 'exercises', 'vocabulary', 'practice'];
    for (final o in outputs) {
      e.add(_Edge(from: 'input', to: o));
    }
    final agents = ['reading_agent', 'speaking_agent', 'writing_agent'];
    for (final a in agents) {
      for (final o in outputs) {
        e.add(_Edge(from: o, to: a, faded: true));
      }
    }
    return e;
  }

  // ---- Source / note / image node creation ----

  void _addSourceNode() {
    final id = 'source_$_sourceCounter';
    _sourceCounter++;
    final y = 220.0 + (_sources.length * 150);
    _nodePositions[id] = Offset(-400, y);
    final source = _SourceData(type: 'url');
    _sources.add(source);
    _nodes[id] = _NodeData(type: 'source', title: 'Source ${_sources.length}', color: const Color(0xFF6B8E7F), headerLabel: 'URL');
    _nodeSizes[id] = const Size(280, 120);
    setState(() => _selectedNode = id);
  }

  void _addTextNoteNode() {
    final id = 'note_$_textNoteCounter';
    _textNoteCounter++;
    _nodePositions[id] = Offset(200 + (_textNoteCounter * 30), 1200);
    _textNotes[id] = '';
    _nodes[id] = _NodeData(type: 'note', title: 'Sticky Note', color: const Color(0xFFFBBF24), headerLabel: 'Note');
    _nodeSizes[id] = const Size(240, 160);
    setState(() => _selectedNode = id);
  }

  void _addImageNode() {
    final id = 'image_$_imageCounter';
    _imageCounter++;
    _nodePositions[id] = Offset(200 + (_imageCounter * 30), 1400);
    _images[id] = _ImageData();
    _nodes[id] = _NodeData(type: 'image', title: 'Image', color: const Color(0xFFA66BD6), headerLabel: 'gpt-image-1', model: 'gpt-image-1');
    _nodeSizes[id] = const Size(320, 360);
    setState(() => _selectedNode = id);
  }

  void _addStickyLabel(String label) {
    final id = 'note_${DateTime.now().microsecondsSinceEpoch}';
    _textNoteCounter++;
    _nodePositions[id] = Offset(40 + (_textNoteCounter * 20), 1380);
    _textNotes[id] = label;
    _nodes[id] = _NodeData(type: 'note', title: label, color: const Color(0xFFFBBF24), headerLabel: 'Sticky');
    _nodeSizes[id] = const Size(220, 80);
    setState(() => _selectedNode = id);
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

    // Gather linked upstream nodes (edge-aware pipeline, Tier 1)
    final linkedNodes = <Map<String, dynamic>>[];
    for (final e in _edges) {
      if (e.to == nodeId) {
        final upstream = _nodes[e.from];
        if (upstream != null && upstream.content != null) {
          linkedNodes.add({
            'nodeId': e.from,
            'type': upstream.type,
            'title': upstream.title,
            'content': upstream.content,
          });
        }
      }
    }

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
        linkedNodes: linkedNodes,
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

  // ---- Canvas transform helpers ----

  Offset _canvasToScreen(Offset p) => (p * _zoom) + _pan;
  Offset _screenToCanvas(Offset p) => (p - _pan) / _zoom;

  void _fitToScreen() {
    if (_nodePositions.isEmpty) return;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final entry in _nodePositions.entries) {
      final size = _nodeSizes[entry.key] ?? const Size(360, 200);
      final pos = entry.value;
      minX = math.min(minX, pos.dx);
      minY = math.min(minY, pos.dy);
      maxX = math.max(maxX, pos.dx + size.width);
      maxY = math.max(maxY, pos.dy + size.height);
    }
    final contentWidth = maxX - minX;
    final contentHeight = maxY - minY;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height - 120;
    if (contentWidth <= 0 || contentHeight <= 0) return;
    final zoomX = (screenW - 80) / contentWidth;
    final zoomY = (screenH - 80) / contentHeight;
    _zoom = math.min(zoomX, zoomY).clamp(0.2, 2.0);
    _pan = Offset(
      (screenW - contentWidth * _zoom) / 2 - minX * _zoom,
      (screenH - contentHeight * _zoom) / 2 - minY * _zoom + 20,
    );
    setState(() {});
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return _buildMobileReadOnlyView();
    }
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            // Material library sidebar (Tier 1)
            if (_libraryOpen) _buildMaterialLibrary(),
            // Canvas area (shifted right if library is open)
            GestureDetector(
              onTap: () => setState(() {
                _selectedNode = null;
                _selectedNodes.clear();
                _selectionRect = null;
              }),
            onPanStart: (d) {
              if (_draggingNode == null && _resizingNode == null) {
                _dragStart = d.globalPosition;
                setState(() {
                  _selectionStart = _screenToCanvas(d.globalPosition);
                  _selectionRect = null;
                });
              }
            },
            onPanUpdate: (d) {
              if (_draggingNode != null) {
                setState(() {
                  final canvasPos = _screenToCanvas(d.globalPosition);
                  if (_selectedNodes.contains(_draggingNode) && _selectedNodes.length > 1) {
                    final delta = canvasPos - (_nodePositions[_draggingNode!] ?? canvasPos);
                    for (final id in _selectedNodes) {
                      _nodePositions[id] = (_nodePositions[id] ?? canvasPos) + delta;
                    }
                  } else {
                    _nodePositions[_draggingNode!] = canvasPos;
                  }
                  _isDraggingNode = true;
                });
              } else if (_resizingNode != null) {
                setState(() {
                  final canvasPos = _screenToCanvas(d.globalPosition);
                  final nodePos = _nodePositions[_resizingNode!]!;
                  _nodeSizes[_resizingNode!] = Size(
                    (canvasPos.dx - nodePos.dx).clamp(160, 800),
                    (canvasPos.dy - nodePos.dy).clamp(80, 600),
                  );
                });
              } else if (_selectionStart != null) {
                setState(() {
                  final current = _screenToCanvas(d.globalPosition);
                  _selectionRect = Rect.fromPoints(_selectionStart!, current);
                  _selectedNodes.clear();
                  for (final entry in _nodePositions.entries) {
                    final size = _nodeSizes[entry.key] ?? const Size(360, 200);
                    final nodeRect = Rect.fromLTWH(entry.value.dx, entry.value.dy, size.width, size.height);
                    if (_selectionRect!.overlaps(nodeRect)) {
                      _selectedNodes.add(entry.key);
                    }
                  }
                });
              } else if (_dragStart != null) {
                setState(() {
                  _pan = _pan + d.delta;
                });
              }
            },
            onPanEnd: (_) {
              _dragStart = null;
              _draggingNode = null;
              _resizingNode = null;
              _selectionStart = null;
              _selectionRect = null;
              setState(() => _isDraggingNode = false);
            },
            child: Stack(
              children: [
                _GridBackground(pan: _pan, zoom: _zoom),
                if (_selectionRect != null)
                  Positioned(
                    left: _canvasToScreen(_selectionRect!.topLeft).dx,
                    top: _canvasToScreen(_selectionRect!.topLeft).dy,
                    width: _selectionRect!.width * _zoom,
                    height: _selectionRect!.height * _zoom,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937).withOpacity(0.06),
                        border: Border.all(color: const Color(0xFF1F2937).withOpacity(0.3), width: 1),
                      ),
                    ),
                  ),
                ..._buildEdges(),
                ..._nodes.entries.map((e) => _buildNode(e.key, e.value)),
                ..._selectedNodes.map((id) {
                  final pos = _nodePositions[id];
                  final size = _nodeSizes[id] ?? const Size(360, 200);
                  if (pos == null) return const SizedBox.shrink();
                  final screenPos = _canvasToScreen(pos);
                  return Positioned(
                    left: screenPos.dx - 4,
                    top: screenPos.dy - 4,
                    width: size.width * _zoom + 8,
                    height: size.height * _zoom + 8,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF1F2937), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          _buildFloatingToolbar(),
          if (_selectedNode != null) _buildSidePanel(),
          _buildBottomLeftControls(),
          _buildZoomControls(),
          _buildMiniMap(),
          // File drop overlay (Tier 1)
          if (_isDraggingFile) _buildFileDropOverlay(),
          // Onboarding overlay (Tier 4)
          if (_showOnboarding) _buildOnboardingOverlay(),
          // Library toggle button (when closed)
          if (!_libraryOpen) _buildLibraryToggle(),
        ],
      ),
      ),
    );
  }

  // ============================================================
  // KEYBOARD SHORTCUTS (Tier 3)
  // ============================================================

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    // Ctrl+Z = undo
    if (isCtrl && key == LogicalKeyboardKey.keyZ && !isShift) {
      _undo();
      return KeyEventResult.handled;
    }
    // Ctrl+Shift+Z or Ctrl+Y = redo
    if ((isCtrl && key == LogicalKeyboardKey.keyZ && isShift) || (isCtrl && key == LogicalKeyboardKey.keyY)) {
      _redo();
      return KeyEventResult.handled;
    }
    // Ctrl+S = save (prevent browser default)
    if (isCtrl && key == LogicalKeyboardKey.keyS) {
      _explicitSave(label: 'keyboard save');
      return KeyEventResult.handled;
    }
    // Ctrl+D = duplicate
    if (isCtrl && key == LogicalKeyboardKey.keyD) {
      _duplicateSelected();
      return KeyEventResult.handled;
    }
    // Delete/Backspace = delete selected
    if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      if (_selectedNode != null) {
        _deleteNode(_selectedNode!);
        return KeyEventResult.handled;
      }
    }
    // F = fit to screen
    if (key == LogicalKeyboardKey.keyF && !isCtrl) {
      _fitToScreen();
      return KeyEventResult.handled;
    }
    // Escape = deselect
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        _selectedNode = null;
        _selectedNodes.clear();
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _duplicateSelected() {
    if (_selectedNode == null) return;
    final id = _selectedNode!;
    final node = _nodes[id];
    final pos = _nodePositions[id];
    if (node == null || pos == null) return;
    final newId = '${node.type}_dup_${DateTime.now().microsecondsSinceEpoch}';
    _pushUndoSnapshot();
    _nodePositions[newId] = pos + const Offset(40, 40);
    _nodeSizes[newId] = _nodeSizes[id] ?? const Size(360, 200);
    _nodes[newId] = _NodeData(
      type: node.type,
      title: node.title,
      color: node.color,
      headerLabel: node.headerLabel,
      model: node.model,
      agentType: node.agentType,
      content: node.content != null ? Map<String, dynamic>.from(node.content!) : null,
    );
    setState(() => _selectedNode = newId);
    _markDirty();
  }

  void _deleteNode(String id) {
    _pushUndoSnapshot();
    setState(() {
      _nodes.remove(id);
      _nodePositions.remove(id);
      _nodeSizes.remove(id);
      _textNotes.remove(id);
      _images.remove(id);
      _selectedNode = null;
      _selectedNodes.remove(id);
    });
    _markDirty();
  }

  // ============================================================
  // APP BAR — remalt-style: breadcrumb + status + actions
  // ============================================================

  PreferredSizeWidget _buildAppBar() {
    final saveBadgeColor = _saveStatus.startsWith('SAVED')
        ? const Color(0xFF059669)
        : _saveStatus == 'SAVING...'
            ? const Color(0xFFF59E0B)
            : _saveStatus == 'ERROR'
                ? const Color(0xFFEF4444)
                : const Color(0xFF9CA3AF);
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
        onPressed: () => context.go('/teacher/syllabi/${widget.syllabusId}'),
      ),
      title: Row(
        children: [
          Text('OSEE', style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF072c1f))),
          Container(margin: const EdgeInsets.symmetric(horizontal: 12), width: 1, height: 20, color: const Color(0xFFE5E7EB)),
          const Text('Brainboard', style: TextStyle(fontFamily: 'Helvetica', fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(_boardTitle.isEmpty ? 'Untitled lesson' : _boardTitle, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 13, color: Color(0xFF1F2937), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: saveBadgeColor, borderRadius: BorderRadius.circular(3)),
            child: Text(_saveStatus, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white)),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.dashboard_outlined, size: 16, color: Color(0xFF1F2937)), tooltip: 'Templates', onPressed: _showTemplatesDialog),
        IconButton(icon: const Icon(Icons.history, size: 16, color: Color(0xFF1F2937)), tooltip: 'Version History', onPressed: _showVersionHistory),
        IconButton(icon: const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF1F2937)), tooltip: 'AI Critic — Review Lesson', onPressed: _runCriticReview),
        IconButton(icon: const Icon(Icons.share_outlined, size: 16, color: Color(0xFF1F2937)), tooltip: 'Share', onPressed: _showShareDialog),
        IconButton(icon: const Icon(Icons.download_outlined, size: 16, color: Color(0xFF1F2937)), tooltip: 'Export', onPressed: _showExportDialog),
        IconButton(icon: const Icon(Icons.keyboard_outlined, size: 16, color: Color(0xFF1F2937)), tooltip: 'Shortcuts', onPressed: _showShortcutsDialog),
        TextButton(
          onPressed: _showBrainDumpDialog,
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF1F2937)),
            SizedBox(width: 6),
            Text('Brain Dump', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
          ]),
        ),
        const SizedBox(width: 4),
        FilledButton.icon(
          onPressed: _isSaving ? null : () => _explicitSave(label: 'manual save'),
          icon: _isSaving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
              : const Icon(Icons.save, size: 14, color: Colors.white),
          label: Text(_isSaving ? 'SAVING…' : 'Save', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF072c1f),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ============================================================
  // EDGES — teal/green bezier curves like remalt
  // ============================================================

  List<Widget> _buildEdges() {
    return _edges.map((e) {
      final from = _nodePositions[e.from];
      final to = _nodePositions[e.to];
      if (from == null || to == null) return const SizedBox.shrink();
      final fromSize = _nodeSizes[e.from] ?? const Size(360, 200);
      final toSize = _nodeSizes[e.to] ?? const Size(360, 200);
      final fromScreen = _canvasToScreen(from + Offset(fromSize.width, 30));
      final toScreen = _canvasToScreen(to + const Offset(0, 30));
      return CustomPaint(
        size: Size.infinite,
        painter: _EdgePainter(
          from: fromScreen,
          to: toScreen,
          color: e.faded ? const Color(0x1A1F2937) : const Color(0xFF10B981),
        ),
      );
    }).toList();
  }

  // ============================================================
  // NODES — remalt-style cards with colored headers
  // ============================================================

  Widget _buildNode(String id, _NodeData node) {
    final pos = _nodePositions[id];
    if (pos == null) return const SizedBox.shrink();
    final screenPos = _canvasToScreen(pos);
    final isSelected = _selectedNode == id;
    final hasContent = node.content != null;
    final size = _nodeSizes[id] ?? const Size(360, 200);
    final isDragging = _isDraggingNode && _draggingNode == id;
    final isMultiSelected = _selectedNodes.contains(id);

    return Positioned(
      left: screenPos.dx,
      top: screenPos.dy,
      child: Transform.scale(
        scale: _zoom,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onPanStart: (_) => setState(() => _draggingNode = id),
                onTap: () => setState(() => _selectedNode = isSelected ? null : id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: isDragging ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? node.color
                          : isMultiSelected
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFE5E7EB),
                      width: isSelected || isMultiSelected ? 2 : 1,
                    ),
                    boxShadow: isDragging
                        ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, spreadRadius: 2, offset: const Offset(0, 8))]
                        : isSelected
                            ? [BoxShadow(color: node.color.withOpacity(0.2), blurRadius: 12, spreadRadius: 1)]
                            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildNodeHeader(id, node, hasContent),
                      Expanded(child: _buildNodeBody(id, node)),
                    ],
                  ),
                ),
              ),
              // Resize handle
              Positioned(
                right: -2,
                bottom: -2,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _resizingNode = id),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeDownRight,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.only(bottomRight: Radius.circular(6)),
                      ),
                      child: const Icon(Icons.open_in_full, size: 10, color: Color(0xFF6B7280)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Remalt-style node header: colored bar with model name + title
  Widget _buildNodeHeader(String id, _NodeData node, bool hasContent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: node.color,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(7), topRight: Radius.circular(7)),
      ),
      child: Row(
        children: [
          Icon(_nodeIcon(id), size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (node.headerLabel != null)
                  Text(
                    node.headerLabel!,
                    style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Colors.white70),
                  ),
                Text(
                  node.title,
                  style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (node.isGenerating)
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
          else if (node.chatHistory.isNotEmpty || hasContent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              child: Text(
                hasContent ? '✓ ${(node.content!['title'] as String? ?? 'done').substring(0, math.min(15, (node.content!['title'] as String? ?? 'done').length))}' : '${node.chatHistory.length}',
                style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  IconData _nodeIcon(String id) {
    switch (id) {
      case 'input': return Icons.input;
      case 'theory': return Icons.menu_book;
      case 'examples': return Icons.lightbulb_outline;
      case 'exercises': return Icons.quiz_outlined;
      case 'vocabulary': return Icons.translate;
      case 'practice': return Icons.fitness_center;
      case 'reading_agent': return Icons.menu_book_outlined;
      case 'speaking_agent': return Icons.mic;
      case 'writing_agent': return Icons.edit;
      default:
        if (id.startsWith('source_')) return Icons.link;
        if (id.startsWith('note_')) return Icons.sticky_note_2_outlined;
        if (id.startsWith('image_')) return Icons.image_outlined;
        return Icons.circle;
    }
  }

  Widget _buildNodeBody(String id, _NodeData node) {
    if (id == 'input') {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            TextField(
              controller: _topicCtl,
              decoration: const InputDecoration(
                hintText: 'Lesson topic…',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
              onChanged: (_) => setState(() {}),
            ),
            Container(height: 1, color: const Color(0xFFE5E7EB)),
            const SizedBox(height: 4),
            TextField(
              controller: _notesCtl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Your notes, goals, student struggles…',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF6B7280), height: 1.4),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _miniDropdown('Exam', _exam, {'GENERAL': 'Gen', 'TOEFL_IBT': 'iBT', 'IELTS': 'IELTS', 'TOEIC': 'TOEIC'}, (v) => setState(() => _exam = v)),
                const SizedBox(width: 4),
                _miniDropdown('Level', _level, const {'A2': 'A2', 'B1': 'B1', 'B2': 'B2', 'C1': 'C1'}, (v) => setState(() => _level = v)),
              ],
            ),
          ],
        ),
      );
    }
    if (node.type == 'source') {
      final idx = int.tryParse(id.replaceAll('source_', '')) ?? 0;
      final source = idx < _sources.length ? _sources[idx] : null;
      if (source == null) return const SizedBox.shrink();
      if (source.isIngesting) {
        return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF6B8E7F))));
      }
      if (source.text != null) {
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(source.title ?? 'Source', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Expanded(child: Text(source.text!, style: const TextStyle(fontFamily: 'Georgia', fontSize: 10, color: Color(0xFF6B7280), height: 1.3), maxLines: 6, overflow: TextOverflow.ellipsis)),
            ],
          ),
        );
      }
      return Center(child: Text('Tap to add ${source.type}', style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: Color(0xFF9B9B9B))));
    }
    if (node.type == 'note') {
      final idx = int.tryParse(id.replaceAll('note_', '')) ?? 0;
      final ctl = TextEditingController(text: _textNotes[id] ?? '');
      return Padding(
        padding: const EdgeInsets.all(10),
        child: TextField(
          controller: ctl,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: 'Sticky note…',
            hintStyle: TextStyle(color: Color(0xFFB45309), fontFamily: 'Georgia', fontStyle: FontStyle.italic),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: Color(0xFF78350F), height: 1.4),
          onChanged: (v) => _textNotes[id] = v,
        ),
      );
    }
    if (node.type == 'image') {
      final idx = int.tryParse(id.replaceAll('image_', '')) ?? 0;
      final img = idx < _images.length ? _images[idx] : null;
      if (img == null) return const SizedBox.shrink();
      if (img.isGenerating) {
        return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA66BD6))),
          SizedBox(height: 8),
          Text('Generating image…', style: TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF6B7280))),
        ]));
      }
      if (img.url != null) {
        return Padding(
          padding: const EdgeInsets.all(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              _decodeImage(img.url!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFF3F4F6),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, color: Color(0xFF9CA3AF), size: 32),
              ),
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (v) { if (img != null) img.prompt = v; },
              decoration: const InputDecoration(
                hintText: 'Describe the image…',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF1F2937), height: 1.3),
              maxLines: 4,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniDropdown('Type', img.imageType, const {'illustration': 'Illustration', 'cover': 'Cover', 'infographic': 'Infographic', 'vocabulary': 'Vocab', 'icon': 'Icon', 'scene': 'Scene'}, (v) => setState(() => img.imageType = v)),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _generateImage(id),
                  icon: const Icon(Icons.auto_awesome, size: 12),
                  label: const Text('Generate', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFA66BD6).withOpacity(0.15),
                    foregroundColor: const Color(0xFFA66BD6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 28),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (node.type == 'agent') {
      return _buildAgentPanel(id, node);
    }
    // Output node — has GENERATE button + content preview
    return _buildOutputPanel(id, node);
  }

  Widget _buildOutputPanel(String id, _NodeData node) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: node.isGenerating ? null : () => _generateNode(id),
                icon: node.isGenerating
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF1E40AF)))
                    : Icon(node.content == null ? Icons.auto_awesome : Icons.refresh, size: 12),
                label: Text(
                  node.isGenerating ? 'GENERATING…' : (node.content == null ? 'GENERATE' : 'REGENERATE'),
                  style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E40AF).withOpacity(0.1),
                  foregroundColor: const Color(0xFF1E40AF),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 26),
                ),
              ),
              if (node.content != null) ...[
                const SizedBox(width: 8),
                Text(
                  _nodeSummary(id, node.content!),
                  style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: Color(0xFF6B7280)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: node.content != null
                ? _buildNodeContentPreview(id, node.content!)
                : node.error != null
                    ? Text(node.error!, style: const TextStyle(color: Color(0xFFE63946), fontFamily: 'Georgia', fontSize: 11))
                    : const Text('Tap GENERATE to create content with AI.', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: Color(0xFF9B9B9B))),
          ),
        ],
      ),
    );
  }

  String _nodeSummary(String id, Map<String, dynamic> content) {
    switch (id) {
      case 'theory': return '${(content['theory'] as String? ?? '').length} chars';
      case 'examples': return '${(content['examples'] as List? ?? []).length} examples';
      case 'exercises': return '${(content['exercises'] as List? ?? []).length} questions';
      case 'vocabulary': return '${(content['vocabulary'] as List? ?? []).length} words';
      case 'practice': return (content['practice_prompt'] as String? ?? '').isNotEmpty ? '1 prompt' : '';
      default: return '';
    }
  }

  Widget _buildNodeContentPreview(String id, Map<String, dynamic> content) {
    switch (id) {
      case 'theory':
        return Text((content['theory'] as String? ?? '').replaceAll('\\n', '\n'),
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF1F2937), height: 1.4),
            maxLines: 8, overflow: TextOverflow.ellipsis);
      case 'examples':
        final examples = (content['examples'] as List? ?? []) as List;
        return ListView.builder(
          itemCount: examples.length,
          itemBuilder: (_, i) {
            final e = examples[i] as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 10, color: Color(0xFF1F2937), height: 1.3),
                  children: [
                    TextSpan(text: '${e['input']}\n', style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF6B7280))),
                    TextSpan(text: '→ ${e['output']}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                  ],
                ),
              ),
            );
          },
        );
      case 'exercises':
        final ex = (content['exercises'] as List? ?? []) as List;
        return ListView.builder(
          itemCount: ex.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text('${i + 1}. ${(ex[i] as Map<String, dynamic>)['question'] as String? ?? ''}',
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 10, color: Color(0xFF1F2937)), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        );
      case 'vocabulary':
        final v = (content['vocabulary'] as List? ?? []) as List;
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: v.take(8).map((w) {
            final word = (w as Map<String, dynamic>)['word'] as String? ?? '';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFFBBF24).withOpacity(0.15), borderRadius: BorderRadius.circular(2)),
              child: Text(word, style: const TextStyle(fontFamily: 'Georgia', fontSize: 10, color: Color(0xFF78350F))),
            );
          }).toList(),
        );
      case 'practice':
        return Text(content['practice_prompt'] as String? ?? '',
            style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: Color(0xFF1F2937), height: 1.4));
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildAgentPanel(String id, _NodeData node) {
    final msgCtl = TextEditingController();
    return StatefulBuilder(
      builder: (ctx, setLocal) => Column(
        children: [
          Expanded(
            child: node.chatHistory.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Type a message to chat with the agent.', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: Color(0xFF9CA3AF), height: 1.4), textAlign: TextAlign.center),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: node.chatHistory.length,
                    itemBuilder: (_, i) {
                      final msg = node.chatHistory[i];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(msg['content'] ?? '',
                              style: TextStyle(fontFamily: 'Georgia', fontSize: 11, color: const Color(0xFF1F2937), height: 1.4)),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: msgCtl,
                    decoration: InputDecoration(
                      hintText: 'Ask the agent to refine…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF1F2937)),
                    onSubmitted: (_) => _sendAndClear(msgCtl, node, setLocal),
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: node.isGenerating ? null : () => _sendAndClear(msgCtl, node, setLocal),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: node.isGenerating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                      : const Icon(Icons.send, size: 14, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendAndClear(TextEditingController ctl, _NodeData node, StateSetter setLocal) {
    final text = ctl.text.trim();
    if (text.isEmpty) return;
    ctl.clear();
    _sendAgentMessage(_selectedNode!, text);
    setLocal(() {});
  }

  Widget _miniDropdown(String label, String value, Map<String, String> items, void Function(String) onChanged) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(2)),
        child: DropdownButton<String>(
          value: value,
          underline: const SizedBox(),
          isExpanded: true,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, size: 12, color: Color(0xFF6B7280)),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text('${e.value}', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: Color(0xFF1F2937)))))
              .toList(),
          onChanged: (v) => onChanged(v ?? value),
        ),
      ),
    );
  }

  // ============================================================
  // FLOATING TOOLBAR (bottom-center) — remalt-style node-type buttons
  // ============================================================

  Widget _buildFloatingToolbar() {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(icon: Icons.sticky_note_2_outlined, label: 'Note', color: const Color(0xFFFBBF24), onTap: _addTextNoteNode),
              _ToolbarButton(icon: Icons.add_link, label: 'Source', color: const Color(0xFF6B8E7F), onTap: _addSourceNode),
              _ToolbarButton(icon: Icons.image_outlined, label: 'Image', color: const Color(0xFFA66BD6), onTap: _addImageNode),
              Container(width: 1, height: 24, color: const Color(0xFFE5E7EB)),
              _ToolbarButton(icon: Icons.menu_book, label: 'Theory', color: const Color(0xFF1E40AF), onTap: () => _addOutputNode('theory', 'Theory', const Color(0xFF1E40AF))),
              _ToolbarButton(icon: Icons.lightbulb_outline, label: 'Examples', color: const Color(0xFF1E40AF), onTap: () => _addOutputNode('examples', 'Examples', const Color(0xFF1E40AF))),
              _ToolbarButton(icon: Icons.quiz_outlined, label: 'Exercises', color: const Color(0xFF1E40AF), onTap: () => _addOutputNode('exercises', 'Exercises', const Color(0xFF1E40AF))),
              _ToolbarButton(icon: Icons.translate, label: 'Vocab', color: const Color(0xFF1E40AF), onTap: () => _addOutputNode('vocabulary', 'Vocabulary', const Color(0xFF1E40AF))),
              _ToolbarButton(icon: Icons.fitness_center, label: 'Practice', color: const Color(0xFF1E40AF), onTap: () => _addOutputNode('practice', 'Practice', const Color(0xFF1E40AF))),
              Container(width: 1, height: 24, color: const Color(0xFFE5E7EB)),
              _ToolbarButton(icon: Icons.menu_book_outlined, label: 'Reading', color: const Color(0xFF059669), onTap: () => _addAgentNode('reading')),
              _ToolbarButton(icon: Icons.mic, label: 'Speaking', color: const Color(0xFF059669), onTap: () => _addAgentNode('speaking')),
              _ToolbarButton(icon: Icons.edit, label: 'Writing', color: const Color(0xFF059669), onTap: () => _addAgentNode('writing')),
            ],
          ),
        ),
      ),
    );
  }

  void _addOutputNode(String type, String title, Color color) {
    final id = '${type}_${DateTime.now().microsecondsSinceEpoch}';
    _nodePositions[id] = Offset(440 + (_nodes.length * 20 % 400), 60 + (_nodes.length * 50 % 800));
    _nodes[id] = _NodeData(type: type, title: title, color: color, headerLabel: 'Remalt AI Prompt', model: 'remic');
    _nodeSizes[id] = const Size(360, 200);
    setState(() => _selectedNode = id);
  }

  void _addAgentNode(String agentType) {
    final id = '${agentType}_agent_${DateTime.now().microsecondsSinceEpoch}';
    _nodePositions[id] = Offset(880, 140 + (_nodes.length * 30 % 600));
    final colorMap = {'reading': const Color(0xFF059669), 'speaking': const Color(0xFF059669), 'writing': const Color(0xFF059669)};
    _nodes[id] = _NodeData(
      type: 'agent',
      title: '${agentType[0].toUpperCase()}${agentType.substring(1)} Coach',
      color: colorMap[agentType] ?? const Color(0xFF059669),
      headerLabel: 'Remalt Chat',
      model: 'remic',
      agentType: agentType,
    );
    _nodeSizes[id] = const Size(360, 220);
    setState(() => _selectedNode = id);
  }

  // ============================================================
  // BOTTOM-LEFT CONTROLS — help text
  // ============================================================

  Widget _buildBottomLeftControls() {
    return Positioned(
      bottom: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(6)),
        child: const Text(
          'Drag nodes to move · Drag empty space to pan · Drag to select · Tap to open panel',
          style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: Color(0xFF9CA3AF), letterSpacing: 0.3),
        ),
      ),
    );
  }

  // ============================================================
  // ZOOM CONTROLS (bottom-right) — like remalt
  // ============================================================

  Widget _buildZoomControls() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 14, color: Color(0xFF1F2937)),
              onPressed: () => setState(() => _zoom = (_zoom - 0.1).clamp(0.2, 3.0)),
              iconSize: 14,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Zoom out',
            ),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('${(_zoom * 100).round()}%', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: Color(0xFF1F2937)))),
            IconButton(
              icon: const Icon(Icons.add, size: 14, color: Color(0xFF1F2937)),
              onPressed: () => setState(() => _zoom = (_zoom + 0.1).clamp(0.2, 3.0)),
              iconSize: 14,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Zoom in',
            ),
            Container(width: 1, height: 20, color: const Color(0xFFE5E7EB)),
            IconButton(
              icon: const Icon(Icons.fit_screen, size: 14, color: Color(0xFF1F2937)),
              onPressed: _fitToScreen,
              iconSize: 14,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Fit to screen',
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SIDE PANEL (when source or note node selected) — for source/URL input
  // ============================================================

  Widget _buildSidePanel() {
    final node = _nodes[_selectedNode!]!;
    if (node.type == 'source') {
      return _buildSourcePanel(_selectedNode!, node);
    }
    // For other nodes, the panel is rendered inside the node body
    return const SizedBox.shrink();
  }

  Widget _buildSourcePanel(String id, _NodeData node) {
    final sourceIndex = int.tryParse(id.replaceAll('source_', '')) ?? 0;
    final source = sourceIndex < _sources.length ? _sources[sourceIndex] : _SourceData(type: 'url');
    final urlCtl = TextEditingController(text: source.urlOrQuery);

    return StatefulBuilder(
      builder: (ctx, setLocal) => Align(
        alignment: Alignment.bottomRight,
        child: Container(
          margin: const EdgeInsets.only(right: 80, bottom: 64),
          width: 360,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('SOURCE', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: Color(0xFF6B7280))),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, size: 14, color: Color(0xFF6B7280)), onPressed: () => setState(() => _selectedNode = null), iconSize: 14, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 24, minHeight: 24)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _miniDropdown('Type', source.type, const {'youtube': 'YouTube', 'url': 'URL', 'text': 'Text'}, (v) => setLocal(() => source.type = v)),
                ],
              ),
              const SizedBox(height: 8),
              if (source.type == 'text')
                TextField(
                  controller: urlCtl,
                  maxLines: 5,
                  decoration: const InputDecoration(hintText: 'Paste any text…', border: OutlineInputBorder(), isDense: true),
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Color(0xFF1F2937)),
                  onChanged: (v) => source.urlOrQuery = v,
                )
              else
                TextField(
                  controller: urlCtl,
                  decoration: InputDecoration(
                    hintText: source.type == 'youtube' ? 'https://youtube.com/watch?v=…' : 'https://example.com/article',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Color(0xFF1F2937)),
                  onChanged: (v) => source.urlOrQuery = v,
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: source.isIngesting ? null : () => _ingestSource(id, source),
                  icon: source.isIngesting
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                      : const Icon(Icons.download, size: 12),
                  label: Text(source.isIngesting ? 'FETCHING…' : 'FETCH', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6B8E7F), padding: const EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
              if (source.text != null) ...[
                const SizedBox(height: 8),
                Text('${source.text!.length} chars extracted', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: Color(0xFF059669))),
              ],
            ],
          ),
        ),
      ),
    );
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

  // ============================================================
  // MATERIAL LIBRARY SIDEBAR (Tier 1)
  // ============================================================

  Widget _buildMaterialLibrary() {
    return Positioned(
      top: 0,
      left: 0,
      bottom: 0,
      width: 260,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB)))),
              child: Row(
                children: [
                  const Icon(Icons.folder_open, size: 14, color: Color(0xFF1F2937)),
                  const SizedBox(width: 6),
                  const Text('MY MATERIALS', style: TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Color(0xFF1F2937))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 16, color: Color(0xFF6B7280)),
                    onPressed: () => setState(() => _libraryOpen = false),
                    iconSize: 16,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            // Add button
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showAddMaterialDialog,
                      icon: const Icon(Icons.add, size: 12),
                      label: const Text('Add URL / Text', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1F2937),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.upload_file, size: 14, color: Color(0xFF6B7280)),
                    onPressed: _pickFile,
                    tooltip: 'Upload file',
                    iconSize: 14,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: _materialsLoading
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF6B7280))))
                  : _materials.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('No materials yet.\nDrag files here or add a URL.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Georgia', fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF9CA3AF), height: 1.5)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _materials.length,
                          itemBuilder: (_, i) {
                            final mat = _materials[i];
                            final typeIcon = _materialTypeIcon(mat['type'] as String? ?? 'url');
                            return Draggable<Map<String, dynamic>>(
                              data: mat,
                              feedback: Material(
                                color: Colors.transparent,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFF6B8E7F), borderRadius: BorderRadius.circular(4), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)]),
                                  child: Text(mat['name'] as String? ?? 'Material', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              childWhenDragging: Opacity(opacity: 0.4, child: _materialTile(mat, typeIcon)),
                              child: _materialTile(mat, typeIcon),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _materialTile(Map<String, dynamic> mat, IconData typeIcon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 44, decoration: const BoxDecoration(color: Color(0xFF6B8E7F), borderRadius: BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)))),
          const SizedBox(width: 8),
          Icon(typeIcon, size: 14, color: const Color(0xFF6B7280)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mat['name'] as String? ?? 'Untitled', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                Text(_materialSubtitle(mat), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 12, color: Color(0xFF6B7280)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rag', child: Text('Add to RAG', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11))),
              const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, color: Color(0xFFEF4444)))),
            ],
            onSelected: (v) {
              if (v == 'rag') _ingestMaterialToRag(mat['id'] as String);
              if (v == 'delete') _deleteMaterial(mat['id'] as String);
            },
          ),
        ],
      ),
    );
  }

  IconData _materialTypeIcon(String type) {
    switch (type) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'youtube': return Icons.play_circle_outline;
      case 'url': return Icons.link;
      case 'text': return Icons.text_snippet_outlined;
      case 'image': return Icons.image_outlined;
      case 'docx': return Icons.description_outlined;
      case 'slides': return Icons.slideshow;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  String _materialSubtitle(Map<String, dynamic> mat) {
    final type = mat['type'] as String? ?? 'url';
    final size = mat['size_bytes'] as int?;
    if (size == null) return type;
    final kb = size > 1024 ? '${size ~/ 1024}KB' : '${size}B';
    return '$type · $kb';
  }

  Widget _buildLibraryToggle() {
    return Positioned(
      top: 14,
      left: 14,
      child: IconButton(
        icon: const Icon(Icons.folder_open, size: 18, color: Color(0xFF1F2937)),
        onPressed: () => setState(() => _libraryOpen = true),
        tooltip: 'Open material library',
        style: IconButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: Color(0xFFE5E7EB))),
      ),
    );
  }

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
                _miniDropdown('Type', type, const {'url': 'URL', 'youtube': 'YouTube', 'text': 'Text'}, (v) => setLocal(() => type = v)),
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
    await _handleDroppedFiles(files);
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

  // ============================================================
  // FILE DROP OVERLAY (Tier 1)
  // ============================================================

  Widget _buildFileDropOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: const Color(0xFF10B981).withValues(alpha: 0.1),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981), width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.file_download, size: 40, color: Color(0xFF10B981)),
                  SizedBox(height: 12),
                  Text('DROP FILES TO ADD MATERIALS', style: TextStyle(fontFamily: 'Helvetica', fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2, color: Color(0xFF1F2937))),
                  SizedBox(height: 4),
                  Text('PDF, TXT, DOCX — auto-extracted & added to your library', style: TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF6B7280))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MINI-MAP (Tier 3)
  // ============================================================

  Widget _buildMiniMap() {
    if (_nodePositions.isEmpty) return const SizedBox.shrink();
    return Positioned(
      bottom: 56,
      right: 16,
      child: Container(
        width: 150,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: CustomPaint(
          size: const Size(150, 100),
          painter: _MiniMapPainter(
            positions: _nodePositions,
            sizes: _nodeSizes,
            pan: _pan,
            zoom: _zoom,
            viewportSize: MediaQuery.of(context).size,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ONBOARDING OVERLAY (Tier 4)
  // ============================================================

  Widget _buildOnboardingOverlay() {
    final steps = [
      ('Drag materials from the left', 'Your library is on the left. Drag PDFs, URLs, or text onto the canvas to use them as sources.', Icons.folder_open),
      ('Enter your topic and notes', 'Click the INPUT node to set your lesson topic, notes, exam, level, and difficulty.', Icons.edit),
      ('Generate AI content per node', 'Tap any Theory/Examples/Exercises node and hit Generate. Each node pulls context from its upstream nodes.', Icons.auto_awesome),
      ('Review with the AI critic', 'Click the shield icon in the app bar to run an AI review of your lesson.', Icons.shield_outlined),
    ];
    final step = steps[_onboardingStep];
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() {
          _onboardingStep++;
          if (_onboardingStep >= steps.length) _showOnboarding = false;
        }),
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(step.$3, size: 40, color: const Color(0xFF072c1f)),
                  const SizedBox(height: 16),
                  Text(step.$1, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
                  const SizedBox(height: 8),
                  Text(step.$2, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Color(0xFF6B7280), height: 1.5)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(onPressed: () => setState(() => _showOnboarding = false), child: const Text('Skip', style: TextStyle(color: Color(0xFF6B7280)))),
                      Text('${_onboardingStep + 1} / ${steps.length}'),
                      FilledButton(
                        onPressed: () => setState(() {
                          _onboardingStep++;
                          if (_onboardingStep >= steps.length) _showOnboarding = false;
                        }),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF072c1f)),
                        child: Text(_onboardingStep < steps.length - 1 ? 'Next' : 'Got it'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE READ-ONLY VIEW (Tier 4)
  // ============================================================

  Widget _buildMobileReadOnlyView() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Brainboard (read-only)', style: TextStyle(fontFamily: 'Helvetica', fontSize: 14, color: Color(0xFF1F2937))),
      ),
      body: Column(
        children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(12), color: const Color(0xFFFEF3C7), child: const Text('Open on desktop to edit this board.', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, color: Color(0xFF92400E)))),
          Expanded(
            child: ListView.builder(
              itemCount: _nodes.length,
              itemBuilder: (_, i) {
                final entry = _nodes.entries.elementAt(i);
                final node = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: Icon(_nodeIcon(entry.key), color: node.color, size: 20),
                    title: Text(node.title, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 12, fontWeight: FontWeight.w600)),
                    subtitle: node.content != null
                        ? Text((node.content!['summary'] ?? node.content!['title'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF6B7280)))
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
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
  // AI CRIC REVIEW (Tier 2)
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
              Row(children: [_miniDropdown('Permission', permission, const {'view': 'View only', 'edit': 'Can edit', 'admin': 'Admin'}, (v) => setLocal(() => permission = v))]),
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
          _ShortcutRow(keys: 'Ctrl+Z', desc: 'Undo'),
          _ShortcutRow(keys: 'Ctrl+Shift+Z', desc: 'Redo'),
          _ShortcutRow(keys: 'Ctrl+S', desc: 'Save (versioned)'),
          _ShortcutRow(keys: 'Ctrl+D', desc: 'Duplicate selected node'),
          _ShortcutRow(keys: 'Delete', desc: 'Delete selected node'),
          _ShortcutRow(keys: 'F', desc: 'Fit to screen'),
          _ShortcutRow(keys: 'Esc', desc: 'Deselect'),
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
                    final id = 'source_$_sourceCounter';
                    _sourceCounter++;
                    _nodePositions[id] = Offset(-400, 220.0 + (_sources.length * 150));
                    final source = _SourceData(type: src['type'] as String? ?? 'url');
                    source.title = src['title'] as String?;
                    source.text = src['text'] as String?;
                    _sources.add(source);
                    _nodes[id] = _NodeData(type: 'source', title: 'Source ${_sources.length}', color: const Color(0xFF6B8E7F), headerLabel: 'URL');
                    _nodeSizes[id] = const Size(280, 120);
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

class _Edge {
  final String from;
  final String to;
  final bool faded;
  const _Edge({required this.from, required this.to, this.faded = false});
}

// ============================================================
// EDGE PAINTER — teal/green smoothstep bezier
// ============================================================

class _EdgePainter extends CustomPainter {
  const _EdgePainter({required this.from, required this.to, required this.color});
  final Offset from;
  final Offset to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final midX = (from.dx + to.dx) / 2;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(midX, from.dy, midX, to.dy, to.dx, to.dy);
    canvas.drawPath(path, paint);
    canvas.drawCircle(to, 3, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => from != old.from || to != old.to || color != old.color;
}

// ============================================================
// GRID BACKGROUND — subtle dot grid on light background
// ============================================================

class _GridBackground extends StatelessWidget {
  const _GridBackground({required this.pan, required this.zoom});
  final Offset pan;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.infinite, painter: _GridPainter(pan: pan, zoom: zoom));
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.pan, required this.zoom});
  final Offset pan;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 40.0;
    final effectiveSpacing = spacing * zoom;
    final offsetX = pan.dx % effectiveSpacing;
    final offsetY = pan.dy % effectiveSpacing;
    final paint = Paint()..color = const Color(0x14000000).withValues(alpha: 0.06);
    for (var x = offsetX; x < size.width; x += effectiveSpacing) {
      for (var y = offsetY; y < size.height; y += effectiveSpacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => pan != old.pan || zoom != old.zoom;
}

// ============================================================
// TOOLBAR BUTTON
// ============================================================

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
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

// ============================================================
// MINI-MAP PAINTER — small overview of the canvas (Tier 3)
// ============================================================

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter({
    required this.positions,
    required this.sizes,
    required this.pan,
    required this.zoom,
    required this.viewportSize,
  });
  final Map<String, Offset> positions;
  final Map<String, Size> sizes;
  final Offset pan;
  final double zoom;
  final Size viewportSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.isEmpty) return;
    // Compute bounds
    var minX = double.infinity, minY = double.infinity, maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final entry in positions.entries) {
      final s = sizes[entry.key] ?? const Size(360, 200);
      minX = math.min(minX, entry.value.dx);
      minY = math.min(minY, entry.value.dy);
      maxX = math.max(maxX, entry.value.dx + s.width);
      maxY = math.max(maxY, entry.value.dy + s.height);
    }
    // Include viewport in bounds
    final vpCanvas = Offset(-pan.dx / zoom, -pan.dy / zoom);
    final vpSize = Size(viewportSize.width / zoom, viewportSize.height / zoom);
    minX = math.min(minX, vpCanvas.dx);
    minY = math.min(minY, vpCanvas.dy);
    maxX = math.max(maxX, vpCanvas.dx + vpSize.width);
    maxY = math.max(maxY, vpCanvas.dy + vpSize.height);
    final contentW = maxX - minX;
    final contentH = maxY - minY;
    if (contentW <= 0 || contentH <= 0) return;
    final scale = math.min(size.width / contentW, size.height / contentH);
    final offsetX = (size.width - contentW * scale) / 2 - minX * scale;
    final offsetY = (size.height - contentH * scale) / 2 - minY * scale;

    // Draw nodes
    final nodePaint = Paint()..color = const Color(0xFF6B7280)..style = PaintingStyle.fill;
    for (final entry in positions.entries) {
      final s = sizes[entry.key] ?? const Size(360, 200);
      final rect = Rect.fromLTWH(entry.value.dx * scale + offsetX, entry.value.dy * scale + offsetY, s.width * scale, s.height * scale);
      canvas.drawRect(rect, nodePaint);
    }
    // Draw viewport rectangle
    final vpRect = Rect.fromLTWH(vpCanvas.dx * scale + offsetX, vpCanvas.dy * scale + offsetY, vpSize.width * scale, vpSize.height * scale);
    final vpPaint = Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawRect(vpRect, vpPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter old) =>
      positions != old.positions || pan != old.pan || zoom != old.zoom;
}

// ============================================================
// SHORTCUT ROW — keyboard shortcut help entry (Tier 3)
// ============================================================

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.keys, required this.desc});
  final String keys;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFD1D5DB))),
            child: Text(keys, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
          ),
          const SizedBox(width: 12),
          Text(desc, style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}