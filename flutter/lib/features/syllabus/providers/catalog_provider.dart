import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../models/catalog.dart';
import '../models/syllabus.dart';

/// Catalog repository — fetches the material catalog from
/// `/api/teacher/catalog` at runtime. Falls back to the curated static
/// [kMaterialCatalog] when the API is unreachable (offline / dev) OR when
/// the API returns an empty list (DB not yet seeded with teacher_custom
/// syllabus_items) so the syllabus builder always has materials to show.
final catalogProvider = FutureProvider.autoDispose<List<CatalogEntry>>((
  ref,
) async {
  try {
    final dio = ApiClient.create();
    final res = await dio.get('/teacher/catalog');
    final data = res.data as Map<String, dynamic>;
    final list = data['catalog'] as List? ?? [];
    final entries = list.map<CatalogEntry>((raw) {
      final m = raw as Map<String, dynamic>;
      return CatalogEntry(
        sourceType: (m['source_type'] as String?) ?? 'teacher_custom',
        materialId: (m['material_id'] as String?) ?? '',
        title: (m['title'] as String?) ?? 'Untitled',
        description: m['description'] as String?,
        itemType: (m['item_type'] as String?) ?? 'reading',
        section: m['section'] as String?,
        difficulty: m['difficulty'] as String?,
        estimatedMinutes: (m['estimated_minutes'] as int?) ?? 20,
      );
    }).toList();
    // API returned data — use it.
    if (entries.isNotEmpty) return entries;
    // API succeeded but returned empty — DB not seeded yet. Fall back to the
    // static curated catalog so the syllabus builder is always usable.
    debugPrint(
      'catalogProvider: API returned empty catalog, using static fallback',
    );
    return kMaterialCatalog;
  } catch (e) {
    // Network failure — fall back to the static curated set.
    debugPrint('catalogProvider: fetch failed, using static fallback: $e');
    return kMaterialCatalog;
  }
});
