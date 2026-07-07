import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/mind_board_api.dart';

/// Material Bank browser — magazine-style searchable exam question database.
///
/// Teachers browse available exam materials (TOEIC, TOEFL, IELTS), filter by
/// exam type, part, skill, CEFR level, and search by keyword. Selected questions
/// can be added to lesson blocks.
class MaterialBankPage extends ConsumerStatefulWidget {
  const MaterialBankPage({super.key, this.onSelectQuestion});
  final void Function(Map<String, dynamic> question)? onSelectQuestion;

  @override
  ConsumerState<MaterialBankPage> createState() => _MaterialBankPageState();
}

class _MaterialBankPageState extends ConsumerState<MaterialBankPage> {
  late final MindBoardApi _api;
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _skills = [];
  bool _isLoading = true;
  String? _examFilter;
  String? _partFilter;
  String? _skillFilter;
  String? _cefrFilter;
  final _searchCtl = TextEditingController();
  int _offset = 0;
  int _total = 0;
  static const int _pageSize = 30;

  static const _examTypes = ['TOEIC', 'TOEFL_IBT', 'TOEFL_ITP', 'IELTS', 'GENERAL'];
  static const _parts = ['1', '2', '3', '4', '5', '6', '7'];
  static const _cefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  @override
  void initState() {
    super.initState();
    _api = ref.read(mindBoardApiProvider);
    _loadSkills();
    _loadQuestions();
  }

