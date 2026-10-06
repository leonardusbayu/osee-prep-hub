import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

/// AI grader input payload.
class AiGradingInput {
  const AiGradingInput({
    required this.essay,
    required this.rubric,
    required this.examType,
    this.level,
  });

  final String essay;
  final String rubric;
  final String examType;
  final String? level;

  Map<String, dynamic> toJson() => {
    'essay': essay,
    'rubric': rubric,
    'examType': examType,
    if (level != null) 'level': level,
  };
}

/// AI grader result.
class AiGradingResult {
  const AiGradingResult({
    required this.score,
    required this.band,
    required this.feedback,
    required this.criteriaScores,
    required this.improvements,
  });

  final double score;
  final String band;
  final String feedback;
  final List<Map<String, dynamic>> criteriaScores;
  final List<String> improvements;

  factory AiGradingResult.fromJson(Map<String, dynamic> json) {
    return AiGradingResult(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      band: json['band'] as String? ?? '',
      feedback: json['feedback'] as String? ?? '',
      criteriaScores: ((json['criteria_scores'] as List<dynamic>?) ?? [])
          .cast<Map<String, dynamic>>(),
      improvements: ((json['improvements'] as List<dynamic>?) ?? [])
          .cast<String>(),
    );
  }
}

/// Result of a queued grading job.
final aiGradingResultProvider = FutureProvider.family
    .autoDispose<AiGradingResult, AiGradingInput>((ref, input) async {
      final dio = ApiClient.create();
      final res = await dio.post('/ai/grade-writing', data: input.toJson());
      return AiGradingResult.fromJson(res.data as Map<String, dynamic>);
    });

/// State for the AI grader page (essay + config).
class AiGraderState {
  const AiGraderState({
    this.essay = '',
    this.rubric = 'ielts_task2',
    this.examType = 'IELTS',
    this.level = 'B2',
  });

  final String essay;
  final String rubric;
  final String examType;
  final String level;

  AiGraderState copyWith({
    String? essay,
    String? rubric,
    String? examType,
    String? level,
  }) => AiGraderState(
    essay: essay ?? this.essay,
    rubric: rubric ?? this.rubric,
    examType: examType ?? this.examType,
    level: level ?? this.level,
  );
}

final aiGraderStateProvider = StateProvider<AiGraderState>(
  (ref) => const AiGraderState(),
);

/// Trigger grading as a stateful operation so the UI can show loading/error states.
class AiGraderNotifier extends StateNotifier<AsyncValue<AiGradingResult?>> {
  AiGraderNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<bool> grade() async {
    final config = ref.read(aiGraderStateProvider);
    if (config.essay.trim().isEmpty) return false;
    state = const AsyncValue.loading();
    try {
      final dio = ApiClient.create();
      final res = await dio.post('/ai/grade-writing', data: config.toJson());
      final result = AiGradingResult.fromJson(res.data as Map<String, dynamic>);
      state = AsyncValue.data(result);
      return true;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      return false;
    }
  }
}

final aiGraderNotifierProvider =
    StateNotifierProvider<AiGraderNotifier, AsyncValue<AiGradingResult?>>((
      ref,
    ) {
      return AiGraderNotifier(ref);
    });
