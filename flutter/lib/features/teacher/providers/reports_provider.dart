import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

/// Student report summary.
class StudentReport {
  const StudentReport({
    required this.studentId,
    required this.studentName,
    required this.scores,
    required this.recommendations,
  });

  final String studentId;
  final String studentName;
  final Map<String, dynamic> scores;
  final List<String> recommendations;

  factory StudentReport.fromJson(Map<String, dynamic> json) {
    return StudentReport(
      studentId: json['student_id'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      scores: (json['scores'] as Map<String, dynamic>?) ?? {},
      recommendations: ((json['recommendations'] as List<dynamic>?) ?? [])
          .cast<String>(),
    );
  }
}

/// Classroom report summary.
class ClassroomReport {
  const ClassroomReport({
    required this.classroomId,
    required this.classroomName,
    required this.studentReports,
  });

  final String classroomId;
  final String classroomName;
  final List<StudentReport> studentReports;

  factory ClassroomReport.fromJson(Map<String, dynamic> json) {
    return ClassroomReport(
      classroomId: json['classroom_id'] as String? ?? '',
      classroomName: json['classroom_name'] as String? ?? '',
      studentReports: ((json['student_reports'] as List<dynamic>?) ?? [])
          .map((e) => StudentReport.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Single student report provider.
final studentReportProvider = FutureProvider.family
    .autoDispose<StudentReport, String>((ref, studentId) async {
      final dio = ApiClient.create();
      final res = await dio.get('/teacher/students/$studentId/report');
      return StudentReport.fromJson(res.data as Map<String, dynamic>);
    });

/// Classroom report provider.
final classroomReportProvider = FutureProvider.family
    .autoDispose<ClassroomReport, String>((ref, classroomId) async {
      final dio = ApiClient.create();
      final res = await dio.get('/teacher/classrooms/$classroomId/report');
      return ClassroomReport.fromJson(res.data as Map<String, dynamic>);
    });

/// Email a student report.
class ReportEmailNotifier extends StateNotifier<AsyncValue<void>> {
  ReportEmailNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<bool> send(String studentId, {String? email}) async {
    state = const AsyncValue.loading();
    try {
      final dio = ApiClient.create();
      await dio.post(
        '/teacher/students/$studentId/report/email',
        data: {if (email != null) 'email': email},
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      return false;
    }
  }
}

final reportEmailNotifierProvider =
    StateNotifierProvider<ReportEmailNotifier, AsyncValue<void>>((ref) {
      return ReportEmailNotifier(ref);
    });
