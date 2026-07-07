import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/mind_board_api.dart';

/// Material Bank — two-panel magazine-style browser with draggable question cards.
///
/// Left sidebar: category tree (Exam → Package → Part/Topic).
/// Right panel: draggable question cards in the selected group.
///
/// Can be used standalone (full page) or embedded as a side panel
/// in the lesson builder for drag-drop into blocks.
class MaterialBankPage extends ConsumerStatefulWidget {
  const MaterialBankPage({super.key, this.onSelectQuestion, this.enableDrag = false});
  final void Function(Map<String, dynamic> question)? onSelectQuestion;
  final bool enableDrag;

  @override
  ConsumerState<MaterialBankPage> createState() => _MaterialBankPageState();
}

class _MaterialBankPageState extends ConsumerState<MaterialBankPage> {
  late final MindBoardApi _api;
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  String? _selectedPackageId;
  String? _selectedExam;
  String? _selectedPart;
  String? _selectedTopic;
  String? _searchQuery;
  int _offset = 0;
  int _total = 0;
  static const int _pageSize = 30;

  // Tree state
  String? _expandedExam;
  String? _expandedPackage;

  @override
  void initState() {
    super.initState();
    _api = ref.read(mindBoardApiProvider);
    _loadPackages();
    _loadQuestions();
  }