  Future<void> _loadSkills() async {
    try {
      final skills = await _api.listSkills(examType: _examFilter);
      setState(() => _skills = skills);
    } catch (_) {}
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final result = await _api.listQuestions(
        examType: _examFilter,
        part: _partFilter,
        cefrLevel: _cefrFilter,
        skillTag: _skillFilter,
        limit: _pageSize,
        offset: _offset,
      );
      setState(() {
        _questions = (result['questions'] as List).cast<Map<String, dynamic>>();
        _total = (result['total'] as num?)?.toInt() ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _search() async {
    final q = _searchCtl.text.trim();
    if (q.isEmpty) {
      _loadQuestions();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final results = await _api.searchQuestions(q, examType: _examFilter);
      setState(() {
        _questions = results;
        _total = results.length;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String? exam, String? part, String? cefr) {
    _examFilter = exam;
    _partFilter = part;
    _cefrFilter = cefr;
    _offset = 0;
    _loadSkills();
    _loadQuestions();
  }

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: OseeTheme.cloud))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtl,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Search questions…',
                      hintStyle: TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink.withValues(alpha: 0.4), fontStyle: FontStyle.italic),
                      prefixIcon: Icon(Icons.search, size: 16, color: OseeTheme.stone),
                      border: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.cloud)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: OseeTheme.ink, width: 2)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _search,
                  style: FilledButton.styleFrom(backgroundColor: OseeTheme.ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  child: const Text('Search', style: TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
              ],
            ),
          ),
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('All', _examFilter == null, () => _applyFilter(null, _partFilter, _cefrFilter)),
                  ..._examTypes.map((e) => _filterChip(e.replaceAll('_', ' '), _examFilter == e, () => _applyFilter(e, _partFilter, _cefrFilter))),
                  Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 8), color: OseeTheme.cloud),
                  _filterChip('All Parts', _partFilter == null, () => _applyFilter(_examFilter, null, _cefrFilter)),
                  ..._parts.map((p) => _filterChip('Part $p', _partFilter == p, () => _applyFilter(_examFilter, p, _cefrFilter))),
                  Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 8), color: OseeTheme.cloud),
                  _filterChip('All CEFR', _cefrFilter == null, () => _applyFilter(_examFilter, _partFilter, null)),
                  ..._cefrLevels.map((l) => _filterChip(l, _cefrFilter == l, () => _applyFilter(_examFilter, _partFilter, l))),
                ],
              ),
            ),
          ),
          // Question list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: OseeTheme.ink))
                : _questions.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.search_off, size: 48, color: OseeTheme.cloud),
                        const SizedBox(height: 12),
                        Text('No questions found.', style: TextStyle(fontFamily: 'Georgia', fontSize: 14, color: OseeTheme.ink.withValues(alpha: 0.5), fontStyle: FontStyle.italic)),
                      ]))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _questions.length,
                        itemBuilder: (_, i) => _QuestionCard(
                          question: _questions[i],
                          onTap: widget.onSelectQuestion != null
                              ? () { widget.onSelectQuestion!(_questions[i]); Navigator.pop(context); }
                              : () => _showQuestionDetail(_questions[i]),
                        ),
                      ),
          ),
          // Pagination
          if (_total > _pageSize)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: OseeTheme.cloud))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_offset + 1}–${(_offset + _pageSize).clamp(0, _total)} of $_total', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 10, color: OseeTheme.ink)),
                  Row(children: [
                    TextButton(
                      onPressed: _offset > 0 ? () { _offset = (_offset - _pageSize).clamp(0, _total); _loadQuestions(); } : null,
                      child: const Text('◀ PREV', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1, color: OseeTheme.ink)),
                    ),
                    TextButton(
                      onPressed: _offset + _pageSize < _total ? () { _offset += _pageSize; _loadQuestions(); } : null,
                      child: const Text('NEXT ▶', style: TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1, color: OseeTheme.ink)),
                    ),
                  ],
                ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? OseeTheme.ink : Colors.white,
          border: Border.all(color: isActive ? OseeTheme.ink : OseeTheme.cloud),
        ),
        child: Text(label.toUpperCase(), style: TextStyle(fontFamily: 'Helvetica', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: isActive ? Colors.white : OseeTheme.ink)),
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

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, required this.onTap});
  final Map<String, dynamic> question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final exam = (question['exam_type'] as String?) ?? '—';
    final part = (question['part'] as String?) ?? '—';
    final qNum = (question['question_number'] as num?)?.toString() ?? '—';
    final qType = (question['question_type'] as String?)?.replaceAll('_', ' ') ?? 'question';
    final section = (question['section'] as String?) ?? '';
    final cefr = (question['cefr_level'] as String?) ?? '';
    final skills = (question['skill_tags'] as List?)?.cast<String>() ?? [];
    final text = (question['question_text'] as String?) ?? '';
    final hasAsset = question['asset'] != null;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: OseeTheme.gold, width: 2), top: BorderSide(color: OseeTheme.cloud), bottom: BorderSide(color: OseeTheme.cloud), right: BorderSide(color: OseeTheme.cloud)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: exam + part + type badges
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
                Text('#$qNum', style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
              ],
            ),
            const SizedBox(height: 8),
            // Question text preview
            Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5)),
            // Skill tags + asset indicator
            if (skills.isNotEmpty || hasAsset) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  ...skills.take(3).map((s) => Padding(padding: const EdgeInsets.only(right: 4), child: Text(s.replaceAll('_', ' '), style: const TextStyle(fontFamily: 'Georgia', fontSize: 9, color: OseeTheme.stone, fontStyle: FontStyle.italic)))),
                  if (hasAsset) Icon(Icons.perm_media, size: 12, color: OseeTheme.sage),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 14, color: OseeTheme.stone),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Question text
        Text(text, style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, color: OseeTheme.ink, height: 1.6)),
        // Asset (audio transcript / passage context)
        if (asset != null) ...[
          const SizedBox(height: 16),
          const _MagSectionLabel('STIMULUS'),
          if (asset['context'] != null) Text(asset['context'] as String, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5, fontStyle: FontStyle.italic)),
          if (asset['transcript'] != null) ...[
            const SizedBox(height: 8),
            Text(asset['transcript'] as String, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, height: 1.5)),
          ],
        ],
        // Options (MC)
        if (options != null && options.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _MagSectionLabel('OPTIONS'),
          for (final entry in options.entries)
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${entry.key}.', style: TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: entry.key == answer ? OseeTheme.sage : OseeTheme.ink)),
              const SizedBox(width: 8),
              Expanded(child: Text(entry.value.toString(), style: TextStyle(fontFamily: 'Georgia', fontSize: 13, color: entry.key == answer ? OseeTheme.sage : OseeTheme.ink, fontWeight: entry.key == answer ? FontWeight.w700 : FontWeight.w400, height: 1.4))),
            ])),
        ],
        // Answer
        if (answer.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _MagSectionLabel('CORRECT ANSWER'),
          Text(answer, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: OseeTheme.sage)),
        ],
        // Explanation
        if (explanation.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _MagSectionLabel('EXPLANATION'),
          Text(explanation, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5)),
        ],
        // Scoring rubric (SW questions)
        if (scoringRubric.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _MagSectionLabel('SCORING RUBRIC'),
          Text(scoringRubric, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5)),
        ],
        // Sample response
        if (sampleResponse.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _MagSectionLabel('SAMPLE RESPONSE'),
          Text(sampleResponse, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5, fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }
}

class _MagSectionLabel extends StatelessWidget {
  const _MagSectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(width: 12, height: 1, color: OseeTheme.ink),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: 'Helvetica', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2, color: OseeTheme.ink)),
      ]),
    );
  }
}