import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../student_theme.dart';
import '../widgets/student_widgets.dart';

/// Syllabus item detail page — shown when a student taps "Start" on a syllabus
/// item from [StudentSyllabusPage].
///
/// Solves the "no context" gap: previously Start just launched the platform
/// homepage, leaving the student wondering which package to do. This page:
/// 1. Fetches the full syllabus item (title, description, exam_type,
///    difficulty, estimated_minutes, source_type, source_platform_url).
/// 2. Tells the student exactly WHAT to do on the destination platform
///    (derived from item_type + difficulty).
/// 3. Provides a "Go to platform" CTA that opens source_platform_url with a
///    `?osee_material_id=...` query param so the destination platform can
///    (optionally) deep-link to the exact package in the future.
///
/// Until the practice platforms support the `osee_material_id` query param,
/// the student lands on the platform dashboard with clear in-app instructions
/// on which package/section to pick.
class SyllabusItemDetailPage extends ConsumerStatefulWidget {
  const SyllabusItemDetailPage({super.key, required this.itemId});
  final String itemId;

  @override
  ConsumerState<SyllabusItemDetailPage> createState() =>
      _SyllabusItemDetailPageState();
}

class _SyllabusItemDetailPageState
    extends ConsumerState<SyllabusItemDetailPage> {
  Map<String, dynamic>? _item;
  bool _isLoading = true;
  bool _isStarting = false;
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
      final r = await dio.get('/student/syllabus/item/${widget.itemId}');
      setState(() {
        _item = r.data as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load item';
        _isLoading = false;
      });
    }
  }

  Future<void> _startAndOpen() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      final dio = ApiClient.create();
      // Mark as started on the backend (records progress).
      await dio.post('/student/syllabus/${widget.itemId}/start', data: {});
      final item = _item ?? {};
      final baseUrl = item['source_platform_url'] as String?;
      final materialId = item['source_material_id'] as String?;
      if (baseUrl == null || baseUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: StudentTheme.successGreen,
              content: Text(
                'Started! No external link — ask your teacher or open it via the Materials Hub.',
                style: StudentTheme.cardLabel(Colors.white),
              ),
            ),
          );
          context.go('/student/syllabus');
        }
        return;
      }
      // Append ?osee_material_id=... so destination platforms can deep-link
      // to the exact package when they implement the param parser.
      final deepLink = materialId == null
          ? baseUrl
          : baseUrl.contains('?')
          ? '$baseUrl&osee_material_id=$materialId'
          : '$baseUrl?osee_material_id=$materialId';
      await launchUrl(Uri.parse(deepLink));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: StudentTheme.primary,
          content: Text(
            'Opening platform — follow the instructions above.',
            style: StudentTheme.cardLabel(Colors.white),
          ),
          action: SnackBarAction(
            label: 'Re-open',
            textColor: Colors.white,
            onPressed: () => launchUrl(Uri.parse(deepLink)),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: StudentTheme.danger,
            content: Text(
              'Failed: $e',
              style: StudentTheme.cardLabel(Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _markComplete() async {
    try {
      final dio = ApiClient.create();
      await dio.post('/student/syllabus/${widget.itemId}/complete', data: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: StudentTheme.successGreen,
            content: Text(
              'Completed! ✓',
              style: StudentTheme.cardLabel(Colors.white),
            ),
          ),
        );
        context.go('/student/syllabus');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: StudentTheme.danger,
            content: Text(
              'Failed: $e',
              style: StudentTheme.cardLabel(Colors.white),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    return Scaffold(
      backgroundColor: StudentTheme.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: StudentTheme.primary,
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    style: StudentTheme.cardLabel(StudentTheme.textSecondary),
                  ),
                  const SizedBox(height: StudentSpacing.lg),
                  ElevatedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : _buildContent(isDesktop),
    );
  }

  Widget _buildContent(bool isDesktop) {
    final item = _item ?? {};
    final title = item['title'] as String? ?? 'Syllabus item';
    final description = item['description'] as String?;
    final itemType = item['item_type'] as String? ?? '';
    final difficulty = item['difficulty'] as String?;
    final minutes = item['estimated_minutes'] as int?;
    final sourceType = item['source_type'] as String? ?? '';
    final sourceUrl = item['source_platform_url'] as String?;
    final syllabusName = item['syllabus_name'] as String? ?? '';
    final classroomName = item['classroom_name'] as String? ?? '';
    final instructions = _instructionsFor(itemType, sourceType, difficulty);

    return ListView(
      padding: const EdgeInsets.all(StudentSpacing.xl),
      children: [
        StudentTopBar(
          name: 'Assignment',
          subtitle: 'Syllabus item',
          onMenuTap: isDesktop ? null : () => Scaffold.of(context).openDrawer(),
        ),
        const SizedBox(height: StudentSpacing.xxl),

        // Context card — tells the student where this item comes from.
        if (syllabusName.isNotEmpty || classroomName.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(StudentSpacing.md),
            decoration: BoxDecoration(
              color: StudentTheme.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded, color: StudentTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    [
                      if (classroomName.isNotEmpty) classroomName,
                      if (syllabusName.isNotEmpty) syllabusName,
                    ].join(' · '),
                    style: StudentTheme.cardLabel(StudentTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: StudentSpacing.lg),
        ],

        // Title card
        Container(
          padding: const EdgeInsets.all(StudentSpacing.xl),
          decoration: BoxDecoration(
            color: StudentTheme.surface,
            borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
            boxShadow: StudentTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: StudentTheme.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _typeIcon(itemType),
                      color: StudentTheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: StudentTheme.courseTitle()),
                  ),
                ],
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(description, style: StudentTheme.cardLabel()),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(_typeLabel(itemType), Icons.assignment_rounded),
                  if (difficulty != null)
                    _chip('Level $difficulty', Icons.bar_chart_rounded),
                  if (minutes != null)
                    _chip('$minutes min', Icons.timer_rounded),
                  _chip(_sourceLabel(sourceType), _sourceIcon(sourceType)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: StudentSpacing.xl),

        // Instructions card — what to do on the destination platform.
        const StudentSectionHeader(
          title: 'What to do',
          icon: Icons.checklist_rounded,
        ),
        const SizedBox(height: StudentSpacing.md),
        Container(
          padding: const EdgeInsets.all(StudentSpacing.xl),
          decoration: BoxDecoration(
            color: StudentTheme.surface,
            borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
            boxShadow: StudentTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < instructions.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: StudentTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        instructions[i],
                        style: StudentTheme.cardLabel(StudentTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
                if (i < instructions.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        const SizedBox(height: StudentSpacing.xxl),

        // Actions.
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isStarting ? null : _startAndOpen,
                icon: _isStarting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(_sourceIcon(sourceType)),
                label: Text(
                  sourceUrl == null || sourceUrl.isEmpty
                      ? 'Start (no link)'
                      : 'Go to ${_sourceLabel(sourceType)}',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: StudentTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _markComplete,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Done'),
              style: OutlinedButton.styleFrom(
                foregroundColor: StudentTheme.textSecondary,
                side: const BorderSide(color: StudentTheme.divider),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: StudentSpacing.lg),
        if (sourceUrl == null || sourceUrl.isEmpty)
          Text(
            'This item has no external platform link. Ask your teacher for instructions or open it via the Materials Hub.',
            style: StudentTheme.cardLabel(StudentTheme.textSecondary),
          ),
      ],
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: StudentTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: StudentTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: StudentTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: StudentTheme.cardLabel(StudentTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ---- Instruction generator ----
  //
  // Maps the syllabus item's type + source to concrete, actionable steps the
  // student should follow on the destination platform. This is what makes the
  // syllabus actually "structured" instead of just a list of links.
  List<String> _instructionsFor(
    String itemType,
    String sourceType,
    String? difficulty,
  ) {
    final platformName = _sourceLabel(sourceType);
    final level = difficulty == null ? '' : ' ($difficulty)';

    if (sourceType == 'edubot') {
      return [
        'Open the EduBot Tutor on Telegram$level.',
        'Start a session and tell the bot you want to practice: ${_typeLabel(itemType)}.',
        'Follow the bot prompts — it will give you exercises and instant feedback.',
        'Come back here and tap "Done" once you finish the session.',
      ];
    }

    if (sourceType == 'ai_generated') {
      return [
        'Open the material content shown below (it was AI-generated by your teacher).',
        'Read through the passage / questions carefully.',
        'Answer all questions or complete the exercises.',
        'Tap "Done" when you have finished.',
      ];
    }

    if (sourceType == 'teacher_custom') {
      return [
        'Open the link your teacher provided for this assignment.',
        'Complete the exercise / read the material as instructed.',
        'Tap "Done" when you have finished.',
      ];
    }

    // Platform items (ibt / itp / ielts / toeic).
    final taskVerb = switch (itemType) {
      'reading' => 'complete the reading passages and answer all questions',
      'listening' => 'play the audio and answer all listening questions',
      'speaking' => 'record your responses to all speaking tasks',
      'writing' => 'write your essays/responses to the writing prompts',
      'grammar' => 'complete all grammar drills',
      'vocabulary' => 'work through the vocabulary exercises',
      'mock_test' => 'complete the full mock test under timed conditions',
      'video' =>
        'watch the video lesson and complete any comprehension questions',
      'live_class' => 'join the live class on time and participate',
      _ => 'complete the assigned material',
    };

    return [
      'Log in to $platformName (you can use the same account as here).',
      'Find the ${_typeLabel(itemType)} package$level assigned by your teacher.',
      taskVerb.sentenceCase(),
      'When you finish, the platform will show your score automatically.',
      'Come back here and tap "Done" so your teacher sees your progress.',
    ];
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'reading':
        return Icons.menu_book_rounded;
      case 'listening':
        return Icons.headphones_rounded;
      case 'speaking':
        return Icons.mic_rounded;
      case 'writing':
        return Icons.edit_rounded;
      case 'grammar':
        return Icons.spellcheck_rounded;
      case 'vocabulary':
        return Icons.translate_rounded;
      case 'mock_test':
        return Icons.quiz_rounded;
      case 'video':
        return Icons.video_library_rounded;
      case 'live_class':
        return Icons.videocam_rounded;
      default:
        return Icons.assignment_rounded;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'reading':
        return 'Reading';
      case 'listening':
        return 'Listening';
      case 'speaking':
        return 'Speaking';
      case 'writing':
        return 'Writing';
      case 'grammar':
        return 'Grammar';
      case 'vocabulary':
        return 'Vocabulary';
      case 'mock_test':
        return 'Mock test';
      case 'video':
        return 'Video lesson';
      case 'live_class':
        return 'Live class';
      default:
        return 'Assignment';
    }
  }

  IconData _sourceIcon(String sourceType) {
    switch (sourceType) {
      case 'platform_ibt':
      case 'platform_itp':
      case 'platform_ielts':
      case 'platform_toeic':
        return Icons.school_rounded;
      case 'edubot':
        return Icons.smart_toy_rounded;
      case 'ai_generated':
        return Icons.auto_awesome_rounded;
      case 'teacher_custom':
        return Icons.upload_file_rounded;
      case 'video_lesson':
        return Icons.video_library_rounded;
      case 'live_class':
        return Icons.event_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  String _sourceLabel(String sourceType) {
    switch (sourceType) {
      case 'platform_ibt':
        return 'OSEE iBT';
      case 'platform_itp':
        return 'OSEE ITP';
      case 'platform_ielts':
        return 'OSEE IELTS';
      case 'platform_toeic':
        return 'OSEE TOEIC';
      case 'edubot':
        return 'EduBot';
      case 'ai_generated':
        return 'AI-generated';
      case 'teacher_custom':
        return 'Custom';
      case 'video_lesson':
        return 'Video';
      case 'live_class':
        return 'Live class';
      default:
        return 'Platform';
    }
  }
}

/// Tiny extension to capitalize the first letter of a sentence (used to format
/// generated instruction strings nicely).
extension on String {
  String sentenceCase() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