  Future<void> _loadPackages() async {
    try {
      final pkgs = await _api.listPackages();
      setState(() => _packages = pkgs);
    } catch (_) {}
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        final results = await _api.searchQuestions(_searchQuery!, examType: _selectedExam);
        setState(() {
          _questions = results;
          _total = results.length;
          _isLoading = false;
        });
      } else {
        final result = await _api.listQuestions(
          packageId: _selectedPackageId,
          examType: _selectedExam,
          part: _selectedPart,
          limit: _pageSize,
          offset: _offset,
        );
        setState(() {
          _questions = (result['questions'] as List).cast<Map<String, dynamic>>();
          _total = (result['total'] as num?)?.toInt() ?? 0;
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _selectGroup({String? exam, String? packageId, String? part, String? topic}) {
    _selectedExam = exam;
    _selectedPackageId = packageId;
    _selectedPart = part;
    _selectedTopic = topic;
    _offset = 0;
    _searchQuery = null;
    _loadQuestions();
  }

  void _onSearch(String query) {
    _searchQuery = query.trim().isEmpty ? null : query.trim();
    _offset = 0;
    _loadQuestions();
  }

  // Group packages by exam type
  Map<String, List<Map<String, dynamic>>> get _packagesByExam {
    final m = <String, List<Map<String, dynamic>>>{};
    for (final p in _packages) {
      final exam = (p['exam_type'] as String?) ?? 'UNKNOWN';
      m.putIfAbsent(exam, () => []).add(p);
    }
    return m;
  }

  // Group packages by product_line within an exam
  Map<String, List<Map<String, dynamic>>> _packagesByProductLine(String exam) {
    final m = <String, List<Map<String, dynamic>>>{};
    for (final p in _packagesByExam[exam] ?? []) {
      final pl = (p['product_line'] as String?) ?? 'unknown';
      m.putIfAbsent(pl, () => []).add(p);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return widget.onSelectQuestion != null && !widget.enableDrag
        ? _buildStandalonePage()
        : _buildEmbeddedBrowser();
  }

  // ---- Standalone full-page mode ----
  Widget _buildStandalonePage() {
    return Scaffold(
      backgroundColor: OseeTheme.paper,
      appBar: AppBar(
        backgroundColor: OseeTheme.paper,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: OseeTheme.ink, width: 2)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: OseeTheme.ink), onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MATERIAL BANK', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 3, color: OseeTheme.ink)),
          const SizedBox(height: 2),
          Text('$_total questions available', style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
        ]),
      ),
      body: _buildTwoPanel(),
    );
  }

  // ---- Embedded side-panel mode (for lesson builder) ----
  Widget _buildEmbeddedBrowser() {
    return Container(
      color: OseeTheme.paper,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(color: OseeTheme.ink, border: Border(bottom: BorderSide(color: OseeTheme.gold, width: 1))),
            child: Row(children: [
              const Icon(Icons.library_books, size: 14, color: OseeTheme.gold),
              const SizedBox(width: 6),
              const Text('MATERIAL BANK', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white)),
              const Spacer(),
              Text('$_total', style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, fontWeight: FontWeight.w700, color: OseeTheme.gold)),
            ]),
          ),
          Expanded(child: _buildTwoPanel()),
        ],
      ),
    );
  }

  // ---- Two-panel browser (shared) ----
  Widget _buildTwoPanel() {
    return Row(
      children: [
        // Left sidebar — category tree
        _buildSidebar(),
        // Vertical divider
        Container(width: 1, color: OseeTheme.cloud),
        // Right panel — question cards
        Expanded(child: _buildQuestionPanel()),
      ],
    );
  }

  // ---- Left sidebar ----
  Widget _buildSidebar() {
    return Container(
      width: 200,
      color: const Color(0xFFEFEDE6),
      child: Column(
        children: [
          // Search
          Container(
            padding: const EdgeInsets.all(8),
            child: TextField(
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search…',
                hintStyle: TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.ink.withValues(alpha: 0.4), fontStyle: FontStyle.italic),
                prefixIcon: Icon(Icons.search, size: 14, color: OseeTheme.stone),
                border: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.cloud)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.ink, width: 2)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.ink),
            ),
          ),
          // Tree
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                // "All Questions"
                _treeItem('All Questions', '$_total', _selectedExam == null && _selectedPackageId == null, () => _selectGroup()),
                const Divider(height: 8, color: OseeTheme.cloud),
                // Exam types
                ..._packagesByExam.entries.map((examEntry) {
                  final exam = examEntry.key;
                  final pkgs = examEntry.value;
                  final examLabel = exam.replaceAll('_', ' ');
                  final isExpanded = _expandedExam == exam;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _treeItem(examLabel, '${pkgs.length} packages', _selectedExam == exam && _selectedPackageId == null, () {
                        setState(() => _expandedExam = isExpanded ? null : exam);
                        _selectGroup(exam: exam);
                      }, isHeader: true),
                      if (isExpanded)
                        ..._packagesByProductLine(exam).entries.map((plEntry) {
                          final pl = plEntry.key;
                          final plPackages = plEntry.value;
                          final plLabel = pl.replaceAll('_', ' ');
                          return Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                                  child: Text(plLabel.toUpperCase(), style: TextStyle(fontFamily: 'Helvetica', fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.stone)),
                                ),
                                ...plPackages.map((pkg) {
                                  final pkgCode = (pkg['package_code'] as String?) ?? '';
                                  final pkgId = (pkg['id'] as String?) ?? '';
                                  final isActive = _selectedPackageId == pkgId;
                                  return _treeItem(pkgCode, '', isActive, () => _selectGroup(exam: exam, packageId: pkgId), indent: 32);
                                }),
                              ],
                            ),
                          );
                        }),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _treeItem(String label, String count, bool isActive, VoidCallback onTap, {bool isHeader = false, double indent = 0}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(left: 8 + indent, right: 8, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          border: Border(left: BorderSide(color: isActive ? OseeTheme.accent : Colors.transparent, width: 2)),
        ),
        child: Row(
          children: [
            if (isHeader)
              Icon(_expandedExam == label.replaceAll(' ', '_') ? Icons.expand_more : Icons.chevron_right, size: 12, color: OseeTheme.stone),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: isHeader ? 'Helvetica' : 'Georgia',
                  fontSize: isHeader ? 10 : 11,
                  fontWeight: isHeader ? FontWeight.w700 : isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? OseeTheme.ink : OseeTheme.ink.withValues(alpha: 0.7),
                  letterSpacing: isHeader ? 1 : 0,
                ),
              ),
            ),
            if (count.isNotEmpty)
              Text(count, style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, color: OseeTheme.stone)),
          ],
        ),
      ),
    );
  }

  // ---- Right panel — question cards ----
  Widget _buildQuestionPanel() {
    return Column(
      children: [
        // Current filter indicator
        if (_selectedPackageId != null || _selectedExam != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 12, color: OseeTheme.stone),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  _selectedPackageId != null
                      ? _packages.firstWhere((p) => p['id'] == _selectedPackageId, orElse: () => {})['package_code'] as String? ?? ''
                      : _selectedExam?.replaceAll('_', ' ') ?? 'All',
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.ink),
                )),
                if (_searchQuery != null)
                  Text('Search: "$_searchQuery"', style: TextStyle(fontFamily: 'Georgia', fontSize: 9, color: OseeTheme.stone, fontStyle: FontStyle.italic)),
                const SizedBox(width: 8),
                Text('${_offset + 1}–${(_offset + _pageSize).clamp(0, _total)} of $_total', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, color: OseeTheme.stone)),
              ],
            ),
          ),
        // Question list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: OseeTheme.ink))
              : _questions.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.search_off, size: 36, color: OseeTheme.cloud),
                      const SizedBox(height: 8),
                      Text('No questions found.', style: TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink.withValues(alpha: 0.5), fontStyle: FontStyle.italic)),
                    ]))
                  : widget.enableDrag
                      ? _buildDraggableList()
                      : _buildTappableList(),
        ),
        // Pagination
        if (_total > _pageSize)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: OseeTheme.cloud))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _offset > 0 ? () { _offset = (_offset - _pageSize).clamp(0, _total); _loadQuestions(); } : null,
                  child: const Text('◀ PREV', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: OseeTheme.ink)),
                ),
                TextButton(
                  onPressed: _offset + _pageSize < _total ? () { _offset += _pageSize; _loadQuestions(); } : null,
                  child: const Text('NEXT ▶', style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: OseeTheme.ink)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Draggable cards (for side panel mode in lesson builder)
  Widget _buildDraggableList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _questions.length,
      itemBuilder: (_, i) => _DraggableQuestionCard(
        question: _questions[i],
        onTap: widget.onSelectQuestion != null
            ? () { widget.onSelectQuestion!(_questions[i]); }
            : () => _showQuestionDetail(_questions[i]),
      ),
    );
  }

  // Tappable cards (for standalone page mode)
  Widget _buildTappableList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: _questions.length,
      itemBuilder: (_, i) => _QuestionCard(
        question: _questions[i],
        onTap: () => _showQuestionDetail(_questions[i]),
      ),
    );
  }

  void _showQuestionDetail(Map<String, dynamic> q) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: OseeTheme.paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(2))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, sc) => _QuestionDetail(question: q),
      ),
    );
  }
}

