import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/api_client.dart';

/// Remalt-style mind-map canvas — full clone.
///
/// Visual node canvas with:
///  - Input node (topic + notes) — the seed.
///  - 4 AI output nodes (Theory, Examples, Exercises, Vocabulary) — each
///    independently generates via POST /api/ai/mind-map-node.
///  - 3 Specialist agent chat nodes (Reading, Speaking, Writing) — refine
///    any output via POST /api/ai/agent-chat.
///  - Practice node — generates a practice task.
///
/// Interactions:
///  - Pan the canvas by dragging empty space.
///  - Drag nodes by their header.
///  - Tap a node to select + open its panel (edit input, generate, view
///    output, chat with agent).
///  - Edges drawn as bezier curves from input → outputs → agents.
///  - SAVE button assembles all node outputs into one syllabus item.
class MindMapRecipePage extends ConsumerStatefulWidget {
  const MindMapRecipePage({super.key, required this.syllabusId});
  final String syllabusId;

  @override
  ConsumerState<MindMapRecipePage> createState() => _MindMapRecipePageState();
}

class _MindMapRecipePageState extends ConsumerState<MindMapRecipePage>
    with SingleTickerProviderStateMixin {
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
  bool _isDraggingNode = false; // for visual feedback
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

  // Sources — ingested content (YouTube, URL, text) used as AI knowledge
  final List<_SourceData> _sources = [];
  int _sourceCounter = 0;

  // Text note nodes — free-form sticky notes on the canvas
  final Map<String, String> _textNotes = {};
  int _textNoteCounter = 0;

  @override
  void initState() {
    super.initState();
    _initNodes();
  }

  void _initNodes() {
    // Layout: input on left, outputs in a column to the right, agents further right
    _nodePositions['input'] = const Offset(40, 200);
    _nodePositions['theory'] = const Offset(440, 40);
    _nodePositions['examples'] = const Offset(440, 260);
    _nodePositions['exercises'] = const Offset(440, 480);
    _nodePositions['vocabulary'] = const Offset(440, 700);
    _nodePositions['practice'] = const Offset(440, 920);
    _nodePositions['reading_agent'] = const Offset(880, 120);
    _nodePositions['speaking_agent'] = const Offset(880, 380);
    _nodePositions['writing_agent'] = const Offset(880, 640);

    _nodes['input'] = _NodeData(type: 'input', title: 'INPUT', color: OseeTheme.ink);
    _nodes['theory'] = _NodeData(type: 'theory', title: 'THEORY', color: const Color(0xFF4F8DE0));
    _nodes['examples'] = _NodeData(type: 'examples', title: 'EXAMPLES', color: OseeTheme.sage);
    _nodes['exercises'] = _NodeData(type: 'exercises', title: 'EXERCISES', color: OseeTheme.accent);
    _nodes['vocabulary'] = _NodeData(type: 'vocabulary', title: 'VOCABULARY', color: OseeTheme.gold);
    _nodes['practice'] = _NodeData(type: 'practice', title: 'PRACTICE', color: const Color(0xFFA66BD6));
    _nodes['reading_agent'] = _NodeData(type: 'agent', title: 'READING AGENT', color: const Color(0xFF4F8DE0), agentType: 'reading');
    _nodes['speaking_agent'] = _NodeData(type: 'agent', title: 'SPEAKING AGENT', color: const Color(0xFFE5913D), agentType: 'speaking');
    _nodes['writing_agent'] = _NodeData(type: 'agent', title: 'WRITING AGENT', color: const Color(0xFF5BA674), agentType: 'writing');

    // Default node sizes
    for (final id in ['input', 'theory', 'examples', 'exercises', 'vocabulary', 'practice']) {
      _nodeSizes[id] = const Size(180, 100);
    }
    for (final id in ['reading_agent', 'speaking_agent', 'writing_agent']) {
      _nodeSizes[id] = const Size(180, 80);
    }
  }

  // Edges: sources → input, input → each output, each output → all agents
  List<_Edge> get _edges {
    final e = <_Edge>[];
    // Sources feed into input
    for (var i = 0; i < _sources.length; i++) {
      e.add(_Edge(from: 'source_$i', to: 'input', faded: true));
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

  // ---- Source ingestion ----

  void _addSourceNode() {
    final id = 'source_$_sourceCounter';
    _sourceCounter++;
    // Position source nodes to the left of the input, stacked
    final y = 200.0 + (_sources.length * 130);
    _nodePositions[id] = Offset(-380, y);

    final source = _SourceData(type: 'url');
    _sources.add(source);
    _nodes[id] = _NodeData(type: 'source', title: 'SOURCE ${_sources.length}', color: const Color(0xFF6B8E7F));
    _nodeSizes[id] = const Size(180, 90);
    setState(() {
      _selectedNode = id;
    });
  }

  void _addTextNoteNode() {
    final id = 'note_$_textNoteCounter';
    _textNoteCounter++;
    // Position near the center, offset by count
    _nodePositions[id] = Offset(200 + (_textNoteCounter * 30), 1050 + (_textNoteCounter * 20));
    _textNotes[id] = '';
    _nodes[id] = _NodeData(type: 'note', title: 'NOTE', color: const Color(0xFFE0B04F));
    _nodeSizes[id] = const Size(200, 120);
    setState(() {
      _selectedNode = id;
    });
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
    } catch (e) {
      setState(() {
        source.text = null;
        source.error = 'Failed to ingest: $e';
        source.isIngesting = false;
      });
    }
  }

  void _removeSource(String nodeId) {
    final index = _sources.isEmpty ? 0 : int.tryParse(nodeId.replaceAll('source_', '')) ?? 0;
    setState(() {
      if (index < _sources.length) _sources.removeAt(index);
      _nodes.remove(nodeId);
      _nodePositions.remove(nodeId);
      _selectedNode = null;
    });
  }

  // ---- Node generation ----

  /// Collect all ingested sources as JSON for the API.
  List<Map<String, String>> get _sourcesAsJson {
    return _sources.where((s) => s.text != null && s.text!.isNotEmpty).map((s) => {
      'type': s.type,
      'title': s.title ?? s.urlOrQuery,
      'text': s.text!,
    }).toList();
  }

  Future<void> _generateNode(String nodeId) async {
    if (_topicCtl.text.trim().isEmpty || _notesCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter topic and notes first')));
      return;
    }
    final node = _nodes[nodeId];
    if (node == null || node.type == 'input' || node.type == 'agent') return;

    setState(() {
      node.isGenerating = true;
      node.error = null;
    });

    // Pass theory as context to downstream nodes
    String? nodeContext;
    if (nodeId != 'theory' && _nodes['theory']?.content != null) {
      final t = _nodes['theory']!.content!;
      nodeContext = (t['theory'] as String?) ?? (t['title'] as String?);
    }

    try {
      final dio = ApiClient.create();
      final r = await dio.post('/ai/mind-map-node', data: {
        'type': nodeId,
        'topic': _topicCtl.text.trim(),
        'notes': _notesCtl.text.trim(),
        'exam': _exam,
        'level': _level,
        'item_type': _itemType,
        if (nodeContext != null) 'context': nodeContext,
        if (_sourcesAsJson.isNotEmpty) 'sources': _sourcesAsJson,
        'use_rag': true,
      });
      setState(() {
        node.content = r.data['content'] as Map<String, dynamic>?;
        node.isGenerating = false;
      });
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

    // Gather context from all output nodes
    final contextParts = <String>[];
    for (final entry in _nodes.entries) {
      if (entry.value.type != 'input' && entry.value.type != 'agent' && entry.value.content != null) {
        contextParts.add('${entry.key}: ${entry.value.content.toString()}');
      }
    }

    setState(() {
      node.chatHistory.add({'role': 'user', 'content': message});
      node.isGenerating = true;
    });

    try {
      final dio = ApiClient.create();
      final r = await dio.post('/ai/agent-chat', data: {
        'agent': node.agentType,
        'message': message,
        'context': contextParts.join('\n\n'),
        'topic': _topicCtl.text,
        'exam': _exam,
        'level': _level,
        'history': node.chatHistory.where((h) => h['role'] != 'user' || h['content'] != message).toList(),
        if (_sourcesAsJson.isNotEmpty) 'sources': _sourcesAsJson,
      });
      setState(() {
        node.chatHistory.add({'role': 'assistant', 'content': (r.data['reply'] as String?) ?? ''});
        node.isGenerating = false;
      });
    } catch (e) {
      setState(() {
        node.chatHistory.add({'role': 'assistant', 'content': 'Error: could not get a response.'});
        node.isGenerating = false;
      });
    }
  }

  // ---- Save ----

  Future<void> _saveToSyllabus() async {
    // Assemble all node content into one ai_generated_content payload
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

  // ---- Fit to screen ----

  void _fitToScreen() {
    if (_nodePositions.isEmpty) return;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final entry in _nodePositions.entries) {
      final size = _nodeSizes[entry.key] ?? const Size(180, 100);
      final pos = entry.value;
      minX = math.min(minX, pos.dx);
      minY = math.min(minY, pos.dy);
      maxX = math.max(maxX, pos.dx + size.width);
      maxY = math.max(maxY, pos.dy + size.height);
    }
    final contentWidth = maxX - minX;
    final contentHeight = maxY - minY;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height - 120; // minus app bar
    if (contentWidth <= 0 || contentHeight <= 0) return;
    final zoomX = (screenW - 80) / contentWidth;
    final zoomY = (screenH - 80) / contentHeight;
    _zoom = math.min(zoomX, zoomY).clamp(0.3, 2.0);
    _pan = Offset(
      (screenW - contentWidth * _zoom) / 2 - minX * _zoom,
      (screenH - contentHeight * _zoom) / 2 - minY * _zoom + 20,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F2E),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Grid background + canvas
          GestureDetector(
            onTap: () => setState(() {
              _selectedNode = null;
              _selectedNodes.clear();
              _selectionRect = null;
            }),
            onPanStart: (d) {
              if (_draggingNode == null && _resizingNode == null) {
                _dragStart = d.globalPosition;
                // Start selection box
                setState(() {
                  _selectionStart = _screenToCanvas(d.globalPosition);
                  _selectionRect = null;
                });
              }
            },
            onPanUpdate: (d) {
              if (_draggingNode != null) {
                // Move single node (or group if multi-selected)
                setState(() {
                  final canvasPos = _screenToCanvas(d.globalPosition);
                  if (_selectedNodes.contains(_draggingNode) && _selectedNodes.length > 1) {
                    // Move all selected nodes by delta
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
                // Resize node
                setState(() {
                  final canvasPos = _screenToCanvas(d.globalPosition);
                  final nodePos = _nodePositions[_resizingNode!]!;
                  final newSize = Size(
                    (canvasPos.dx - nodePos.dx).clamp(120, 600),
                    (canvasPos.dy - nodePos.dy).clamp(60, 500),
                  );
                  _nodeSizes[_resizingNode!] = newSize;
                });
              } else if (_selectionStart != null) {
                // Update selection box
                setState(() {
                  final current = _screenToCanvas(d.globalPosition);
                  _selectionRect = Rect.fromPoints(_selectionStart!, current);
                  // Select nodes inside the rect
                  _selectedNodes.clear();
                  for (final entry in _nodePositions.entries) {
                    final size = _nodeSizes[entry.key] ?? const Size(180, 100);
                    final nodeRect = Rect.fromLTWH(entry.value.dx, entry.value.dy, size.width, size.height);
                    if (_selectionRect!.overlaps(nodeRect)) {
                      _selectedNodes.add(entry.key);
                    }
                  }
                });
              } else if (_dragStart != null) {
                // Pan the canvas
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
                // Grid background
                _GridBackground(pan: _pan, zoom: _zoom),

                // Selection rectangle
                if (_selectionRect != null)
                  Positioned(
                    left: _canvasToScreen(_selectionRect!.topLeft).dx,
                    top: _canvasToScreen(_selectionRect!.topLeft).dy,
                    width: _selectionRect!.width * _zoom,
                    height: _selectionRect!.height * _zoom,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
                      ),
                    ),
                  ),

                // Edges
                ..._buildEdges(),

                // Nodes
                ..._nodes.entries.map((e) => _buildNode(e.key, e.value)),

                // Multi-select highlight
                ..._selectedNodes.map((id) {
                  final pos = _nodePositions[id];
                  final size = _nodeSizes[id] ?? const Size(180, 100);
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
                          border: Border.all(color: Colors.blue, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Floating toolbar (bottom-center) — add node types
          _buildFloatingToolbar(),

          // Side panel for selected node
          if (_selectedNode != null) _buildSidePanel(),

          // Controls overlay (bottom-left)
          _buildControls(),

          // Zoom controls (bottom-right)
          _buildZoomControls(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1F1F2E),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.go('/teacher/syllabi/${widget.syllabusId}'),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('MIND-MAP CANVAS', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 3, color: Colors.white54)),
          const SizedBox(height: 2),
          const Text('AI Material Builder', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
      actions: [
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _isSaving ? null : _saveToSyllabus,
          icon: _isSaving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
              : const Icon(Icons.save, size: 16),
          label: Text(_isSaving ? 'SAVING…' : 'SAVE', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
          style: FilledButton.styleFrom(backgroundColor: OseeTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ---- Edges ----

  List<Widget> _buildEdges() {
    return _edges.map((e) {
      final from = _nodePositions[e.from];
      final to = _nodePositions[e.to];
      if (from == null || to == null) return const SizedBox.shrink();

      final fromScreen = _canvasToScreen(from + const Offset(180, 30));
      final toScreen = _canvasToScreen(to + const Offset(0, 30));

      return CustomPaint(
        size: Size.infinite,
        painter: _EdgePainter(
          from: fromScreen,
          to: toScreen,
          color: e.faded ? Colors.white12 : Colors.white30,
        ),
      );
    }).toList();
  }

  // ---- Nodes ----

  Widget _buildNode(String id, _NodeData node) {
    final pos = _nodePositions[id];
    if (pos == null) return const SizedBox.shrink();
    final screenPos = _canvasToScreen(pos);
    final isSelected = _selectedNode == id;
    final hasContent = node.content != null;
    final size = _nodeSizes[id] ?? const Size(180, 100);
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
              // Main node card
              GestureDetector(
                onPanStart: (_) => setState(() => _draggingNode = id),
                onTap: () => setState(() => _selectedNode = isSelected ? null : id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  transform: isDragging ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E2E40),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? node.color
                          : isMultiSelected
                              ? Colors.blue
                              : (hasContent ? node.color.withOpacity(0.4) : Colors.white12),
                      width: isSelected || isMultiSelected ? 2 : 1,
                    ),
                    boxShadow: isDragging
                        ? [BoxShadow(color: node.color.withOpacity(0.5), blurRadius: 20, spreadRadius: 4, offset: const Offset(0, 8))]
                        : isSelected
                            ? [BoxShadow(color: node.color.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)]
                            : [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header (drag handle)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: node.color,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5)),
                        ),
                        child: Row(
                          children: [
                            Icon(_nodeIcon(id), size: 12, color: Colors.white),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                node.title,
                                style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white),
                              ),
                            ),
                            if (node.isGenerating)
                              const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white))
                            else if (hasContent)
                              const Icon(Icons.check_circle, size: 10, color: Colors.white70),
                          ],
                        ),
                      ),
                      // Body
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _buildNodeBody(id, node),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Resize handle (bottom-right corner)
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
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(6)),
                      ),
                      child: const Icon(Icons.open_in_full, size: 10, color: Colors.white54),
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

  IconData _nodeIcon(String id) {
    switch (id) {
      case 'input': return Icons.input;
      case 'theory': return Icons.menu_book;
      case 'examples': return Icons.lightbulb_outline;
      case 'exercises': return Icons.quiz_outlined;
      case 'vocabulary': return Icons.translate;
      case 'practice': return Icons.fitness_center;
      case 'reading_agent': return Icons.chrome_reader_mode;
      case 'speaking_agent': return Icons.mic;
      case 'writing_agent': return Icons.edit;
      default: return Icons.circle;
    }
  }

  Widget _buildNodeBody(String id, _NodeData node) {
    if (id == 'input') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _topicCtl.text.isEmpty ? 'Tap to set topic + notes' : _topicCtl.text,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 10,
              color: _topicCtl.text.isEmpty ? Colors.white30 : Colors.white,
              fontStyle: _topicCtl.text.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (_notesCtl.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${_notesCtl.text.length} chars of notes', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, color: Colors.white30)),
          ],
          if (_sources.any((s) => s.text != null)) ...[
            const SizedBox(height: 4),
            Text('${_sources.where((s) => s.text != null).length} sources loaded', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, color: const Color(0xFF6B8E7F))),
          ],
        ],
      );
    }

    if (node.type == 'source') {
      final idx = int.tryParse(id.replaceAll('source_', '')) ?? 0;
      final source = idx < _sources.length ? _sources[idx] : null;
      if (source == null) return const SizedBox.shrink();
      if (source.isIngesting) return const Text('Fetching…', style: TextStyle(fontFamily: 'Georgia', fontSize: 10, color: Colors.white30, fontStyle: FontStyle.italic));
      if (source.text != null) return Text('${source.title ?? 'Source'} · ${source.text!.length} chars', style: const TextStyle(fontFamily: 'Georgia', fontSize: 9, color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis);
      if (source.error != null) return Text(source.error!, style: const TextStyle(fontFamily: 'Georgia', fontSize: 9, color: Colors.redAccent), maxLines: 2, overflow: TextOverflow.ellipsis);
      return Text(source.type == 'text' ? 'Tap to paste text' : 'Tap to add ${source.type}', style: TextStyle(fontFamily: 'Georgia', fontSize: 10, color: Colors.white30, fontStyle: FontStyle.italic));
    }

    if (node.type == 'agent') {
      final msgCount = node.chatHistory.length;
      return Text(
        msgCount == 0 ? 'Tap to chat' : '$msgCount messages',
        style: TextStyle(fontFamily: 'Georgia', fontSize: 10, color: msgCount > 0 ? Colors.white : Colors.white30, fontStyle: msgCount > 0 ? FontStyle.normal : FontStyle.italic),
      );
    }

    // Output nodes
    if (node.error != null) {
      return Text(node.error!, style: const TextStyle(fontFamily: 'Georgia', fontSize: 9, color: Colors.redAccent));
    }
    if (node.content == null) {
      return Text(
        node.isGenerating ? 'Generating…' : 'Tap to generate',
        style: TextStyle(fontFamily: 'Georgia', fontSize: 10, color: Colors.white30, fontStyle: FontStyle.italic),
      );
    }
    // Show a preview of the content
    final preview = _nodePreview(id, node.content!);
    return Text(
      preview,
      style: const TextStyle(fontFamily: 'Georgia', fontSize: 9, color: Colors.white70, height: 1.3),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _nodePreview(String id, Map<String, dynamic> content) {
    switch (id) {
      case 'theory':
        final t = content['theory'] as String? ?? '';
        return t.isNotEmpty ? t.substring(0, t.length.clamp(0, 100)) : 'Theory ready';
      case 'examples':
        final e = content['examples'] as List? ?? [];
        return '${e.length} examples';
      case 'exercises':
        final e = content['exercises'] as List? ?? [];
        return '${e.length} exercises';
      case 'vocabulary':
        final v = content['vocabulary'] as List? ?? [];
        return '${v.length} words';
      case 'practice':
        final p = content['practice_prompt'] as String? ?? '';
        return p.isNotEmpty ? p.substring(0, p.length.clamp(0, 80)) : 'Practice ready';
      default: return 'Ready';
    }
  }

  // ---- Side panel ----

  Widget _buildSidePanel() {
    final node = _nodes[_selectedNode!]!;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 420,
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF252535),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: node.color, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: node.color, borderRadius: const BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5))),
              child: Row(
                children: [
                  Icon(_nodeIcon(_selectedNode!), size: 14, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(node.title, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white))),
                  IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.white70), onPressed: () => setState(() => _selectedNode = null)),
                ],
              ),
            ),
            // Body
            Expanded(child: _buildPanelBody(_selectedNode!, node)),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelBody(String id, _NodeData node) {
    if (id == 'input') return _buildInputPanel();
    if (node.type == 'source') return _buildSourcePanel(id, node);
    if (node.type == 'agent') return _buildAgentPanel(id, node);
    return _buildOutputPanel(id, node);
  }

  Widget _buildSourcePanel(String id, _NodeData node) {
    final sourceIndex = int.tryParse(id.replaceAll('source_', '')) ?? 0;
    final source = sourceIndex < _sources.length ? _sources[sourceIndex] : _SourceData(type: 'url');
    final urlCtl = TextEditingController(text: source.urlOrQuery);

    return StatefulBuilder(
      builder: (ctx, setLocal) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('SOURCE TYPE', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white54)),
            const SizedBox(height: 8),
            Row(
              children: [
                _sourceTypeChip('YouTube', 'youtube', source, setLocal),
                const SizedBox(width: 4),
                _sourceTypeChip('URL', 'url', source, setLocal),
                const SizedBox(width: 4),
                _sourceTypeChip('Text', 'text', source, setLocal),
              ],
            ),
            const SizedBox(height: 16),
            if (source.type == 'text') ...[
              const Text('PASTE TEXT', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white54)),
              const SizedBox(height: 6),
              TextField(
                controller: urlCtl,
                maxLines: 8,
                decoration: const InputDecoration(hintText: 'Paste any text — transcript, article, notes…', border: OutlineInputBorder(), hintStyle: TextStyle(color: Colors.white24)),
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Colors.white, height: 1.5),
                onChanged: (v) => source.urlOrQuery = v,
              ),
            ] else ...[
              const Text('URL', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white54)),
              const SizedBox(height: 6),
              TextField(
                controller: urlCtl,
                decoration: InputDecoration(
                  hintText: source.type == 'youtube' ? 'https://youtube.com/watch?v=…' : 'https://example.com/article',
                  border: const OutlineInputBorder(),
                  hintStyle: const TextStyle(color: Colors.white24),
                ),
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Colors.white),
                onChanged: (v) => source.urlOrQuery = v,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: source.isIngesting ? null : () => _ingestSource(id, source),
                icon: source.isIngesting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                    : const Icon(Icons.download_for_offline, size: 14),
                label: Text(source.isIngesting ? 'FETCHING…' : 'FETCH CONTENT', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6B8E7F), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
              ),
            ),
            const SizedBox(height: 16),
            if (source.error != null) ...[
              Text(source.error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Georgia', fontSize: 11)),
              const SizedBox(height: 8),
            ],
            if (source.text != null) ...[
              const Text('EXTRACTED CONTENT', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white54)),
              const SizedBox(height: 6),
              if (source.title != null) ...[
                Text(source.title!, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 6),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF1F1F2E), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  source.text!,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Colors.white60, height: 1.4),
                  maxLines: 12,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Text('${source.text!.length} chars will be used as AI knowledge', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: Colors.white30)),
            ] else ...[
              const Text('Fetch content from this source. The AI will use it as knowledge when generating materials.', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: Colors.white38, height: 1.4)),
            ],
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _removeSource(id),
              icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
              label: const Text('REMOVE SOURCE', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  Widget _sourceTypeChip(String label, String type, _SourceData source, StateSetter setLocal) {
    final selected = source.type == type;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.white54)),
      selected: selected,
      selectedColor: const Color(0xFF6B8E7F),
      backgroundColor: const Color(0xFF1F1F2E),
      side: BorderSide(color: selected ? const Color(0xFF6B8E7F) : Colors.white12),
      onSelected: (_) => setLocal(() => source.type = type),
    );
  }

  Widget _buildInputPanel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('TOPIC', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white54)),
        const SizedBox(height: 6),
        TextField(
          controller: _topicCtl,
          decoration: const InputDecoration(hintText: 'e.g. Conditional sentences', border: OutlineInputBorder(), hintStyle: TextStyle(color: Colors.white24)),
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, color: Colors.white),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        const Text('NOTES (dump your ideas)', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white54)),
        const SizedBox(height: 6),
        TextField(
          controller: _notesCtl,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'Bullet points, goals, student struggles, examples…', border: OutlineInputBorder(), hintStyle: TextStyle(color: Colors.white24)),
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: Colors.white, height: 1.5),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _darkDropdown('Exam', _exam, {'GENERAL': 'General', 'TOEFL_IBT': 'iBT', 'IELTS': 'IELTS', 'TOEIC': 'TOEIC'}, (v) => setState(() => _exam = v))),
            const SizedBox(width: 8),
            Expanded(child: _darkDropdown('Level', _level, {'A2': 'A2', 'B1': 'B1', 'B2': 'B2', 'C1': 'C1'}, (v) => setState(() => _level = v))),
            const SizedBox(width: 8),
            Expanded(child: _darkDropdown('Type', _itemType, {'grammar': 'Grammar', 'vocabulary': 'Vocab', 'reading': 'Reading', 'writing': 'Writing', 'speaking': 'Speaking'}, (v) => setState(() => _itemType = v))),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Now tap any output node on the canvas to generate it.', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: Colors.white38, height: 1.4)),
      ],
    );
  }

  Widget _darkDropdown(String label, String value, Map<String, String> items, void Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white38)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(4)),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF252535),
            items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Colors.white)))).toList(),
            onChanged: (v) => onChanged(v ?? value),
          ),
        ),
      ],
    );
  }

  Widget _buildOutputPanel(String id, _NodeData node) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Generate / regenerate button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: node.isGenerating ? null : () => _generateNode(id),
            icon: node.isGenerating
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                : Icon(node.content == null ? Icons.auto_awesome : Icons.refresh, size: 14),
            label: Text(
              node.isGenerating ? 'GENERATING…' : (node.content == null ? 'GENERATE' : 'REGENERATE'),
              style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5),
            ),
            style: FilledButton.styleFrom(backgroundColor: node.color, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
          ),
        ),
        const SizedBox(height: 16),
        // Content preview
        if (node.content != null) ...[
          _buildNodeContentPreview(id, node.content!),
          const SizedBox(height: 16),
          const Text('Connect to agent nodes → to refine with a specialist', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: Colors.white38)),
        ] else if (node.error != null) ...[
          Text(node.error!, style: const TextStyle(color: Colors.redAccent, fontFamily: 'Georgia', fontSize: 12)),
        ] else ...[
          const Text('Tap GENERATE to create this content with AI.', style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 12, color: Colors.white38)),
        ],
      ],
    );
  }

  Widget _buildNodeContentPreview(String id, Map<String, dynamic> content) {
    switch (id) {
      case 'theory':
        final theory = (content['theory'] as String? ?? '').replaceAll('\\n', '\n');
        final keyPoints = (content['key_points'] as List? ?? const []) as List;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content['title'] != null) ...[
              Text(content['title'] as String, style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 8),
            ],
            if (content['summary'] != null) ...[
              Text(content['summary'] as String, style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 12, color: Colors.white54, height: 1.4)),
              const SizedBox(height: 8),
            ],
            Text(theory, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Colors.white70, height: 1.6)),
            if (keyPoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('KEY POINTS', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white38)),
              const SizedBox(height: 4),
              for (final p in keyPoints) Padding(padding: const EdgeInsets.only(left: 8, bottom: 2), child: Text('• ${p}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Colors.white60))),
            ],
          ],
        );
      case 'examples':
        final examples = (content['examples'] as List? ?? const []) as List;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in examples)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF1F1F2E), borderRadius: BorderRadius.circular(4)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((e as Map<String, dynamic>)['input'] as String? ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 4),
                  Text('→ ${e['output']}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, fontWeight: FontWeight.w700, color: OseeTheme.sage)),
                  if ((e['explanation'] as String?)?.isNotEmpty ?? false) Text(e['explanation'] as String, style: const TextStyle(fontFamily: 'Georgia', fontSize: 10, color: Colors.white38)),
                ]),
              ),
          ],
        );
      case 'exercises':
        final exercises = (content['exercises'] as List? ?? const []) as List;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < exercises.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF1F1F2E), borderRadius: BorderRadius.circular(4)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i + 1}. ${(exercises[i] as Map<String, dynamic>)['question'] as String? ?? ''}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 2),
                  Text('Answer: ${(exercises[i] as Map<String, dynamic>)['answer'] as String? ?? ''}', style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, fontWeight: FontWeight.w700, color: OseeTheme.sage)),
                ]),
              ),
          ],
        );
      case 'vocabulary':
        final vocab = (content['vocabulary'] as List? ?? const []) as List;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final v in vocab)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((v as Map<String, dynamic>)['word'] as String? ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(v['definition'] as String? ?? '', style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Colors.white60))),
                ]),
              ),
          ],
        );
      case 'practice':
        final p = content['practice_prompt'] as String? ?? '';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0x1AE63946), borderRadius: BorderRadius.circular(4), border: Border(left: BorderSide(color: OseeTheme.accent, width: 2))),
          child: Text(p, style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 13, color: Colors.white, height: 1.5)),
        );
      default:
        return const Text('Content ready', style: TextStyle(color: Colors.white));
    }
  }

  Widget _buildAgentPanel(String id, _NodeData node) {
    final msgCtl = TextEditingController();
    return StatefulBuilder(
      builder: (ctx, setLocal) {
        return Column(
          children: [
            // Chat history
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: node.chatHistory.length,
                itemBuilder: (_, i) {
                  final msg = node.chatHistory[i];
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      constraints: BoxConstraints(maxWidth: 340),
                      decoration: BoxDecoration(
                        color: isUser ? node.color.withOpacity(0.2) : const Color(0xFF1F1F2E),
                        borderRadius: BorderRadius.circular(4),
                        border: Border(left: BorderSide(color: isUser ? Colors.transparent : node.color, width: 2)),
                      ),
                      child: Text(msg['content'] ?? '', style: TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Colors.white70, height: 1.4)),
                    ),
                  );
                },
              ),
            ),
            // Input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: msgCtl,
                      decoration: const InputDecoration(
                        hintText: 'Ask the agent to refine…',
                        hintStyle: TextStyle(color: Colors.white24),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Colors.white),
                      onSubmitted: (_) => _send(msgCtl, node, setLocal),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send, size: 16),
                    style: IconButton.styleFrom(backgroundColor: node.color),
                    onPressed: node.isGenerating ? null : () => _send(msgCtl, node, setLocal),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _send(TextEditingController ctl, _NodeData node, StateSetter setLocal) {
    final text = ctl.text.trim();
    if (text.isEmpty) return;
    ctl.clear();
    _sendAgentMessage(_selectedNode!, text);
    setLocal(() {});
  }

  // ---- Controls overlay ----

  Widget _buildControls() {
    return Positioned(
      bottom: 12,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(4)),
        child: Text(
          'Drag nodes to move · Drag empty space to pan · Drag to select · Tap a node to open its panel · Drag corner to resize',
          style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, color: Colors.white38, letterSpacing: 0.5),
        ),
      ),
    );
  }

  // ---- Zoom controls (bottom-right) ----

  Widget _buildZoomControls() {
    return Positioned(
      bottom: 12,
      right: 12,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.zoom_out, size: 18, color: Colors.white70),
              onPressed: () => setState(() => _zoom = (_zoom - 0.1).clamp(0.2, 3.0)),
              tooltip: 'Zoom out',
              iconSize: 18,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Text(
              '${(_zoom * 100).round()}%',
              style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: Colors.white54),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 18, color: Colors.white70),
              onPressed: () => setState(() => _zoom = (_zoom + 0.1).clamp(0.2, 3.0)),
              tooltip: 'Zoom in',
              iconSize: 18,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Container(width: 1, height: 20, color: Colors.white12),
            IconButton(
              icon: const Icon(Icons.center_focus_strong, size: 18, color: Colors.white70),
              onPressed: _fitToScreen,
              tooltip: 'Fit to screen',
              iconSize: 18,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Floating toolbar (bottom-center) ----

  Widget _buildFloatingToolbar() {
    return Positioned(
      bottom: 12,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xE61F1F2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12, width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: Icons.inventory_2_outlined,
                label: 'Brain Dump',
                color: OseeTheme.accent,
                onTap: _showBrainDumpDialog,
              ),
              _ToolbarButton(
                icon: Icons.add_link,
                label: 'Source',
                color: const Color(0xFF6B8E7F),
                onTap: _addSourceNode,
              ),
              _ToolbarButton(
                icon: Icons.sticky_note_2_outlined,
                label: 'Note',
                color: const Color(0xFFE0B04F),
                onTap: _addTextNoteNode,
              ),
              Container(width: 1, height: 24, color: Colors.white12),
              _ToolbarButton(
                icon: Icons.menu_book,
                label: 'Theory',
                color: const Color(0xFF4F8DE0),
                onTap: () => _addOutputNode('theory', 'THEORY', const Color(0xFF4F8DE0)),
              ),
              _ToolbarButton(
                icon: Icons.lightbulb_outline,
                label: 'Examples',
                color: OseeTheme.sage,
                onTap: () => _addOutputNode('examples', 'EXAMPLES', OseeTheme.sage),
              ),
              _ToolbarButton(
                icon: Icons.quiz_outlined,
                label: 'Exercises',
                color: OseeTheme.accent,
                onTap: () => _addOutputNode('exercises', 'EXERCISES', OseeTheme.accent),
              ),
              _ToolbarButton(
                icon: Icons.translate,
                label: 'Vocab',
                color: OseeTheme.gold,
                onTap: () => _addOutputNode('vocabulary', 'VOCABULARY', OseeTheme.gold),
              ),
              _ToolbarButton(
                icon: Icons.mic,
                label: 'Speaking Agent',
                color: const Color(0xFFE5913D),
                onTap: () => _addAgentNode('speaking'),
              ),
              _ToolbarButton(
                icon: Icons.edit,
                label: 'Writing Agent',
                color: const Color(0xFF5BA674),
                onTap: () => _addAgentNode('writing'),
              ),
              _ToolbarButton(
                icon: Icons.chrome_reader_mode,
                label: 'Reading Agent',
                color: const Color(0xFF4F8DE0),
                onTap: () => _addAgentNode('reading'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addOutputNode(String type, String title, Color color) {
    final id = '${type}_${DateTime.now().microsecondsSinceEpoch}';
    _nodePositions[id] = Offset(
      440 + (_nodes.length * 20 % 200),
      40 + (_nodes.length * 50 % 800),
    );
    _nodes[id] = _NodeData(type: type, title: title, color: color);
    _nodeSizes[id] = const Size(180, 100);
    setState(() => _selectedNode = id);
  }

  void _addAgentNode(String agentType) {
    final id = '${agentType}_agent_${DateTime.now().microsecondsSinceEpoch}';
    _nodePositions[id] = Offset(880, 120 + (_nodes.length * 30 % 600));
    final colorMap = {
      'reading': const Color(0xFF4F8DE0),
      'speaking': const Color(0xFFE5913D),
      'writing': const Color(0xFF5BA674),
    };
    _nodes[id] = _NodeData(
      type: 'agent',
      title: '${agentType.toUpperCase()} AGENT',
      color: colorMap[agentType] ?? Colors.blue,
      agentType: agentType,
    );
    _nodeSizes[id] = const Size(180, 80);
    setState(() => _selectedNode = id);
  }

  // ---- Brain dump — batch ingest multiple sources at once ----

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
          backgroundColor: const Color(0xFF252535),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.white12)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BRAIN DUMP', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3, color: OseeTheme.accent)),
              const SizedBox(height: 4),
              const Text('Dump all your sources at once', style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 6),
              Container(height: 1, color: OseeTheme.gold),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cluster label
                TextField(
                  controller: clusterCtl,
                  decoration: const InputDecoration(
                    labelText: 'Cluster label (optional)',
                    labelStyle: TextStyle(color: Colors.white38, fontSize: 10),
                    hintText: 'e.g. Textbook chapter 3, YouTube tutorials, Lesson notes…',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: Colors.white),
                ),
                const SizedBox(height: 12),
                // URLs — one per line
                const Text('URLS / YOUTUBE LINKS (one per line)', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white38)),
                const SizedBox(height: 4),
                TextField(
                  controller: urlsCtl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'https://en.wikipedia.org/wiki/Conditional_sentence\nhttps://youtube.com/watch?v=...\nhttps://example.com/article',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'Georgia'),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: 12),
                // Pasted text
                const Text('PASTED TEXT (any notes, transcripts, articles)', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white38)),
                const SizedBox(height: 4),
                TextField(
                  controller: textCtl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Paste any text content — transcripts, notes, textbook excerpts…',
                    hintStyle: TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'Georgia'),
                    border: OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: 12),
                if (resultText != null)
                  Text(resultText!, style: TextStyle(fontFamily: 'Georgia', fontSize: 11, color: isIngesting ? Colors.white54 : OseeTheme.sage, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
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
                if (textContent.isNotEmpty) {
                  sources.add({'type': 'text', 'content': textContent});
                }

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

                  // Add source nodes to canvas for each ingested source
                  for (var i = 0; i < ingested.length; i++) {
                    final src = ingested[i] as Map<String, dynamic>;
                    final id = 'source_$_sourceCounter';
                    _sourceCounter++;
                    _nodePositions[id] = Offset(-380, 200.0 + (_sources.length * 130));
                    final source = _SourceData(type: src['type'] as String? ?? 'url');
                    source.title = src['title'] as String?;
                    source.text = src['text'] as String?;
                    _sources.add(source);
                    _nodes[id] = _NodeData(type: 'source', title: 'SOURCE ${_sources.length}', color: const Color(0xFF6B8E7F));
                    _nodeSizes[id] = const Size(180, 90);
                  }

                  setLocal(() {
                    isIngesting = false;
                    resultText = '${ingested.length} sources ingested, $embedded embedded into RAG${errors.isNotEmpty ? ', ${errors.length} errors' : ''}';
                  });
                  setState(() {});

                  // Auto-close after success
                  await Future.delayed(const Duration(seconds: 2));
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setLocal(() { isIngesting = false; resultText = 'Failed: $e'; });
                }
              },
              icon: isIngesting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(isIngesting ? 'INGESTING…' : 'DUMP & EMBED', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              style: FilledButton.styleFrom(backgroundColor: OseeTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Models
// ============================================================

class _NodeData {
  final String type; // input | theory | examples | exercises | vocabulary | practice | agent | source
  final String title;
  final Color color;
  final String? agentType; // for agent nodes
  Map<String, dynamic>? content;
  bool isGenerating;
  String? error;
  final List<Map<String, String>> chatHistory;

  _NodeData({
    required this.type,
    required this.title,
    required this.color,
    this.agentType,
    this.content,
    this.isGenerating = false,
    this.error,
    this.chatHistory = const [],
  });
}

/// Source data — ingested content from YouTube/URL/text used as AI knowledge.
class _SourceData {
  String type; // 'youtube' | 'url' | 'text'
  String urlOrQuery;
  String? title;
  String? text;
  String? error;
  bool isIngesting;

  _SourceData({
    this.type = 'url',
    this.urlOrQuery = '',
    this.title,
    this.text,
    this.error,
    this.isIngesting = false,
  });
}

class _Edge {
  final String from;
  final String to;
  final bool faded;
  const _Edge({required this.from, required this.to, this.faded = false});
}

// ============================================================
// Edge painter — bezier curves between nodes
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

    // Arrow dot at destination
    canvas.drawCircle(to, 3, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => from != old.from || to != old.to || color != old.color;
}

// ============================================================
// Grid background — dot grid pattern like remalt/Miro
// ============================================================

class _GridBackground extends StatelessWidget {
  const _GridBackground({required this.pan, required this.zoom});
  final Offset pan;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _GridPainter(pan: pan, zoom: zoom),
    );
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

    // Dot grid
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;

    for (var x = offsetX; x < size.width; x += effectiveSpacing) {
      for (var y = offsetY; y < size.height; y += effectiveSpacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }

    // Larger dot every 5 cells (for visual rhythm)
    final bigPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.fill;
    final bigSpacing = effectiveSpacing * 5;
    final bigOffsetX = pan.dx % bigSpacing;
    final bigOffsetY = pan.dy % bigSpacing;
    for (var x = bigOffsetX; x < size.width; x += bigSpacing) {
      for (var y = bigOffsetY; y < size.height; y += bigSpacing) {
        canvas.drawCircle(Offset(x, y), 2, bigPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => pan != old.pan || zoom != old.zoom;
}

// ============================================================
// Toolbar button — floating add-node button
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}