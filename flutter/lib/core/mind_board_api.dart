import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

/// API service for the lesson-board feature (Tier 1-4 teacher experience).
///
/// Wraps all /api/boards/* and /api/materials/* endpoints. Uses a Riverpod
/// provider so the page can access it via ref.read(mindBoardApiProvider).
class MindBoardApi {
  MindBoardApi(this._dio);
  final Dio _dio;

  // ============================================================
  // Boards CRUD
  // ============================================================

  Future<Map<String, dynamic>> createBoard({
    required String title,
    String? description,
    String? syllabusId,
    String? targetExam,
    String? cefrLevel,
    List<String>? tags,
    List<Map<String, String>>? kpTags,
  }) async {
    final r = await _dio.post('/boards', data: {
      'title': title,
      if (description != null) 'description': description,
      if (syllabusId != null) 'syllabus_id': syllabusId,
      if (targetExam != null) 'target_exam': targetExam,
      if (cefrLevel != null) 'cefr_level': cefrLevel,
      if (tags != null) 'tags': tags,
      if (kpTags != null) 'kp_tags': kpTags,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listBoards({bool includeArchived = false}) async {
    final r = await _dio.get('/boards', queryParameters: {
      if (includeArchived) 'include_archived': 'true',
    });
    return (r.data['boards'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getBoard(String boardId) async {
    final r = await _dio.get('/boards/$boardId');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBoard(String boardId, Map<String, dynamic> patch) async {
    final r = await _dio.patch('/boards/$boardId', data: patch);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveCanvas(
    String boardId,
    Map<String, dynamic> canvasState, {
    bool autosave = false,
    String? label,
  }) async {
    final r = await _dio.put('/boards/$boardId/canvas', data: {
      'canvas_state': canvasState,
      'autosave': autosave,
      if (label != null) 'label': label,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteBoard(String boardId) async {
    await _dio.delete('/boards/$boardId');
  }

  // ============================================================
  // Versions
  // ============================================================

  Future<List<Map<String, dynamic>>> listVersions(String boardId) async {
    final r = await _dio.get('/boards/$boardId/versions');
    return (r.data['versions'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getVersion(String boardId, String versionId) async {
    final r = await _dio.get('/boards/$boardId/versions/$versionId');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> restoreVersion(String boardId, String versionId) async {
    final r = await _dio.post('/boards/$boardId/versions/$versionId/restore');
    return r.data as Map<String, dynamic>;
  }

  // ============================================================
  // Shares
  // ============================================================

  Future<Map<String, dynamic>> shareBoard(String boardId, String email, String permission) async {
    final r = await _dio.post('/boards/$boardId/shares', data: {
      'shared_with_email': email,
      'permission': permission,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listShares(String boardId) async {
    final r = await _dio.get('/boards/$boardId/shares');
    return (r.data['shares'] as List).cast<Map<String, dynamic>>();
  }

  Future<void> revokeShare(String boardId, String shareId) async {
    await _dio.delete('/boards/$boardId/shares/$shareId');
  }

  // ============================================================
  // Comments
  // ============================================================

  Future<List<Map<String, dynamic>>> listComments(String boardId, {String? nodeId}) async {
    final r = await _dio.get('/boards/$boardId/comments', queryParameters: {
      if (nodeId != null) 'node_id': nodeId,
    });
    return (r.data['comments'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addComment(String boardId, String nodeId, String body) async {
    final r = await _dio.post('/boards/$boardId/comments', data: {
      'node_id': nodeId,
      'body': body,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<void> resolveComment(String boardId, String commentId, {bool resolved = true}) async {
    await _dio.patch('/boards/$boardId/comments/$commentId', data: {'resolved': resolved});
  }

  Future<void> deleteComment(String boardId, String commentId) async {
    await _dio.delete('/boards/$boardId/comments/$commentId');
  }

  // ============================================================
  // Assessments
  // ============================================================

  Future<List<Map<String, dynamic>>> listAssessments(String boardId) async {
    final r = await _dio.get('/boards/$boardId/assessments');
    return (r.data['assessments'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> generateAssessment(
    String boardId, {
    required String type,
    String? nodeId,
    required String topic,
    String? level,
    String? exam,
    Map<String, dynamic>? nodeContent,
  }) async {
    final r = await _dio.post('/boards/$boardId/assessments', data: {
      'type': type,
      if (nodeId != null) 'node_id': nodeId,
      'topic': topic,
      if (level != null) 'level': level,
      if (exam != null) 'exam': exam,
      if (nodeContent != null) 'node_content': nodeContent,
    });
    return r.data as Map<String, dynamic>;
  }

  // ============================================================
  // AI Critic + Feedback
  // ============================================================

  Future<Map<String, dynamic>> reviewLesson(
    String boardId, {
    required List<Map<String, dynamic>> nodes,
    String? targetExam,
    String? cefrLevel,
    List<Map<String, String>>? kpTags,
  }) async {
    final r = await _dio.post('/boards/$boardId/review', data: {
      'nodes': nodes,
      if (targetExam != null) 'target_exam': targetExam,
      if (cefrLevel != null) 'cefr_level': cefrLevel,
      if (kpTags != null) 'kp_tags': kpTags,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listFeedback(String boardId) async {
    final r = await _dio.get('/boards/$boardId/feedback');
    return (r.data['feedback'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> flagInaccurate(
    String boardId, {
    required String nodeId,
    required String body,
    String severity = 'warning',
    String category = 'other',
    String feedbackType = 'teacher_flag',
  }) async {
    final r = await _dio.post('/boards/$boardId/feedback', data: {
      'node_id': nodeId,
      'body': body,
      'severity': severity,
      'category': category,
      'feedback_type': feedbackType,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<void> resolveFeedback(String boardId, String feedbackId, {bool resolved = true}) async {
    await _dio.patch('/boards/$boardId/feedback/$feedbackId', data: {'resolved': resolved});
  }

  // ============================================================
  // Templates
  // ============================================================

  Future<List<Map<String, dynamic>>> listTemplates({String? category, bool includeUnofficial = false}) async {
    final r = await _dio.get('/boards/templates/list', queryParameters: {
      if (category != null) 'category': category,
      if (includeUnofficial) 'include_unofficial': 'true',
    });
    return (r.data['templates'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getTemplate(String templateId) async {
    final r = await _dio.get('/boards/templates/$templateId');
    return r.data as Map<String, dynamic>;
  }

  // ============================================================
  // Materials library
  // ============================================================

  Future<List<Map<String, dynamic>>> listMaterials({String? type}) async {
    final r = await _dio.get('/boards/materials/list', queryParameters: {
      if (type != null) 'type': type,
    });
    return (r.data['materials'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getMaterial(String materialId) async {
    final r = await _dio.get('/boards/materials/$materialId');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addMaterial(Map<String, dynamic> material) async {
    final r = await _dio.post('/boards/materials', data: material);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> ingestMaterial({
    required String name,
    required String type,
    String? url,
    String? content,
    String? filename,
  }) async {
    final r = await _dio.post('/boards/materials/ingest', data: {
      'name': name,
      'type': type,
      if (url != null) 'url': url,
      if (content != null) 'content': content,
      if (filename != null) 'filename': filename,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> ingestMaterialToRag(String materialId) async {
    final r = await _dio.post('/boards/materials/$materialId/ingest-rag');
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteMaterial(String materialId) async {
    await _dio.delete('/boards/materials/$materialId');
  }

  // ============================================================
  // AI node generation (extended with difficulty, kp_tags, linked_nodes)
  // ============================================================

  Future<Map<String, dynamic>> generateNode({
    required String type,
    required String topic,
    required String notes,
    String? exam,
    String? level,
    String? itemType,
    String? context,
    List<Map<String, String>>? sources,
    bool useRag = true,
    String? difficulty,
    List<Map<String, String>>? kpTags,
    List<Map<String, dynamic>>? linkedNodes,
  }) async {
    final r = await _dio.post('/ai/mind-map-node', data: {
      'type': type,
      'topic': topic,
      'notes': notes,
      if (exam != null) 'exam': exam,
      if (level != null) 'level': level,
      if (itemType != null) 'item_type': itemType,
      if (context != null) 'context': context,
      if (sources != null) 'sources': sources,
      'use_rag': useRag,
      if (difficulty != null) 'difficulty': difficulty,
      if (kpTags != null) 'kp_tags': kpTags,
      if (linkedNodes != null) 'linked_nodes': linkedNodes,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> agentChat({
    required String agent,
    required String message,
    String? context,
    String? topic,
    String? exam,
    String? level,
    List<Map<String, String>>? history,
    List<Map<String, String>>? sources,
  }) async {
    final r = await _dio.post('/ai/agent-chat', data: {
      'agent': agent,
      'message': message,
      if (context != null) 'context': context,
      if (topic != null) 'topic': topic,
      if (exam != null) 'exam': exam,
      if (level != null) 'level': level,
      if (history != null) 'history': history,
      if (sources != null) 'sources': sources,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateImage({
    required String type,
    required String topic,
    String? description,
    String? exam,
    String? level,
    String? size,
  }) async {
    final r = await _dio.post('/ai/generate-image', data: {
      'type': type,
      'topic': topic,
      if (description != null) 'description': description,
      if (exam != null) 'exam': exam,
      if (level != null) 'level': level,
      if (size != null) 'size': size,
    });
    return r.data as Map<String, dynamic>;
  }

  /// Decode a base64 data URI from the image generation API to raw bytes.
  Uint8List decodeImageDataUri(String dataUri) {
    final commaIdx = dataUri.indexOf(',');
    final b64 = commaIdx >= 0 ? dataUri.substring(commaIdx + 1) : dataUri;
    return base64Decode(b64);
  }

  // ============================================================
  // Material Bank (/api/materials/*)
  // ============================================================

  Future<List<Map<String, dynamic>>> listPackages({String? examType, String? productLine}) async {
    final r = await _dio.get('/materials/packages', queryParameters: {
      if (examType != null) 'exam_type': examType,
      if (productLine != null) 'product_line': productLine,
    });
    return (r.data['packages'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getPackage(String packageId) async {
    final r = await _dio.get('/materials/packages/$packageId');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listQuestions({
    String? packageId,
    String? examType,
    String? part,
    String? section,
    String? cefrLevel,
    String? skillTag,
    int limit = 50,
    int offset = 0,
  }) async {
    final r = await _dio.get('/materials/questions', queryParameters: {
      if (packageId != null) 'package_id': packageId,
      if (examType != null) 'exam_type': examType,
      if (part != null) 'part': part,
      if (section != null) 'section': section,
      if (cefrLevel != null) 'cefr_level': cefrLevel,
      if (skillTag != null) 'skill_tag': skillTag,
      'limit': limit,
      'offset': offset,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getQuestion(String questionId) async {
    final r = await _dio.get('/materials/questions/$questionId');
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listSkills({String? examType}) async {
    final r = await _dio.get('/materials/skills', queryParameters: {
      if (examType != null) 'exam_type': examType,
    });
    return (r.data['skills'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> searchQuestions(String query, {String? examType}) async {
    final r = await _dio.get('/materials/search', queryParameters: {
      'q': query,
      if (examType != null) 'exam_type': examType,
    });
    return (r.data['questions'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> recordAnswer({
    required String questionId,
    required String studentAnswer,
    required bool isCorrect,
    int? timeSpentSeconds,
    String? classroomId,
  }) async {
    final r = await _dio.post('/materials/answers', data: {
      'question_id': questionId,
      'student_answer': studentAnswer,
      'is_correct': isCorrect,
      if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
      if (classroomId != null) 'classroom_id': classroomId,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStudentAnswers(String studentId) async {
    final r = await _dio.get('/materials/answers/$studentId');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getClassroomProgress(String classroomId) async {
    final r = await _dio.get('/materials/progress/$classroomId');
    return r.data as Map<String, dynamic>;
  }

  // ============================================================
  // Parent Reports (/api/reports/*)
  // ============================================================

  Future<Map<String, dynamic>> generateReport({
    required String studentId,
    String? classroomId,
    String? reportType,
    String? periodStart,
    String? periodEnd,
  }) async {
    final r = await _dio.post('/reports/generate', data: {
      'student_id': studentId,
      if (classroomId != null) 'classroom_id': classroomId,
      if (reportType != null) 'report_type': reportType,
      if (periodStart != null) 'period_start': periodStart,
      if (periodEnd != null) 'period_end': periodEnd,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listReports({String? studentId, String? classroomId}) async {
    final r = await _dio.get('/reports', queryParameters: {
      if (studentId != null) 'student_id': studentId,
      if (classroomId != null) 'classroom_id': classroomId,
    });
    return (r.data['reports'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getReport(String reportId) async {
    final r = await _dio.get('/reports/$reportId');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendReport(String reportId, {required String parentEmail, String? parentName}) async {
    final r = await _dio.post('/reports/$reportId/send', data: {
      'parent_email': parentEmail,
      if (parentName != null) 'parent_name': parentName,
    });
    return r.data as Map<String, dynamic>;
  }
}

/// Riverpod provider for MindBoardApi. Uses the shared Dio instance from
/// ApiClient.create() which attaches the auth token via interceptor.
final mindBoardApiProvider = Provider<MindBoardApi>((ref) {
  return MindBoardApi(ApiClient.create());
});