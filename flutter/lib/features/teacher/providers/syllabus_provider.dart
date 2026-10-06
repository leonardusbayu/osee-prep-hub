import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

/// Syllabus summary for a teacher.
class SyllabusSummary {
  const SyllabusSummary({
    required this.id,
    required this.name,
    required this.isPublished,
    this.targetExam,
  });

  final String id;
  final String name;
  final bool isPublished;
  final String? targetExam;

  factory SyllabusSummary.fromJson(Map<String, dynamic> json) {
    return SyllabusSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      isPublished: json['is_published'] as bool? ?? false,
      targetExam: json['target_exam'] as String?,
    );
  }
}

/// Syllabus item used in the builder.
class SyllabusItem {
  const SyllabusItem({
    required this.id,
    required this.title,
    required this.itemType,
    required this.sourceType,
    this.section,
    this.difficulty,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String itemType;
  final String sourceType;
  final String? section;
  final String? difficulty;
  final int sortOrder;

  factory SyllabusItem.fromJson(Map<String, dynamic> json) {
    return SyllabusItem(
      id: json['id'] as String,
      title: json['title'] as String,
      itemType: json['item_type'] as String,
      sourceType: json['source_type'] as String,
      section: json['section'] as String?,
      difficulty: json['difficulty'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'item_type': itemType,
    'source_type': sourceType,
    if (section != null) 'section': section,
    if (difficulty != null) 'difficulty': difficulty,
    'sort_order': sortOrder,
  };
}

/// List of syllabi for the current teacher.
final syllabiProvider = FutureProvider.autoDispose<List<SyllabusSummary>>((
  ref,
) async {
  final dio = ApiClient.create();
  final res = await dio.get('/teacher/syllabus');
  final data = (res.data as Map<String, dynamic>?) ?? {};
  final list = (data['syllabi'] as List<dynamic>? ?? []) as List<dynamic>;
  return list
      .map((e) => SyllabusSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Syllabus detail by ID including items.
final syllabusDetailProvider = FutureProvider.family
    .autoDispose<Map<String, dynamic>, String>((ref, id) async {
      final dio = ApiClient.create();
      final res = await dio.get('/teacher/syllabus/$id');
      return res.data as Map<String, dynamic>;
    });

/// Items for a syllabus.
final syllabusItemsProvider = FutureProvider.family
    .autoDispose<List<SyllabusItem>, String>((ref, id) async {
      final dio = ApiClient.create();
      final res = await dio.get('/teacher/syllabus/$id/items');
      final data = (res.data as Map<String, dynamic>?) ?? {};
      final list = (data['items'] as List<dynamic>? ?? []) as List<dynamic>;
      return list
          .map((e) => SyllabusItem.fromJson(e as Map<String, dynamic>))
          .toList();
    });

/// CRUD + batch save operations for syllabi.
class SyllabusNotifier extends StateNotifier<AsyncValue<void>> {
  SyllabusNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<bool> create({
    required String name,
    String? description,
    String? targetExam,
    String? classroomId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final dio = ApiClient.create();
      await dio.post(
        '/teacher/syllabus',
        data: {
          'name': name,
          if (description != null) 'description': description,
          if (targetExam != null) 'target_exam': targetExam,
          if (classroomId != null) 'classroom_id': classroomId,
        },
      );
      ref.invalidate(syllabiProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      return false;
    }
  }

  Future<bool> saveItems(
    String syllabusId, {
    required List<SyllabusItem> items,
  }) async {
    state = const AsyncValue.loading();
    try {
      final dio = ApiClient.create();
      await dio.put(
        '/teacher/syllabus/$syllabusId/items',
        data: {'items': items.map((i) => i.toJson()).toList()},
      );
      ref.invalidate(syllabusItemsProvider(syllabusId));
      state = const AsyncValue.data(null);
      return true;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      return false;
    }
  }

  Future<bool> deleteItem(String syllabusId, String itemId) async {
    state = const AsyncValue.loading();
    try {
      final dio = ApiClient.create();
      await dio.delete('/teacher/syllabus/$syllabusId/items/$itemId');
      ref.invalidate(syllabusItemsProvider(syllabusId));
      state = const AsyncValue.data(null);
      return true;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      return false;
    }
  }

  Future<bool> togglePublish(String syllabusId, {required bool publish}) async {
    state = const AsyncValue.loading();
    try {
      final dio = ApiClient.create();
      await dio.patch(
        '/teacher/syllabus/$syllabusId/publish',
        data: {'publish': publish},
      );
      ref.invalidate(syllabiProvider);
      ref.invalidate(syllabusDetailProvider(syllabusId));
      state = const AsyncValue.data(null);
      return true;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      return false;
    }
  }
}

final syllabusNotifierProvider =
    StateNotifierProvider<SyllabusNotifier, AsyncValue<void>>((ref) {
      return SyllabusNotifier(ref);
    });
