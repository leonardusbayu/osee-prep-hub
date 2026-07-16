import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../shared/widgets/ui_components.dart';

/// AI Writing Grader page — Task 5.3.
///
/// Form to paste essay, select rubric, submit to /api/ai/grade-writing.
/// Shows queue status (pending/processing/completed), then displays result.
class AiGraderPage extends ConsumerStatefulWidget {
  const AiGraderPage({super.key});

  @override
  ConsumerState<AiGraderPage> createState() => _AiGraderPageState();
}

class _AiGraderPageState extends ConsumerState<AiGraderPage> {
  final _formKey = GlobalKey<FormState>();
  final _essayController = TextEditingController();
  String _rubric = 'ielts_task2';
  String _examType = 'IELTS';
  String _level = 'B2';
  String? _status;
  Map<String, dynamic>? _result;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _essayController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _status = 'submitting';
    });
    try {
      final dio = ApiClient.create();
      final response = await dio.post(
        '/ai/grade-writing',
        data: {
          'essay': _essayController.text,
          'rubric': _rubric,
          'examType': _examType,
          'level': _level,
        },
      );
      final result = response.data['result'] as Map<String, dynamic>?;
      final status = response.data['status'] as String? ?? 'completed';
      setState(() {
        _result = result;
        _status = status;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _status = 'error';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageHeader(
                title: 'AI Writing Grader',
                subtitle:
                    'Evaluate essays with rubric-aware feedback and classroom-ready suggestions.',
                icon: Icons.edit_note_rounded,
              ),
              const SizedBox(height: Spacing.lg),
              // Essay input
              SurfaceCard(
                padding: const EdgeInsets.all(Spacing.lg),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _essayController,
                      decoration: const InputDecoration(
                        labelText: 'Essay to grade',
                        hintText:
                            'Paste the student response here. 250+ words recommended.',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 12,
                      minLines: 8,
                      validator: (v) => (v == null || v.trim().length < 50)
                          ? 'Essay too short'
                          : null,
                    ),
                    const SizedBox(height: Spacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stack = constraints.maxWidth < 640;
                        final fields = [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _rubric,
                              decoration: const InputDecoration(
                                labelText: 'Rubric',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'ielts_task1',
                                  child: Text('IELTS Task 1'),
                                ),
                                DropdownMenuItem(
                                  value: 'ielts_task2',
                                  child: Text('IELTS Task 2'),
                                ),
                                DropdownMenuItem(
                                  value: 'toefl_ibt',
                                  child: Text('TOEFL iBT'),
                                ),
                                DropdownMenuItem(
                                  value: 'toefl_itp',
                                  child: Text('TOEFL ITP'),
                                ),
                                DropdownMenuItem(
                                  value: 'toeic',
                                  child: Text('TOEIC'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _rubric = v ?? 'ielts_task2'),
                            ),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _examType,
                              decoration: const InputDecoration(
                                labelText: 'Exam',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'IELTS',
                                  child: Text('IELTS'),
                                ),
                                DropdownMenuItem(
                                  value: 'TOEFL_IBT',
                                  child: Text('TOEFL iBT'),
                                ),
                                DropdownMenuItem(
                                  value: 'TOEFL_ITP',
                                  child: Text('TOEFL ITP'),
                                ),
                                DropdownMenuItem(
                                  value: 'TOEIC',
                                  child: Text('TOEIC'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _examType = v ?? 'IELTS'),
                            ),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _level,
                              decoration: const InputDecoration(
                                labelText: 'Target level',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'A2',
                                  child: Text('A2'),
                                ),
                                DropdownMenuItem(
                                  value: 'B1',
                                  child: Text('B1'),
                                ),
                                DropdownMenuItem(
                                  value: 'B2',
                                  child: Text('B2'),
                                ),
                                DropdownMenuItem(
                                  value: 'C1',
                                  child: Text('C1'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _level = v ?? 'B2'),
                            ),
                          ),
                        ];

                        if (stack) {
                          return Column(
                            children: [
                              fields[0],
                              const SizedBox(height: Spacing.sm),
                              fields[1],
                              const SizedBox(height: Spacing.sm),
                              fields[2],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            fields[0],
                            const SizedBox(width: Spacing.sm),
                            fields[1],
                            const SizedBox(width: Spacing.sm),
                            fields[2],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: Spacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: Text(
                          _isSubmitting ? 'Grading...' : 'Grade Essay',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_status != null) ...[
                const SizedBox(height: Spacing.lg),
                _buildStatus(),
              ],
            ],
          ),
        ),
      );
  }

  Widget _buildStatus() {
    final status = _status ?? '';
    final isComplete = status == 'completed' && _result != null;
    return SurfaceCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isComplete
                      ? Icons.check_circle
                      : (status == 'error'
                            ? Icons.error_outline
                            : Icons.hourglass_empty),
                  color: isComplete
                      ? Colors.green
                      : (status == 'error' ? Colors.red : Colors.orange),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  isComplete
                      ? 'Graded: ${_result!['band']} (${_result!['score']})'
                      : 'Status: $status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (isComplete) ...[
              const SizedBox(height: Spacing.md),
              Text(
                _result!['feedback'] as String? ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.md),
              Text(
                'Criteria Breakdown',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ...((_result!['criteria_scores'] as List?)?.map(
                    (c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c['criterion'] as String? ?? ''),
                      subtitle: Text(c['feedback'] as String? ?? ''),
                      trailing: Text('${c['score']}/${c['max_score']}'),
                    ),
                  ) ??
                  []),
              const SizedBox(height: Spacing.md),
              Text(
                'Improvements',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              ...((_result!['improvements'] as List?)?.map(
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '• $i',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ) ??
                  []),
            ],
          ],
        ),
      ),
    );
  }
}
