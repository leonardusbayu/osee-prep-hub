import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

/// A classroom returned by the teacher API.
class ClassroomSummary {
  const ClassroomSummary({
    required this.id,
    required this.name,
    required this.joinCode,
    this.studentCount = 0,
    this.targetExam,
    this.isPrivate = false,
  });

  final String id;
  final String name;
  final String joinCode;
  final int studentCount;
  final String? targetExam;
  final bool isPrivate;

  factory ClassroomSummary.fromJson(Map<String, dynamic> json) {
    return ClassroomSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      joinCode: json['join_code'] as String,
      studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
      targetExam: json['target_exam'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
    );
  }
}

/// Detailed classroom payload including students.
class ClassroomDetail {
  const ClassroomDetail({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.students,
    this.targetExam,
    this.isPrivate = false,
  });

  final String id;
  final String name;
  final String joinCode;
  final List<Map<String, dynamic>> students;
  final String? targetExam;
  final bool isPrivate;

  factory ClassroomDetail.fromJson(Map<String, dynamic> json) {
    return ClassroomDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      joinCode: json['join_code'] as String,
      students: ((json['students'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>(),
      targetExam: json['target_exam'] as String?,
      isPrivate: json['is_private'] as bool? ?? false,
    );
  }
}

/// Async list of teacher classrooms.
final classroomsProvider = FutureProvider.autoDispose<List<ClassroomSummary>>((
  ref,
) async {
  final dio = ApiClient.create();
  final res = await dio.get('/teacher/classrooms');
  final data = (res.data as Map<String, dynamic>?) ?? {};
  final list = (data['classrooms'] as List<dynamic>? ?? []) as List<dynamic>;
  return list
      .map((e) => ClassroomSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Single classroom detail provider by ID.
final classroomDetailProvider = FutureProvider.family
    .autoDispose<ClassroomDetail, String>((ref, id) async {
      final dio = ApiClient.create();
      final res = await dio.get('/teacher/classrooms/$id');
      return ClassroomDetail.fromJson(res.data as Map<String, dynamic>);
    });

/// Creates a classroom and invalidates the list provider.
class ClassroomNotifier extends StateNotifier<AsyncValue<void>> {
  ClassroomNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<bool> create({
    required String name,
    String? description,
    String? targetExam,
    int? maxStudents,
    bool isPrivate = false,
  }) async {
    state = const AsyncValue.loading();
    final dio = ApiClient.create();
    try {
      await dio.post(
        '/teacher/classrooms',
        data: {
          'name': name,
          if (description != null) 'description': description,
          if (targetExam != null) 'target_exam': targetExam,
          if (maxStudents != null) 'max_students': maxStudents,
          'is_private': isPrivate,
        },
      );
      ref.invalidate(classroomsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      return false;
    }
  }

  Future<bool> addStudents(
    String classroomId, {
    required List<String> emails,
  }) async {
    state = const AsyncValue.loading();
    final dio = ApiClient.create();
    try {
      await dio.post(
        '/teacher/classrooms/$classroomId/students',
        data: {'emails': emails},
      );
      ref.invalidate(classroomDetailProvider(classroomId));
      state = const AsyncValue.data(null);
      return true;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      return false;
    }
  }
}

final classroomNotifierProvider =
    StateNotifierProvider<ClassroomNotifier, AsyncValue<void>>((ref) {
      return ClassroomNotifier(ref);
    });
