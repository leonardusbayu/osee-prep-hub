import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../models/syllabus.dart';
import '../providers/syllabus_repository.dart';

/// Magazine-styled syllabus library. Editorial header with kicker + drop-cap
/// intro, asymmetric stats, magazine-cover cards with rotated numbers.
class SyllabusListPage extends ConsumerWidget {
  const SyllabusListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSyllabi = ref.watch(syllabiListProvider);

    return Scaffold(
      backgroundColor: OseeTheme.paper,
      appBar: AppBar(
        backgroundColor: OseeTheme.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: OseeTheme.ink),
          onPressed: () => context.go('/teacher'),
          tooltip: 'Back to dashboard',
        ),
        title: const Text(''),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: OseeTheme.ink),
            onPressed: () => ref.invalidate(syllabiListProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: asyncSyllabi.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: 'Failed to load syllabi: $e',
          onRetry: () => ref.invalidate(syllabiListProvider),
        ),
        data: (syllabi) => _MagazineBody(
          syllabi: syllabi,
          onCreate: () => _showCreateDialog(context, ref),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: OseeTheme.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: OseeTheme.gold, width: 1.5),
        ),
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add, size: 18),
        label: const Text(
          'NEW SYLLABUS',
          style: TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_CreateSyllabusResult>(
      context: context,
      builder: (_) => const _CreateSyllabusDialog(),
    );
    if (result == null) return;
    try {
      final repo = ref.read(syllabusRepositoryProvider);
      final created = await repo.createSyllabus(
        name: result.name,
        description: result.description,
        targetExam: result.targetExam,
      );
      ref.invalidate(syllabiListProvider);
      if (!context.mounted) return;
      context.go('/teacher/syllabi/${created.id}');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create failed: $e'), backgroundColor: OseeTheme.accent),
      );
    }
  }
}

// ---------------- magazine body ----------------

class _MagazineBody extends StatelessWidget {
  const _MagazineBody({required this.syllabi, required this.onCreate});
  final List<Syllabus> syllabi;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(40, 16, 40, 80),
      children: [
        _MagazineMasthead(),
        const SizedBox(height: 32),
        _MagazineIntro(syllabusCount: syllabi.length),
        const SizedBox(height: 28),
        if (syllabi.isNotEmpty) ...[
          _MagazineStatsRow(syllabi: syllabi),
          const SizedBox(height: 32),
        ],
        const _SectionRule(label: 'THE COLLECTION'),
        const SizedBox(height: 16),
        if (syllabi.isEmpty)
          _MagazineEmptyState(onCreate: onCreate)
        else
          ...syllabi.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _MagazineSyllabusCard(syllabus: e.value, index: e.key + 1),
                ),
              ),
      ],
    );
  }
}

class _MagazineMasthead extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: OseeTheme.accent,
              child: const Text(
                'ISSUE 01',
                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'TEACHER PORTAL · SYLLABI',
              style: TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: OseeTheme.stone,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Your',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 64,
                fontWeight: FontWeight.w700,
                color: OseeTheme.ink,
                height: 0.95,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Syllabi',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 64,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: OseeTheme.accent,
                height: 0.95,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(height: 2, color: OseeTheme.gold),
      ],
    );
  }
}

class _MagazineIntro extends StatelessWidget {
  const _MagazineIntro({required this.syllabusCount});
  final int syllabusCount;

