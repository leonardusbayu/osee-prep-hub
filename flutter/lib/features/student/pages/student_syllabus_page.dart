import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../student_theme.dart';
import '../widgets/student_widgets.dart';

/// Student syllabus page — Modernized UI.
/// Shows assigned syllabi + items with deep links to practice platforms.
class StudentSyllabusPage extends ConsumerStatefulWidget {
  const StudentSyllabusPage({super.key});

  @override
  ConsumerState<StudentSyllabusPage> createState() =>
      _StudentSyllabusPageState();
}

class _StudentSyllabusPageState extends ConsumerState<StudentSyllabusPage> {
  List<dynamic>? _syllabi;
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
      final r = await dio.get('/student/syllabus');
      setState(() {
        _syllabi = (r.data as Map)['syllabi'] as List? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load';
        _isLoading = false;
      });
    }
  }

  Future<void> _startItem(String itemId) async {
    try {
      final dio = ApiClient.create();
      final r = await dio.post('/student/syllabus/$itemId/start', data: {});
      final deepLink = (r.data as Map)['deep_link'] as String?;
      if (deepLink != null && deepLink.isNotEmpty && mounted) {
        // Open the deep link immediately, with a SnackBar re-open fallback.
        await launchUrl(Uri.parse(deepLink));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: StudentTheme.primary,
            content: Text(
              'Opening: $deepLink',
              style: StudentTheme.cardLabel(Colors.white),
            ),
            action: SnackBarAction(
              label: 'Re-open',
              textColor: Colors.white,
              onPressed: () => launchUrl(Uri.parse(deepLink)),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: StudentTheme.successGreen,
            content: Text(
              'Started! No external link for this item.',
              style: StudentTheme.cardLabel(Colors.white),
            ),
          ),
        );
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

  Future<void> _completeItem(String itemId) async {
    try {
      final dio = ApiClient.create();
      await dio.post('/student/syllabus/$itemId/complete', data: {});
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
      }
      _load();
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

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: StudentTheme.primary),
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
        : _buildContent(isDesktop);
  }

  Widget _buildContent(bool isDesktop) {
    final isEmpty = _syllabi?.isEmpty ?? true;

    return RefreshIndicator(
      onRefresh: _load,
      color: StudentTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(StudentSpacing.xl),
        children: [
          StudentTopBar(
            name: 'Student',
            subtitle: 'My Syllabus',
            onMenuTap: isDesktop
                ? null
                : () => Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(height: StudentSpacing.xxl),

          if (isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 64,
                horizontal: StudentSpacing.xl,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: StudentTheme.surface,
                borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
                boxShadow: StudentTheme.cardShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.view_kanban_outlined,
                    size: 64,
                    color: StudentTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: StudentSpacing.lg),
                  Text(
                    'No syllabus assigned yet',
                    style: StudentTheme.courseTitle(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ask your teacher to assign a syllabus to your classroom.',
                    style: StudentTheme.cardLabel(),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            const StudentSectionHeader(
              title: 'Assigned Syllabi',
              icon: Icons.assignment_rounded,
            ),
            const SizedBox(height: StudentSpacing.lg),
            for (final sData in _syllabi!) ...[
              _SyllabusCard(
                syllabus: sData as Map<String, dynamic>,
                onStart: _startItem,
                onComplete: _completeItem,
              ),
              const SizedBox(height: StudentSpacing.md),
            ],
          ],
        ],
      ),
    );
  }
}

class _SyllabusCard extends StatelessWidget {
  const _SyllabusCard({
    required this.syllabus,
    required this.onStart,
    required this.onComplete,
  });
  final Map<String, dynamic> syllabus;
  final void Function(String) onStart;
  final void Function(String) onComplete;

  @override
  Widget build(BuildContext context) {
    final items = (syllabus['syllabus_items'] as List?) ?? [];
    return Container(
      decoration: BoxDecoration(
        color: StudentTheme.surface,
        borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
        boxShadow: StudentTheme.cardShadow,
        border: Border.all(color: StudentTheme.divider),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: StudentTheme.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.view_kanban_rounded,
            color: StudentTheme.primary,
            size: 28,
          ),
        ),
        title: Text(
          syllabus['name'] as String? ?? '',
          style: StudentTheme.courseTitle().copyWith(fontSize: 16),
        ),
        subtitle: Text(
          '${syllabus['target_exam'] ?? '—'} · ${items.length} items',
          style: StudentTheme.cardLabel(),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(StudentSpacing.md),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: StudentTheme.divider)),
            ),
            child: Column(
              children: [
                for (final item in items)
                  _SyllabusItemTile(
                    item: item as Map<String, dynamic>,
                    onStart: () => onStart(item['id'] as String),
                    onComplete: () => onComplete(item['id'] as String),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyllabusItemTile extends StatelessWidget {
  const _SyllabusItemTile({
    required this.item,
    required this.onStart,
    required this.onComplete,
  });
  final Map<String, dynamic> item;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final type = item['item_type'] as String? ?? '';
    final icon = _typeIcon(type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: StudentTheme.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: StudentTheme.divider),
            ),
            child: Icon(icon, size: 16, color: StudentTheme.textSecondary),
          ),
          const SizedBox(width: StudentSpacing.md),
          Expanded(
            child: Text(
              item['title'] as String? ?? '',
              style: StudentTheme.noticeTitle().copyWith(
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: StudentSpacing.sm),
          TextButton(
            onPressed: onStart,
            style: TextButton.styleFrom(
              foregroundColor: StudentTheme.primary,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Start'),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: onComplete,
            style: OutlinedButton.styleFrom(
              foregroundColor: StudentTheme.textSecondary,
              side: const BorderSide(color: StudentTheme.divider),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
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
}
