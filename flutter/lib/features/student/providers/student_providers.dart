import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

/// Student dashboard data.
class StudentDashboard {
  const StudentDashboard({
    required this.student,
    required this.syllabus,
    required this.progress,
    required this.readiness,
    required this.upcomingClasses,
    required this.recommendations,
    required this.classrooms,
  });

  final Map<String, dynamic> student;
  final List<dynamic> syllabus;
  final Map<String, dynamic> progress;
  final Map<String, dynamic> readiness;
  final List<dynamic> upcomingClasses;
  final List<String> recommendations;
  final List<dynamic> classrooms;

  factory StudentDashboard.fromJson(Map<String, dynamic> json) {
    return StudentDashboard(
      student: (json['student'] as Map<String, dynamic>?) ?? {},
      syllabus: (json['syllabus'] as List<dynamic>?) ?? [],
      progress: (json['progress'] as Map<String, dynamic>?) ?? {},
      readiness: (json['readiness'] as Map<String, dynamic>?) ?? {},
      upcomingClasses: (json['upcoming_classes'] as List<dynamic>?) ?? [],
      recommendations: ((json['recommendations'] as List<dynamic>?) ?? [])
          .cast<String>(),
      classrooms: (json['classrooms'] as List<dynamic>?) ?? [],
    );
  }
}

final studentDashboardProvider = FutureProvider.autoDispose<StudentDashboard>((
  ref,
) async {
  final dio = ApiClient.create();
  final res = await dio.get('/student/dashboard');
  return StudentDashboard.fromJson(res.data as Map<String, dynamic>);
});

/// Syllabus assigned to the current student.
final studentSyllabusProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final dio = ApiClient.create();
  final res = await dio.get('/student/syllabus');
  final data = (res.data as Map<String, dynamic>?) ?? {};
  return (data['syllabus'] as List<dynamic>?) ?? [];
});

/// Progress across all platforms.
final studentProgressProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final dio = ApiClient.create();
      final res = await dio.get('/student/progress');
      return (res.data as Map<String, dynamic>?) ?? {};
    });

/// Readiness assessment.
final studentReadinessProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final dio = ApiClient.create();
      final res = await dio.get('/student/readiness');
      return (res.data as Map<String, dynamic>?) ?? {};
    });

/// Upcoming live classes for students.
final studentUpcomingClassesProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
      final dio = ApiClient.create();
      final res = await dio.get('/classes/upcoming');
      final data = (res.data as Map<String, dynamic>?) ?? {};
      return (data['classes'] as List<dynamic>?) ?? [];
    });

/// Video lessons available to the student.
final studentVideoLessonsProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final dio = ApiClient.create();
  final res = await dio.get('/student/videos');
  final data = (res.data as Map<String, dynamic>?) ?? {};
  return (data['videos'] as List<dynamic>?) ?? [];
});

/// Mark a video lesson as completed (or record progress).
class VideoProgressNotifier extends StateNotifier<AsyncValue<void>> {
  VideoProgressNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<bool> record({
    required String lessonId,
    required int watchedSeconds,
    int? quizScore,
  }) async {
    state = const AsyncValue.loading();
    try {
      final dio = ApiClient.create();
      await dio.post(
        '/student/videos/$lessonId/progress',
        data: {
          'watched_seconds': watchedSeconds,
          if (quizScore != null) 'quiz_score': quizScore,
        },
      );
      ref.invalidate(studentVideoLessonsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      return false;
    }
  }
}

final videoProgressNotifierProvider =
    StateNotifierProvider<VideoProgressNotifier, AsyncValue<void>>((ref) {
      return VideoProgressNotifier(ref);
    });
