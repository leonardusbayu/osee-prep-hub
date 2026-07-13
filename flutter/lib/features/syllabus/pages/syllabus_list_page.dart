import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/ui_components.dart';
import '../models/syllabus.dart';
import '../providers/syllabus_repository.dart';

class SyllabusListPage extends ConsumerWidget {
  const SyllabusListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSyllabi = ref.watch(syllabiListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Syllabi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/teacher'),
          tooltip: 'Back',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(syllabiListProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Syllabus'),
      ),
      body: asyncSyllabi.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: 'Failed to load syllabi: $e',
          onRetry: () => ref.invalidate(syllabiListProvider),
        ),
        data: (syllabi) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(syllabiListProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.md,
              Spacing.md,
              96,
            ),
            children: [
              PageHeader(
                title: 'Syllabus Library',
                subtitle:
                    'Plan weekly learning paths and assign materials from OSEE platforms, EduBot, videos, and AI generation.',
                icon: Icons.view_kanban_rounded,
                trailing: FilledButton.icon(
                  onPressed: () => _showCreateDialog(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create'),
                ),
              ),
              const SizedBox(height: Spacing.lg),
              _StatsRow(syllabi: syllabi),
              const SizedBox(height: Spacing.lg),
              SectionHeader(
                title: 'All Syllabi',
                subtitle:
                    '${syllabi.length} plan${syllabi.length == 1 ? '' : 's'}',
              ),
              if (syllabi.isEmpty)
                EmptyState(
                  icon: Icons.view_kanban_outlined,
                  title: 'No syllabi yet',
                  subtitle:
                      'Create your first plan and organize materials into weekly units.',
                  action: FilledButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create Syllabus'),
                  ),
                )
              else
                ...syllabi.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.sm),
                    child: _SyllabusCard(syllabus: s),
                  ),
                ),
            ],
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    }
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.syllabi});
  final List<Syllabus> syllabi;

  @override
  Widget build(BuildContext context) {
    final published = syllabi.where((s) => s.isPublished).length;
    final templates = syllabi.where((s) => s.isTemplate).length;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.45,
      crossAxisSpacing: Spacing.sm,
      mainAxisSpacing: Spacing.sm,
      children: [
        StatCard(
          icon: Icons.library_books_rounded,
          label: 'Total',
          value: '${syllabi.length}',
          color: OseeTheme.primary,
        ),
        StatCard(
          icon: Icons.check_circle_rounded,
          label: 'Published',
          value: '$published',
          color: OseeTheme.success,
        ),
        StatCard(
          icon: Icons.copy_all_rounded,
          label: 'Templates',
          value: '$templates',
          color: OseeTheme.warning,
        ),
      ],
    );
  }
}

class _SyllabusCard extends StatelessWidget {
  const _SyllabusCard({required this.syllabus});
  final Syllabus syllabus;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OseeTheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go('/teacher/syllabi/${syllabus.id}'),
        child: SurfaceCard(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: OseeTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.view_week_rounded,
                  color: OseeTheme.primary,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      syllabus.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      syllabus.description?.isNotEmpty == true
                          ? syllabus.description!
                          : 'No description',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Wrap(
                      spacing: Spacing.xs,
                      children: [
                        _Pill(text: syllabus.targetExam ?? 'Mixed'),
                        _Pill(
                          text: syllabus.isPublished ? 'Published' : 'Draft',
                          color: syllabus.isPublished
                              ? OseeTheme.success
                              : OseeTheme.textMuted,
                        ),
                        if (syllabus.isTemplate)
                          const _Pill(
                            text: 'Template',
                            color: OseeTheme.warning,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: OseeTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.color = OseeTheme.primary});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
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
      title: const Text('New syllabus'),
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
                hintText: 'e.g. TOEFL iBT 12-week plan',
              ),
            ),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _desc,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: Spacing.md),
            DropdownButtonFormField<String>(
              value: _exam,
              decoration: const InputDecoration(labelText: 'Target exam'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Any / Mixed')),
                DropdownMenuItem(value: 'TOEFL_IBT', child: Text('TOEFL iBT')),
                DropdownMenuItem(value: 'TOEFL_ITP', child: Text('TOEFL ITP')),
                DropdownMenuItem(value: 'IELTS', child: Text('IELTS')),
                DropdownMenuItem(value: 'TOEIC', child: Text('TOEIC')),
                DropdownMenuItem(
                  value: 'GENERAL',
                  child: Text('General English'),
                ),
              ],
              onChanged: (v) => setState(() => _exam = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final n = _name.text.trim();
            if (n.isEmpty) return;
            Navigator.pop(
              context,
              _CreateSyllabusResult(
                n,
                _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                _exam,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
