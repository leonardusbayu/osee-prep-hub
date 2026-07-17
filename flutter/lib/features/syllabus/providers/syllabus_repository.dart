import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/syllabus.dart';

/// Thin Dio-backed repository for the syllabus endpoints.
class SyllabusRepository {
  SyllabusRepository();

  Future<List<Syllabus>> listSyllabi() async {
    final dio = ApiClient.create();
    final res = await dio.get('/teacher/syllabi');
    final list = (res.data['syllabi'] as List? ?? const []);
    return list
        .cast<Map<String, dynamic>>()
        .map(Syllabus.fromJson)
        .toList(growable: false);
  }

  Future<Syllabus> createSyllabus({
    required String name,
    String? description,
    String? targetExam,
    String? classroomId,
  }) async {
    final dio = ApiClient.create();
    final res = await dio.post(
      '/teacher/syllabi',
      data: {
        'name': name,
        if (description != null) 'description': description,
        if (targetExam != null) 'target_exam': targetExam,
        if (classroomId != null) 'classroom_id': classroomId,
      },
    );
    return Syllabus.fromJson(res.data as Map<String, dynamic>);
  }

  /// Returns the syllabus + its items.
  Future<({Syllabus syllabus, List<SyllabusItem> items})> getSyllabus(
    String id,
  ) async {
    final dio = ApiClient.create();
    final res = await dio.get('/teacher/syllabi/$id');
    final data = res.data as Map<String, dynamic>;
    return (
      syllabus: Syllabus.fromJson(data['syllabus'] as Map<String, dynamic>),
      items: (data['items'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(SyllabusItem.fromJson)
          .toList(growable: false),
    );
  }

  /// Replaces all items in the syllabus (atomic).
  Future<void> saveItems(String syllabusId, List<SyllabusItem> items) async {
    final dio = ApiClient.create();
    await dio.put(
      '/teacher/syllabi/$syllabusId/items',
      data: {'items': items.map((i) => i.toSaveJson()).toList()},
    );
  }

  Future<SyllabusItem> addItem(String syllabusId, SyllabusItem item) async {
    final dio = ApiClient.create();
    final res = await dio.post(
      '/teacher/syllabi/$syllabusId/items',
      data: item.toSaveJson(),
    );
    return SyllabusItem.fromJson(res.data as Map<String, dynamic>);
  }
}

final syllabusRepositoryProvider = Provider<SyllabusRepository>(
  (ref) => SyllabusRepository(),
);

/// List of the calling teacher's syllabi.
final syllabiListProvider = FutureProvider.autoDispose<List<Syllabus>>((
  ref,
) async {
  final repo = ref.read(syllabusRepositoryProvider);
  return repo.listSyllabi();
});

/// Single syllabus + its items, keyed by syllabus id.
final syllabusDetailProvider = FutureProvider.autoDispose
    .family<({Syllabus syllabus, List<SyllabusItem> items}), String>((
      ref,
      id,
    ) async {
      final repo = ref.read(syllabusRepositoryProvider);
      return repo.getSyllabus(id);
    });
