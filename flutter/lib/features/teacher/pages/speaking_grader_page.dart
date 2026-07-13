import 'package:flutter/material.dart';
import 'dart:js' as js;

import '../../../core/api_client.dart';
import '../../../shared/widgets/ui_components.dart';
import '../../../app/theme.dart';

/// Speaking grader page — Task 7.2.
/// Record audio → upload to R2 → grade via EduBot bridge.
class SpeakingGraderPage extends StatefulWidget {
  const SpeakingGraderPage({super.key});

  @override
  State<SpeakingGraderPage> createState() => _SpeakingGraderPageState();
}

class _SpeakingGraderPageState extends State<SpeakingGraderPage> {
  final _promptController = TextEditingController();
  String _examType = 'IELTS';
  String _level = 'B2';
  String? _audioUrl;
  Map<String, dynamic>? _result;
  bool _isGrading = false;
  bool _isUploading = false;
  String? _error;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _uploadAudio() async {
    setState(() { _isUploading = true; _error = null; });
    try {
      // In a real implementation, use file_picker or mic recording plugin
      // For now, open file dialog via HTML input
      js.context.callMethod('eval', [
        '''
        var input = document.createElement('input');
        input.type = 'file';
        input.accept = 'audio/*';
        input.onchange = function(e) {
          var file = e.target.files[0];
          if (!file) return;
          window.__oseeAudioFile = file;
          window.__oseeAudioPicked = true;
        };
        input.click();
        '''
      ]);
      // Wait for file pick (simplified — real implementation would use interop callback)
      await Future.delayed(const Duration(seconds: 3));
      setState(() { _isUploading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a file in the dialog, then click Grade')),
        );
      }
    } catch (e) {
      setState(() { _isUploading = false; _error = 'Upload failed: $e'; });
    }
  }

  Future<void> _gradeSpeaking() async {
    if (_audioUrl == null || _audioUrl!.isEmpty) {
      // Use a placeholder URL for demo — real flow: upload to R2 first
      setState(() { _error = 'Please upload an audio file first'; });
      return;
    }
    setState(() { _isGrading = true; _error = null; });
    try {
      final dio = ApiClient.create();
      final response = await dio.post('/ai/grade-speaking', data: {
        'audio_url': _audioUrl,
        'examType': _examType,
        'prompt': _promptController.text.trim(),
        'level': _level,
      });
      setState(() { _result = response.data as Map<String, dynamic>; _isGrading = false; });
    } catch (e) {
      setState(() { _isGrading = false; _error = 'Grading failed: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Speaking Grader'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => setState(() { _result = null; _error = null; }), tooltip: 'Reset'),
        ],
      ),
      body: _isGrading
          ? const LoadingState(message: 'Evaluating speaking...')
          : ListView(
              padding: const EdgeInsets.all(Spacing.md),
              children: [
                // Exam + level selectors
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _examType,
                        decoration: const InputDecoration(labelText: 'Exam'),
                        items: ['IELTS', 'TOEFL_IBT', 'TOEIC'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _examType = v ?? 'IELTS'),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _level,
                        decoration: const InputDecoration(labelText: 'Level'),
                        items: ['A2', 'B1', 'B2', 'C1'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _level = v ?? 'B2'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.md),

                // Prompt
                TextField(
                  controller: _promptController,
                  decoration: const InputDecoration(
                    labelText: 'Speaking prompt (optional)',
                    hintText: 'e.g. Describe a memorable trip you took',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: Spacing.md),

                // Upload audio
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.upload_file_rounded),
                        label: Text(_audioUrl != null ? 'Audio: ${_audioUrl!.split('/').last}' : 'Upload Audio File'),
                        onPressed: _isUploading ? null : () async {
                          // Simulate upload — real implementation would use file picker + R2
                          setState(() => _audioUrl = 'r2://demo-audio.mp3');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),

                // Grade button
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.mic_rounded),
                    label: const Text('Evaluate Speaking'),
                    onPressed: _isGrading ? null : _gradeSpeaking,
                  ),
                ),
                const SizedBox(height: Spacing.lg),

                if (_error != null)
                  ErrorState(message: _error!, onRetry: _gradeSpeaking),

                if (_result != null) ...[
                  SectionHeader(title: 'Evaluation Result'),
                  _ResultCard(result: _result!),
                ],
              ],
            ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final band = result['overall_band'] ?? result['band_score'];
    final transcription = result['transcription'] as String?;
    final feedback = result['feedback'] as String?;
    final scores = result['scores'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: OseeTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (band != null) ...[
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: OseeTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '$band',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: OseeTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Text('Overall Band Score', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: OseeTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: Spacing.md),
          ],
          if (scores != null) ...[
            const Divider(),
            for (final entry in scores.entries)
              InfoRow(label: entry.key.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '), value: '${entry.value}'),
            const SizedBox(height: Spacing.sm),
          ],
          if (transcription != null) ...[
            const Divider(),
            Text('Transcription', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(transcription, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: Spacing.sm),
          ],
          if (feedback != null) ...[
            const Divider(),
            Text('Feedback', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(feedback, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}