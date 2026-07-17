import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_client.dart';
import '../student_theme.dart';
import '../widgets/student_widgets.dart';

/// Materials Hub — Goal 6: a centralized hub connected to all test-prep
/// platforms + the tutor bot. Shows every material a student can use
/// (syllabus items assigned to them, published video lessons, and AI-generated
/// materials) in one searchable, filterable list, with deep links to the
/// source platform or YouTube video.
class MaterialsPage extends ConsumerStatefulWidget {
  const MaterialsPage({super.key});

  @override
  ConsumerState<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends ConsumerState<MaterialsPage> {
  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;
  String? _error;
  String _typeFilter = '';
  String _query = '';

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
      final res = await dio.get(
        '/platform/materials',
        queryParameters: {'limit': 200},
      );
      final list = (res.data['materials'] as List?) ?? [];
      setState(() {
        _materials = list.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load materials';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _materials.where((m) {
      if (_typeFilter.isNotEmpty && m['type'] != _typeFilter) return false;
      if (_query.trim().isEmpty) return true;
      final title = (m['title'] as String?)?.toLowerCase() ?? '';
      final desc = (m['description'] as String?)?.toLowerCase() ?? '';
      return title.contains(_query.toLowerCase()) ||
          desc.contains(_query.toLowerCase());
    }).toList();
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
                  name: 'Materials Hub',
                  subtitle:
                      '${_materials.length} materials across all platforms',
                ),
                const SizedBox(height: 24),
                // Search + filter row
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search materials…',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: StudentTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: StudentTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        StudentTheme.radiusButton,
                      ),
                      borderSide: BorderSide(color: StudentTheme.dividerSubtle),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 12),
                // Type chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chip('All', ''),
                      _chip('Reading', 'reading'),
                      _chip('Listening', 'listening'),
                      _chip('Speaking', 'speaking'),
                      _chip('Writing', 'writing'),
                      _chip('Grammar', 'grammar'),
                      _chip('Vocabulary', 'vocabulary'),
                      _chip('Video', 'video'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                StudentSectionHeader(
                  title: 'All Materials',
                  icon: Icons.library_books_rounded,
                  onSeeAll: null,
                ),
                const SizedBox(height: 12),
                ..._filtered.map(_materialCard),
                if (_filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No materials match your filters.',
                        style: TextStyle(color: StudentTheme.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _typeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _typeFilter = selected ? '' : value),
        selectedColor: StudentTheme.primary.withValues(alpha: 0.15),
        checkmarkColor: StudentTheme.primary,
        labelStyle: TextStyle(
          color: selected ? StudentTheme.primary : StudentTheme.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected
                ? StudentTheme.primary.withValues(alpha: 0.4)
                : StudentTheme.dividerSubtle,
          ),
        ),
        backgroundColor: StudentTheme.surface,
      ),
    );
  }

  Widget _materialCard(Map<String, dynamic> m) {
    final url = m['url'] as String?;
    final type = (m['type'] as String?) ?? 'material';
    final source = (m['source'] as String?) ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentTheme.surface,
        borderRadius: BorderRadius.circular(StudentTheme.radiusCard),
        border: Border.all(color: StudentTheme.dividerSubtle),
        boxShadow: StudentTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: StudentTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              type == 'video'
                  ? Icons.play_circle_rounded
                  : Icons.menu_book_rounded,
              color: StudentTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m['title'] as String? ?? 'Untitled',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: StudentTheme.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _badge(type),
                    const SizedBox(width: 6),
                    if (source.isNotEmpty) _badge(source),
                    const SizedBox(width: 6),
                    if (m['level'] != null) _badge(m['level'] as String),
                  ],
                ),
                if (m['description'] != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    m['description'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StudentTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (url != null && url.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.open_in_new_rounded,
                color: StudentTheme.primary,
              ),
              onPressed: () => launchUrl(Uri.parse(url)),
              tooltip: 'Open',
            ),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: StudentTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: StudentTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
