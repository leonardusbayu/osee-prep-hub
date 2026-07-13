import 'package:flutter/material.dart';

import '../../../core/api_client.dart';

/// Student Progress page — Task 11.3.
class StudentProgressPage extends StatefulWidget {
  const StudentProgressPage({super.key});

  @override
  State<StudentProgressPage> createState() => _StudentProgressPageState();
}

class _StudentProgressPageState extends State<StudentProgressPage> {
  Map<String, dynamic>? _progress;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final dio = ApiClient.create();
      final r = await dio.get('/student/progress');
      setState(() {
        _progress = (r.data as Map)['progress'] as Map<String, dynamic>? ?? {};
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Progress'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(_progress ?? {}),
    );
  }

  Widget _buildContent(Map<String, dynamic> p) {
    final ibt = p['ibt_latest_score'];
    final itp = p['itp_latest_score'];
    final ielts = p['ielts_latest_band'];
    final toeic = p['toeic_latest_score'];
    final streak = p['edubot_streak_days'] ?? 0;
    final xp = p['edubot_xp'] ?? 0;
    final questions = p['edubot_questions_answered'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Exam Scores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _ScoreCard('TOEFL iBT', ibt?.toString() ?? '—', Colors.blue),
            _ScoreCard('TOEFL ITP', itp?.toString() ?? '—', Colors.teal),
            _ScoreCard('IELTS Band', ielts?.toString() ?? '—', Colors.purple),
            _ScoreCard('TOEIC', toeic?.toString() ?? '—', Colors.orange),
          ],
        ),
        const SizedBox(height: 24),
        const Text('EduBot Tutor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _statRow('🔥 Streak (days)', streak.toString()),
                _statRow('⭐ XP', xp.toString()),
                _statRow('✅ Questions answered', questions.toString()),
                _statRow('🎯 Accuracy', '${((p['edubot_accuracy_rate'] as num?) ?? 0).toStringAsFixed(1)}%'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statRow(String label, String value) {
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

class _ScoreCard extends StatelessWidget {
  const _ScoreCard(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const Spacer(),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}