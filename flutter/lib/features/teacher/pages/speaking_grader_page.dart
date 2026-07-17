import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../shared/widgets/ui_components.dart';
import '../../../app/theme.dart';

/// Speaking grader page — Task 7.2.
/// Pick an audio file → upload to R2 via POST /api/upload/audio → grade via
/// POST /api/ai/grade-speaking (which bridges to EduBot's Whisper+GPT evaluator).
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
  String? _audioName;
  Map<String, dynamic>? _result;
  bool _isGrading = false;
  bool _isUploading = false;
  String? _error;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  /// Opens the browser file picker, uploads the chosen file to R2, and stores
  /// the resulting public URL in [_audioUrl] so the grade button can submit
  /// it to /api/ai/grade-speaking.
  Future<void> _pickAndUploadAudio() async {
    setState(() {
      _isUploading = true;
      _error = null;
      _audioUrl = null;
      _audioName = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        setState(() {
          _isUploading = false;
          _error = 'No file selected';
        });
        return;
      }

      final picked = result.files.first;
      final name = picked.name;
      final bytes = picked.bytes;
      if (bytes == null) {
        setState(() {
          _isUploading = false;
          _error = 'Failed to read file bytes';
        });
        return;
      }

      // Sniff content type from extension (file_picker doesn't always
      // populate the MIME type on web; use a simple extension map).
      final ext = name.split('.').last.toLowerCase();
      const extToType = <String, String>{
        'mp3': 'audio/mp3',
        'wav': 'audio/wav',
        'ogg': 'audio/ogg',
        'm4a': 'audio/m4a',
        'webm': 'audio/webm',
      };
      final contentType = extToType[ext] ?? 'audio/webm';

      final dio = ApiClient.create();
      final uploadRes = await dio.post(
        '/upload/audio',
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': bytes.length,
          },
        ),
      );

      final uploadData = uploadRes.data as Map<String, dynamic>;
      final url = uploadData['url'] as String?;
      if (url == null) {
        throw StateError('Upload response missing url');
      }

      setState(() {
        _audioUrl = url;
        _audioName = name;
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Upload failed: $e';
      });
    }
  }

  Future<void> _gradeSpeaking() async {
    final url = _audioUrl;
    if (url == null || url.isEmpty) {
      setState(() => _error = 'Please upload an audio file first');
      return;
    }
    setState(() {
      _isGrading = true;
      _error = null;
    });
    try {
      final dio = ApiClient.create();
      final response = await dio.post(
        '/ai/grade-speaking',
        data: {
          'audio_url': url,
          'examType': _examType,
          'prompt': _promptController.text.trim(),
          'level': _level,
        },
      );
      setState(() {
        _result = response.data as Map<String, dynamic>;
        _isGrading = false;
      });
    } catch (e) {
      setState(() {
        _isGrading = false;
        _error = 'Grading failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isGrading
        ? const LoadingState(message: 'Evaluating speaking...')
        : ListView(
            padding: const EdgeInsets.all(Spacing.md),
            children: [
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Reset',
                    onPressed: () => setState(() {
                      _result = null;
                      _error = null;
                    }),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _examType,
                      decoration: const InputDecoration(labelText: 'Exam'),
                      items: ['IELTS', 'TOEFL_IBT', 'TOEIC']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _examType = v ?? 'IELTS'),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _level,
                      decoration: const InputDecoration(labelText: 'Level'),
                      items: ['A2', 'B1', 'B2', 'C1']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _level = v ?? 'B2'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),

              TextField(
                controller: _promptController,
                decoration: const InputDecoration(
                  labelText: 'Speaking prompt (optional)',
                  hintText: 'e.g. Describe a memorable trip you took',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: Spacing.md),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_rounded),
                      label: Text(
                        _audioName != null
                            ? 'Audio: $_audioName'
                            : 'Upload Audio File',
                      ),
                      onPressed: _isUploading ? null : _pickAndUploadAudio,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.lg),

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
                const SectionHeader(title: 'Evaluation Result'),
                _ResultCard(result: _result!),
              ],
            ],
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: OseeTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '$band',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: OseeTheme.primary,
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Text(
                  'Overall Band Score',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OseeTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
          ],
          if (scores != null) ...[
            const Divider(),
            for (final entry in scores.entries)
              InfoRow(
                label: entry.key
                    .replaceAll('_', ' ')
                    .split(' ')
                    .map((w) => w[0].toUpperCase() + w.substring(1))
                    .join(' '),
                value: '${entry.value}',
              ),
            const SizedBox(height: Spacing.sm),
          ],
          if (transcription != null) ...[
            const Divider(),
            Text(
              'Transcription',
              style: Theme.of(context).textTheme.titleSmall,
            ),
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
