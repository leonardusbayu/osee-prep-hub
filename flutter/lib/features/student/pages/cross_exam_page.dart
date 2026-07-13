import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../shared/widgets/ui_components.dart';

/// Cross-exam score map page — Task 11.5.
class CrossExamPage extends StatefulWidget {
  const CrossExamPage({super.key});

  @override
  State<CrossExamPage> createState() => _CrossExamPageState();
}

class _CrossExamPageState extends State<CrossExamPage> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

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
      final r = await dio.get('/student/cross-exam-map');
      setState(() {
        _data = r.data as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cross-Exam Map'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : _buildContent(_data ?? {}),
    );
  }

  Widget _buildContent(Map<String, dynamic> d) {
    final equivalents = (d['equivalents'] as Map<String, dynamic>?) ?? {};
    final sourceScores = (d['source_scores'] as Map<String, dynamic>?) ?? {};

    final exams = ['TOEFL_IBT', 'TOEFL_ITP', 'IELTS', 'TOEIC'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Latest Scores',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (final exam in exams)
                  _row(
                    exam.replaceAll('_', ' '),
                    sourceScores[exam.toLowerCase()]?.toString() ?? '—',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Equivalency Matrix',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _EquivalencyTable(equivalents: equivalents, exams: exams),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Note: Scores are approximate based on ETS concordance tables. Use as a guide, not as a guarantee.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _EquivalencyTable extends StatelessWidget {
  const _EquivalencyTable({required this.equivalents, required this.exams});
  final Map<String, dynamic> equivalents;
  final List<String> exams;

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Source',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final e in exams)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  e.replaceAll('_', ' '),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        for (final sourceExam in exams)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  sourceExam.replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              for (final targetExam in exams)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _val(equivalents, targetExam, sourceExam),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  String _val(Map<String, dynamic> eq, String target, String source) {
    final row = eq[target] as Map<String, dynamic>?;
    if (row == null) return '—';
    final v = row[source];
    if (v == null) return '—';
    return v.toString();
  }
}