  @override
  Widget build(BuildContext context) {
    final intro = syllabusCount == 0
        ? 'reate your first syllabus and arrange material into weekly units. Drag, drop, reorder — the canvas is yours.'
        : 'ou have $syllabusCount syllabus${syllabusCount == 1 ? '' : 'i'} in your library. Open one to drag material into weekly units, or start a new one for your next course.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          intro[0].toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 64,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: OseeTheme.accent,
            height: 0.8,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              intro.substring(1),
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 15,
                color: OseeTheme.ink,
                height: 1.55,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MagazineStatsRow extends StatelessWidget {
  const _MagazineStatsRow({required this.syllabi});
  final List<Syllabus> syllabi;

  @override
  Widget build(BuildContext context) {
    final total = syllabi.length;
    final published = syllabi.where((s) => s.isPublished).length;
    final templates = syllabi.where((s) => s.isTemplate).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MagazineStat(
          value: '$total',
          label: 'TOTAL',
          big: true,
          offset: const Offset(0, -4),
        ),
        const SizedBox(width: 32),
        Transform.rotate(
          angle: -0.017,
          child: _MagazineStat(
            value: '$published',
            label: 'PUBLISHED',
            accent: OseeTheme.sage,
          ),
        ),
        const SizedBox(width: 32),
        _MagazineStat(
          value: '$templates',
          label: 'TEMPLATES',
          accent: OseeTheme.gold,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class _MagazineStat extends StatelessWidget {
  const _MagazineStat({
    required this.value,
    required this.label,
    this.big = false,
    this.accent,
    this.offset = Offset.zero,
  });
  final String value;
  final String label;
  final bool big;
  final Color? accent;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final a = accent ?? OseeTheme.ink;
    return Transform.translate(
      offset: offset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: big ? 44 : 36,
              fontWeight: FontWeight.w700,
              color: a,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: OseeTheme.stone,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionRule extends StatelessWidget {
  const _SectionRule({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: OseeTheme.ink,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: OseeTheme.ink, thickness: 1, height: 1)),
      ],
    );
  }
}

class _MagazineEmptyState extends StatelessWidget {
  const _MagazineEmptyState({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: OseeTheme.cloud),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'A',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 96,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                  color: OseeTheme.accent,
                  height: 0.9,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'blank canvas.',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 28,
                        fontStyle: FontStyle.italic,
                        color: OseeTheme.ink,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your first syllabus starts with a single week and a single item. Build from there.',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 14,
                        color: OseeTheme.stone,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onCreate,
              style: OutlinedButton.styleFrom(
                foregroundColor: OseeTheme.ink,
                side: const BorderSide(color: OseeTheme.ink, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'CREATE YOUR FIRST',
                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MagazineSyllabusCard extends StatelessWidget {
  const _MagazineSyllabusCard({required this.syllabus, required this.index});
  final Syllabus syllabus;
  final int index;

  static const _examNames = {
    'TOEFL_IBT': 'TOEFL iBT',
    'TOEFL_ITP': 'TOEFL ITP',
    'IELTS': 'IELTS',
    'TOEIC': 'TOEIC',
    'GENERAL': 'General English',
  };

  @override
  Widget build(BuildContext context) {
    final examLabel = syllabus.targetExam != null
        ? (_examNames[syllabus.targetExam] ?? syllabus.targetExam!)
        : 'Any exam';
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => context.go('/teacher/syllabi/${syllabus.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: const BorderSide(color: OseeTheme.ink, width: 4),
              bottom: BorderSide(color: OseeTheme.cloud, width: 1),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Transform.rotate(
                angle: -0.05,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    border: Border.all(color: OseeTheme.ink, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '${index < 10 ? '0' : ''}$index',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: OseeTheme.ink,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          color: OseeTheme.gold,
                          child: Text(
                            examLabel.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (syllabus.isPublished)
                          const Text(
                            'PUBLISHED',
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: OseeTheme.sage,
                              letterSpacing: 1.5,
                            ),
                          ),
                        if (syllabus.isTemplate) ...[
                          const SizedBox(width: 8),
                          const Text(
                            'TEMPLATE',
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: OseeTheme.stone,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      syllabus.name,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: OseeTheme.ink,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(height: 0.5, color: OseeTheme.gold),
                    const SizedBox(height: 8),
                    if (syllabus.description != null && syllabus.description!.isNotEmpty) ...[
                      Text(
                        syllabus.description!,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 12,
                          color: OseeTheme.stone,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Created ${syllabus.createdAt.day} ${_monthName(syllabus.createdAt.month)} ${syllabus.createdAt.year}',
                      style: const TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 9,
                        color: OseeTheme.stone,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: OseeTheme.ink, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (m >= 1 && m <= 12) return names[m - 1];
    return '';
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: OseeTheme.accent),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _CreateSyllabusResult {
  final String name;
  final String? description;
  final String? targetExam;
  _CreateSyllabusResult(this.name, this.description, this.targetExam);
}

class _CreateSyllabusDialog extends StatefulWidget {
  const _CreateSyllabusDialog();
  @override
  State<_CreateSyllabusDialog> createState() => _CreateSyllabusDialogState();
}

class _CreateSyllabusDialogState extends State<_CreateSyllabusDialog> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String? _exam;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: OseeTheme.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: OseeTheme.ink, width: 1),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEW SYLLABUS',
            style: TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: OseeTheme.accent,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'A new canvas.',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: OseeTheme.ink,
            ),
          ),
          const SizedBox(height: 6),
          Container(height: 1, color: OseeTheme.gold),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(fontFamily: 'Helvetica', fontSize: 11, letterSpacing: 1.5),
                hintText: 'e.g. TOEFL iBT 12-week plan',
                hintStyle: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: TextStyle(fontFamily: 'Helvetica', fontSize: 11, letterSpacing: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _exam,
              decoration: const InputDecoration(
                labelText: 'Target exam',
                labelStyle: TextStyle(fontFamily: 'Helvetica', fontSize: 11, letterSpacing: 1.5),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Any / Mixed')),
                DropdownMenuItem(value: 'TOEFL_IBT', child: Text('TOEFL iBT')),
                DropdownMenuItem(value: 'TOEFL_ITP', child: Text('TOEFL ITP')),
                DropdownMenuItem(value: 'IELTS', child: Text('IELTS')),
                DropdownMenuItem(value: 'TOEIC', child: Text('TOEIC')),
                DropdownMenuItem(value: 'GENERAL', child: Text('General English')),
              ],
              onChanged: (v) => setState(() => _exam = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: OseeTheme.stone,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: OseeTheme.ink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
              side: const BorderSide(color: OseeTheme.gold, width: 1.5),
            ),
          ),
          onPressed: () {
            final n = _name.text.trim();
            if (n.isEmpty) return;
            Navigator.pop(context, _CreateSyllabusResult(n, _desc.text.trim().isEmpty ? null : _desc.text.trim(), _exam));
          },
          child: const Text(
            'CREATE',
            style: TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}