// ============================================================
// Draggable question card — for drag-drop into lesson blocks
// ============================================================

class _DraggableQuestionCard extends StatelessWidget {
  const _DraggableQuestionCard({required this.question, required this.onTap});
  final Map<String, dynamic> question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Draggable<Map<String, dynamic>>(
      data: question,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: OseeTheme.ink, border: Border.all(color: OseeTheme.gold, width: 2), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)]),
          child: Text(
            (question['question_text'] as String?) ?? 'Question',
            maxLines: 3, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: Colors.white, height: 1.3),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _card()),
      child: _card(),
    );
  }

  Widget _card() {
    final exam = (question['exam_type'] as String?) ?? '—';
    final part = (question['part'] as String?) ?? '—';
    final qType = (question['question_type'] as String?)?.replaceAll('_', ' ') ?? 'question';
    final topic = (question['topic'] as String?) ?? '';
    final cefr = (question['cefr_level'] as String?) ?? '';
    final text = (question['question_text'] as String?) ?? '';

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: OseeTheme.gold, width: 2), top: BorderSide(color: OseeTheme.cloud), bottom: BorderSide(color: OseeTheme.cloud), right: BorderSide(color: OseeTheme.cloud)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: OseeTheme.ink), child: Text(exam.replaceAll('_', ' '), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 6, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: Colors.white))),
                const SizedBox(width: 4),
                Text('P$part', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 7, fontWeight: FontWeight.w700, color: OseeTheme.gold)),
                if (cefr.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(cefr, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 7, color: OseeTheme.stone)),
                ],
                const Spacer(),
                Icon(Icons.drag_indicator, size: 12, color: OseeTheme.stone),
              ],
            ),
            const SizedBox(height: 4),
            Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.ink, height: 1.3)),
            if (topic.isNotEmpty)
              Text(topic, style: TextStyle(fontFamily: 'Georgia', fontSize: 8, color: OseeTheme.stone, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Tappable question card — for standalone page mode
// ============================================================

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, required this.onTap});
  final Map<String, dynamic> question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final exam = (question['exam_type'] as String?) ?? '—';
    final part = (question['part'] as String?) ?? '—';
    final qType = (question['question_type'] as String?)?.replaceAll('_', ' ') ?? 'question';
    final topic = (question['topic'] as String?) ?? '';
    final cefr = (question['cefr_level'] as String?) ?? '';
    final text = (question['question_text'] as String?) ?? '';

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: OseeTheme.gold, width: 2), top: BorderSide(color: OseeTheme.cloud), bottom: BorderSide(color: OseeTheme.cloud), right: BorderSide(color: OseeTheme.cloud)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: OseeTheme.ink), child: Text(exam.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white))),
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(border: Border.all(color: OseeTheme.gold)), child: Text('PART $part', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 1, color: OseeTheme.gold))),
                const SizedBox(width: 6),
                Text(qType.toUpperCase(), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: 1, color: OseeTheme.stone)),
                if (cefr.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(border: Border.all(color: OseeTheme.cloud)), child: Text(cefr, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 7, fontWeight: FontWeight.w700, color: OseeTheme.ink))),
                ],
                const Spacer(),
                const Icon(Icons.chevron_right, size: 14, color: OseeTheme.stone),
              ],
            ),
            const SizedBox(height: 6),
            Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, height: 1.5)),
            if (topic.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(topic, style: const TextStyle(fontFamily: 'Georgia', fontSize: 9, color: OseeTheme.stone, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Question detail bottom sheet
// ============================================================

class _QuestionDetail extends StatelessWidget {
  const _QuestionDetail({required this.question});
  final Map<String, dynamic> question;

  @override
  Widget build(BuildContext context) {
    final text = (question['question_text'] as String?) ?? '';
    final options = question['options'] as Map<String, dynamic>?;
    final answer = (question['correct_answer'] as String?) ?? '';
    final explanation = (question['explanation'] as String?) ?? '';
    final asset = question['asset'] as Map<String, dynamic>?;
    final scoringRubric = (question['scoring_rubric'] as String?) ?? '';
    final sampleResponse = (question['sample_response'] as String?) ?? '';
    final topic = (question['topic'] as String?) ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (topic.isNotEmpty)
          Text(topic.toUpperCase(), style: const TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.stone)),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, color: OseeTheme.ink, height: 1.6)),
        if (asset != null) ...[
          const SizedBox(height: 16),
          _magLabel('STIMULUS'),
          if (asset['context'] != null) Text(asset['context'] as String, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5, fontStyle: FontStyle.italic)),
          if (asset['transcript'] != null) ...[const SizedBox(height: 8), Text(asset['transcript'] as String, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, height: 1.5))],
        ],
        if (options != null && options.isNotEmpty) ...[
          const SizedBox(height: 16),
          _magLabel('OPTIONS'),
          for (final entry in options.entries)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${entry.key}.', style: TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: entry.key == answer ? OseeTheme.sage : OseeTheme.ink)),
              const SizedBox(width: 8),
              Expanded(child: Text(entry.value.toString(), style: TextStyle(fontFamily: 'Georgia', fontSize: 13, color: entry.key == answer ? OseeTheme.sage : OseeTheme.ink, fontWeight: entry.key == answer ? FontWeight.w700 : FontWeight.w400, height: 1.4))),
            ])),
        ],
        if (answer.isNotEmpty) ...[const SizedBox(height: 16), _magLabel('CORRECT ANSWER'), Text(answer, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: OseeTheme.sage))],
        if (explanation.isNotEmpty) ...[const SizedBox(height: 16), _magLabel('EXPLANATION'), Text(explanation, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5))],
        if (scoringRubric.isNotEmpty) ...[const SizedBox(height: 16), _magLabel('SCORING RUBRIC'), Text(scoringRubric, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5))],
        if (sampleResponse.isNotEmpty) ...[const SizedBox(height: 16), _magLabel('SAMPLE RESPONSE'), Text(sampleResponse, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5, fontStyle: FontStyle.italic))],
      ],
    );
  }

  Widget _magLabel(String label) {
    return Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
      Container(width: 12, height: 1, color: OseeTheme.ink),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.ink)),
    ]));
  }
}