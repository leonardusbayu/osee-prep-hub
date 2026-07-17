import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../student_theme.dart';
import '../widgets/student_widgets.dart';

/// Platform Links — Goal 6: deep links to all practice platforms + EduBot.
/// Reads the configurable platform_links table via the API so links can
/// change without an app deploy.
class PlatformLinksPage extends ConsumerStatefulWidget {
  const PlatformLinksPage({super.key});

  @override
  ConsumerState<PlatformLinksPage> createState() => _PlatformLinksPageState();
}

class _PlatformLinksPageState extends ConsumerState<PlatformLinksPage> {
  List<Map<String, dynamic>> _links = [];
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
      final res = await dio.get('/platform/platform-links');
      final list = (res.data['links'] as List?) ?? [];
      setState(() {
        _links = list.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load platform links';
        _isLoading = false;
      });
    }
  }

  IconData _iconFor(String platform) {
    switch (platform) {
      case 'ibt':
        return Icons.school_rounded;
      case 'itp':
        return Icons.quiz_rounded;
      case 'ielts':
        return Icons.language_rounded;
      case 'toeic':
        return Icons.work_rounded;
      case 'edubot':
        return Icons.smart_toy_rounded;
      case 'osee':
        return Icons.calendar_today_rounded;
      default:
        return Icons.link_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    style: const TextStyle(color: StudentTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _load,
                    style: FilledButton.styleFrom(
                      backgroundColor: StudentTheme.primary,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                StudentTopBar(
                  name: 'Practice Platforms',
                  subtitle: 'Open any test-prep platform or the Tutor Bot',
                ),
                const SizedBox(height: 24),
                StudentSectionHeader(
                  title: 'All Platforms',
                  icon: Icons.link_rounded,
                  onSeeAll: null,
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 900
                      ? 3
                      : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: _links.map(_platformCard).toList(),
                ),
              ],
            ),
    );
  }

  Widget _platformCard(Map<String, dynamic> link) {
    final platform = (link['platform'] as String?) ?? '';
    final url = (link['url'] as String?) ?? '';
    final label = (link['label'] as String?) ?? platform;
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StudentTheme.surface,
          borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
          border: Border.all(color: StudentTheme.dividerSubtle),
          boxShadow: StudentTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: StudentTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _iconFor(platform),
                    color: StudentTheme.primary,
                    size: 22,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.open_in_new_rounded,
                  color: StudentTheme.textSecondary,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: StudentTheme.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              (link['exam_type'] as String?) ?? '',
              style: const TextStyle(
                color: StudentTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
