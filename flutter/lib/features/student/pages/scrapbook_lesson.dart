import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Scrapbook-style lesson reader — magazine mood board aesthetic.
///
/// Each section of the lesson (theory, examples, exercises, vocabulary,
/// practice) is rendered as a distinct scrapbook element:
///  - Theory: handwritten letter on aged paper, tied with twine
///  - Examples: Polaroid-style cards, slightly tilted, with washi tape
///  - Exercises: magazine clippings on parchment, with red stamp accents
///  - Vocabulary: fabric swatch cards with handwritten labels
///  - Practice: a coffee-ring stained note with fountain pen scribble
///
/// The whole page sits on an antique parchment background with deckled
/// edges, coffee stains, and scattered decorative elements.
class ScrapbookLesson extends StatelessWidget {
  const ScrapbookLesson({
    super.key,
    required this.title,
    required this.summary,
    required this.theory,
    required this.keyPoints,
    required this.examples,
    required this.exercises,
    required this.vocabulary,
    required this.practicePrompt,
    required this.sourceLabel,
    required this.difficulty,
    required this.minutes,
    required this.onDone,
    required this.isDone,
    required this.onDeepLink,
    required this.deepLinkLabel,
    this.onPrev,
    this.onNext,
  });

  final String title;
  final String? summary;
  final String theory;
  final List<String> keyPoints;
  final List<Map<String, dynamic>> examples;
  final List<Map<String, dynamic>> exercises;
  final List<Map<String, dynamic>> vocabulary;
  final String? practicePrompt;
  final String sourceLabel;
  final String? difficulty;
  final int? minutes;
  final VoidCallback onDone;
  final bool isDone;
  final VoidCallback? onDeepLink;
  final String? deepLinkLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OseeTheme.parchment,
      child: Stack(
        children: [
          // Parchment texture background
          Positioned.fill(child: _ParchmentTexture()),

          // Main content
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 60),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMasthead(),
                    const SizedBox(height: 32),
                    if (summary != null && summary!.isNotEmpty) ...[
                      _HandwrittenNote(text: summary!, fontSize: 15),
                      const SizedBox(height: 24),
                    ],
                    if (theory.isNotEmpty) ...[
                      _TheoryLetter(theory: theory, keyPoints: keyPoints),
                      const SizedBox(height: 28),
                    ],
                    if (examples.isNotEmpty) ...[
                      _SectionHeader(text: 'some of my favorites...', tilted: true),
                      const SizedBox(height: 12),
                      _PolaroidGrid(items: examples),
                      const SizedBox(height: 28),
                    ],
                    if (exercises.isNotEmpty) ...[
                      _SectionHeader(text: 'try these out', tilted: false),
                      const SizedBox(height: 12),
                      _ExerciseClippings(exercises: exercises),
                      const SizedBox(height: 28),
                    ],
                    if (vocabulary.isNotEmpty) ...[
                      _SectionHeader(text: 'word swatches', tilted: true),
                      const SizedBox(height: 12),
                      _VocabSwatches(vocabulary: vocabulary),
                      const SizedBox(height: 28),
                    ],
                    if (practicePrompt != null && practicePrompt!.isNotEmpty) ...[
                      _CoffeeRingNote(text: practicePrompt!),
                      const SizedBox(height: 28),
                    ],
                    if (onDeepLink != null && deepLinkLabel != null) ...[
                      _TapedButton(label: deepLinkLabel!, onTap: onDeepLink!),
                      const SizedBox(height: 20),
                    ],
                    _DoneStamp(isDone: isDone, onTap: onDone),
                    const SizedBox(height: 28),
                    // Prev/Next chapter navigation
                    if (onPrev != null || onNext != null) ...[
                      Row(
                        children: [
                          if (onPrev != null)
                            Expanded(
                              child: InkWell(
                                onTap: onPrev,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: OseeTheme.cloud)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.chevron_left, size: 16, color: OseeTheme.ink),
                                      const SizedBox(width: 6),
                                      Text('PREVIOUS', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: OseeTheme.ink)),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else const Spacer(),
                          const SizedBox(width: 10),
                          if (onNext != null)
                            Expanded(
                              child: InkWell(
                                onTap: onNext,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(color: OseeTheme.ink),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text('NEXT CHAPTER', style: const TextStyle(fontFamily: 'Helvetica', fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white)),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.chevron_right, size: 16, color: Colors.white),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                    _FountainPen(),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Masthead ----

  Widget _buildMasthead() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source label badge
        Row(
          children: [
            Transform.rotate(
              angle: -0.04,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: OseeTheme.redStamp,
                  border: Border.all(color: OseeTheme.redStamp, width: 1),
                ),
                child: Text(
                  sourceLabel.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (difficulty != null) ...[
              const SizedBox(width: 8),
              Text(
                difficulty!.toUpperCase(),
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, fontWeight: FontWeight.w700, color: OseeTheme.gold, letterSpacing: 1.5),
              ),
            ],
            if (minutes != null) ...[
              const Text('  ·  ', style: TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.stone)),
              Text('$minutes min', style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, color: OseeTheme.stone)),
            ],
          ],
        ),
        const SizedBox(height: 16),
        // Big handwritten title
        _HandwrittenTitle(text: title),
        const SizedBox(height: 8),
        // Gold rule (like a deckled edge)
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: OseeTheme.gold,
            borderRadius: BorderRadius.circular(1),
            boxShadow: [BoxShadow(color: OseeTheme.gold.withValues(alpha: 0.3), blurRadius: 4, spreadRadius: 1)],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Parchment texture — aged paper background with stains
// ============================================================

class _ParchmentTexture extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParchmentPainter(),
      size: Size.infinite,
    );
  }
}

class _ParchmentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base parchment color
    final paint = Paint()..color = OseeTheme.parchment;
    canvas.drawRect(Offset.zero & size, paint);

    // Coffee ring stain (top-right area)
    final ringPaint = Paint()
      ..color = OseeTheme.coffeeRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.12), 40, ringPaint);
    // Inner ring
    final innerRing = Paint()
      ..color = OseeTheme.coffeeRing.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.12), 28, innerRing);

    // Scattered ink spots
    final spotPaint = Paint()..color = OseeTheme.inkBleed;
    canvas.drawCircle(Offset(size.width * 0.1, size.height * 0.05), 3, spotPaint);
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.5), 2, spotPaint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.9), 2, spotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// Handwritten title — large brush-script style
// ============================================================

class _HandwrittenTitle extends StatelessWidget {
  const _HandwrittenTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.015,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: OseeTheme.ink,
          height: 1.1,
          letterSpacing: -0.5,
          shadows: [
            Shadow(color: Color(0x331A1A2E), offset: Offset(1, 2), blurRadius: 2),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Handwritten note — cursive-style text
// ============================================================

class _HandwrittenNote extends StatelessWidget {
  const _HandwrittenNote({required this.text, this.fontSize = 13});
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Transform.rotate(
        angle: -0.005,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontStyle: FontStyle.italic,
            fontSize: fontSize,
            color: OseeTheme.stone,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Section header — handwritten cursive
// ============================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text, required this.tilted});
  final String text;
  final bool tilted;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilted ? -0.02 : 0,
      child: Row(
        children: [
          Container(
            width: 20,
            height: 1,
            color: OseeTheme.ink,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: OseeTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Theory letter — aged paper, tied with twine, ink-bleed shadows
// ============================================================

class _TheoryLetter extends StatelessWidget {
  const _TheoryLetter({required this.theory, required this.keyPoints});
  final String theory;
  final List<String> keyPoints;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.008,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        decoration: BoxDecoration(
          color: OseeTheme.clippingYellow.withValues(alpha: 0.6),
          border: Border.all(color: OseeTheme.parchmentDark, width: 1),
          boxShadow: [
            BoxShadow(color: OseeTheme.inkBleed, blurRadius: 6, offset: const Offset(3, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "Dear Student," opener
            const Text(
              'Dear Student,',
              style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 16, color: OseeTheme.ink, height: 1.4),
            ),
            const SizedBox(height: 12),
            // Theory text
            Text(
              theory.replaceAll('\\n', '\n'),
              style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, color: OseeTheme.ink, height: 1.7),
            ),
            const SizedBox(height: 16),
            // Key points as bullet list
            if (keyPoints.isNotEmpty) ...[
              const Text(
                'Remember these:',
                style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 13, color: OseeTheme.stone),
              ),
              const SizedBox(height: 8),
              for (final p in keyPoints)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: const BoxDecoration(color: OseeTheme.accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(p, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink, height: 1.5))),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            // Signature
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                '— Your Teacher',
                style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 14, color: OseeTheme.stone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Polaroid grid — tilted photo cards with washi tape and captions
// ============================================================

class _PolaroidGrid extends StatelessWidget {
  const _PolaroidGrid({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 24,
      children: [
        for (var i = 0; i < items.length; i++)
          _PolaroidCard(
            example: items[i],
            index: i,
            rotation: (i % 2 == 0 ? -1 : 1) * (0.02 + (i % 3) * 0.01),
          ),
      ],
    );
  }
}

class _PolaroidCard extends StatelessWidget {
  const _PolaroidCard({required this.example, required this.index, required this.rotation});
  final Map<String, dynamic> example;
  final int index;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    final input = example['input'] as String? ?? '';
    final output = example['output'] as String? ?? '';
    final explanation = example['explanation'] as String? ?? '';
    final tapeColor = index % 3 == 0 ? OseeTheme.tape : (index % 3 == 1 ? OseeTheme.tapePink : OseeTheme.tape);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 400 ? screenWidth * 0.85 : 280.0;

    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: OseeTheme.polaroidWhite,
          boxShadow: [
            BoxShadow(color: OseeTheme.inkBleed, blurRadius: 8, offset: const Offset(4, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Washi tape at top
            Align(
              alignment: Alignment.topCenter,
              child: Transform.rotate(
                angle: -rotation * 0.5,
                child: Container(
                  width: 80,
                  height: 24,
                  margin: const EdgeInsets.only(top: -8),
                  decoration: BoxDecoration(
                    color: tapeColor,
                    border: Border.all(color: tapeColor.withValues(alpha: 0.5), width: 1),
                  ),
                ),
              ),
            ),
            // "Photo" area — the example input in italic
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E6E1),
                  border: Border.all(color: OseeTheme.parchmentDark, width: 0.5),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      input,
                      style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 13, color: OseeTheme.ink, height: 1.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            // Caption area — the output
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '→ $output',
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: OseeTheme.sage, height: 1.3),
                  ),
                  if (explanation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      explanation,
                      style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.stone, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Exercise clippings — magazine clipping style with red stamp
// ============================================================

class _ExerciseClippings extends StatelessWidget {
  const _ExerciseClippings({required this.exercises});
  final List<Map<String, dynamic>> exercises;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < exercises.length; i++)
          _ExerciseClipping(
            exercise: exercises[i],
            index: i + 1,
            rotation: (i % 2 == 0 ? -1 : 1) * 0.012,
          ),
      ],
    );
  }
}

class _ExerciseClipping extends StatefulWidget {
  const _ExerciseClipping({required this.exercise, required this.index, required this.rotation});
  final Map<String, dynamic> exercise;
  final int index;
  final double rotation;

  @override
  State<_ExerciseClipping> createState() => _ExerciseClippingState();
}

class _ExerciseClippingState extends State<_ExerciseClipping> {
  String? _selected;
  bool _showAnswer = false;

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final type = ex['type'] as String? ?? 'short_answer';
    final question = ex['question'] as String? ?? '';
    final options = (ex['options'] as List?)?.cast<String>();
    final answer = ex['answer'] as String? ?? '';
    final explanation = ex['explanation'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Transform.rotate(
        angle: widget.rotation,
        child: Container(
          decoration: BoxDecoration(
            color: OseeTheme.polaroidWhite,
            border: Border.all(color: OseeTheme.parchmentDark, width: 0.5),
            boxShadow: [
              BoxShadow(color: OseeTheme.inkBleed, blurRadius: 4, offset: const Offset(2, 3)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Number stamp + type
                Row(
                  children: [
                    Transform.rotate(
                      angle: -0.08,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: OseeTheme.redStamp,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Center(
                          child: Text(
                            '${widget.index}',
                            style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      type.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, fontWeight: FontWeight.w700, color: OseeTheme.stone, letterSpacing: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Question
                Text(
                  question,
                  style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, color: OseeTheme.ink, height: 1.4),
                ),
                // Options
                if (options != null && options.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (var i = 0; i < options.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _selected = options[i]),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selected == options[i] ? OseeTheme.accent.withValues(alpha: 0.1) : Colors.transparent,
                          border: Border.all(color: _selected == options[i] ? OseeTheme.accent : OseeTheme.cloud, width: 1),
                        ),
                        child: Row(
                          children: [
                            Text(String.fromCharCode(65 + i), style: const TextStyle(fontFamily: 'Georgia', fontSize: 11, fontWeight: FontWeight.w700, color: OseeTheme.ink)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(options[i], style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, color: OseeTheme.ink))),
                          ],
                        ),
                      ),
                    ),
                ],
                // Answer reveal
                if (_showAnswer) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: OseeTheme.sage.withValues(alpha: 0.08),
                      border: Border(left: BorderSide(color: OseeTheme.sage, width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: OseeTheme.sage),
                            const SizedBox(width: 6),
                            Expanded(child: Text(answer, style: const TextStyle(fontFamily: 'Georgia', fontSize: 13, fontWeight: FontWeight.w700, color: OseeTheme.sage))),
                          ],
                        ),
                        if (explanation.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(explanation, style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.stone, height: 1.3)),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => setState(() => _showAnswer = !_showAnswer),
                  child: Text(
                    _showAnswer ? 'hide answer' : 'show answer',
                    style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 12, color: OseeTheme.sage),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Vocabulary swatches — fabric swatch cards with handwritten labels
// ============================================================

class _VocabSwatches extends StatelessWidget {
  const _VocabSwatches({required this.vocabulary});
  final List<Map<String, dynamic>> vocabulary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 16,
      children: [
        for (var i = 0; i < vocabulary.length; i++)
          _VocabSwatch(
            word: vocabulary[i]['word'] as String? ?? '',
            definition: vocabulary[i]['definition'] as String? ?? '',
            example: vocabulary[i]['example'] as String? ?? '',
            index: i,
          ),
      ],
    );
  }
}

class _VocabSwatch extends StatelessWidget {
  const _VocabSwatch({required this.word, required this.definition, required this.example, required this.index});
  final String word;
  final String definition;
  final String example;
  final int index;

  // Alternate swatch "colors" (like fabric swatches)
  static const _swatchColors = [
    Color(0xFF4F8DE0),
    Color(0xFFE5913D),
    Color(0xFF5BA674),
    Color(0xFFA66BD6),
    Color(0xFFD65F5F),
    Color(0xFFE0B04F),
    Color(0xFF4FA6A0),
    Color(0xFF7A6BD6),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _swatchColors[index % _swatchColors.length];
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth < 400 ? screenWidth * 0.42 : 200.0;
    return Transform.rotate(
      angle: (index % 2 == 0 ? -1 : 1) * 0.02,
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: OseeTheme.polaroidWhite,
          boxShadow: [BoxShadow(color: OseeTheme.inkBleed, blurRadius: 4, offset: const Offset(2, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Swatch color block
            Container(
              height: 48,
              width: double.infinity,
              color: color.withValues(alpha: 0.15),
              child: Center(
                child: Text(
                  word,
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ),
            // Definition + example
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(definition, style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: OseeTheme.ink, height: 1.4)),
                  if (example.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '"$example"',
                      style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11, color: OseeTheme.stone, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Coffee ring note — practice prompt with coffee stain overlay
// ============================================================

class _CoffeeRingNote extends StatelessWidget {
  const _CoffeeRingNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.01,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: OseeTheme.polaroidWhite,
              border: Border.all(color: OseeTheme.parchmentDark, width: 1),
              boxShadow: [BoxShadow(color: OseeTheme.inkBleed, blurRadius: 6, offset: const Offset(3, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit, size: 18, color: OseeTheme.accent),
                    const SizedBox(width: 8),
                    Text(
                      'try this:',
                      style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 18, color: OseeTheme.ink),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  text,
                  style: const TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 14, color: OseeTheme.ink, height: 1.6),
                ),
              ],
            ),
          ),
          // Coffee ring overlay
          Positioned(
            top: -10,
            right: 10,
            child: CustomPaint(
              size: const Size(80, 80),
              painter: _CoffeeRingPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoffeeRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ringPaint = Paint()
      ..color = OseeTheme.coffeeRing
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - 6, ringPaint);
    final innerPaint = Paint()
      ..color = OseeTheme.coffeeRing.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - 16, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// Taped button — deep link button with washi tape on top
// ============================================================

class _TapedButton extends StatelessWidget {
  const _TapedButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.01,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: OseeTheme.ink,
            boxShadow: [BoxShadow(color: OseeTheme.inkBleed, blurRadius: 6, offset: const Offset(3, 4))],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.open_in_new, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Washi tape on top-left corner
              Positioned(
                top: -6,
                left: 20,
                child: Transform.rotate(
                  angle: 0.15,
                  child: Container(
                    width: 60,
                    height: 18,
                    color: OseeTheme.tape,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Done stamp — rubber stamp style
// ============================================================

class _DoneStamp extends StatelessWidget {
  const _DoneStamp({required this.isDone, required this.onTap});
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Transform.rotate(
          angle: isDone ? -0.08 : 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDone ? OseeTheme.sage : OseeTheme.accent,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isDone ? 'DONE ✓' : 'MARK AS DONE',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: isDone ? OseeTheme.sage : OseeTheme.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Fountain pen — decorative element at the bottom
// ============================================================

class _FountainPen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.15,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 120,
            height: 6,
            decoration: BoxDecoration(
              color: OseeTheme.ink,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(3), right: Radius.circular(1)),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: OseeTheme.gold,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}