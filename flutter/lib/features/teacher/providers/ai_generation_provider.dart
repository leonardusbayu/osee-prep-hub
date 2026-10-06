import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

/// AI material generation request payload.
class AiGenerationInput {
  const AiGenerationInput({
    required this.type,
    required this.exam,
    required this.level,
    required this.topic,
    this.wordCount,
    this.questionCount,
    this.difficulty,
  });

  final String type;
  final String exam;
  final String level;
  final String topic;
  final int? wordCount;
  final int? questionCount;
  final String? difficulty;

  Map<String, dynamic> toJson() => {
    'type': type,
    'exam': exam,
    'level': level,
    'topic': topic,
    if (wordCount != null)
      'options': <String, dynamic>{
        'word_count': wordCount,
        if (questionCount != null) 'question_count': questionCount,
        if (difficulty != null) 'difficulty': difficulty,
      },
  };
}

/// AI generation result.
class AiGenerationResult {
  const AiGenerationResult({
    required this.type,
    required this.exam,
    required this.level,
    required this.topic,
    required this.content,
    this.ragContextUsed = 0,
  });

  final String type;
  final String exam;
  final String level;
  final String topic;
  final Map<String, dynamic> content;
  final int ragContextUsed;

  factory AiGenerationResult.fromJson(Map<String, dynamic> json) {
    return AiGenerationResult(
      type: json['type'] as String? ?? '',
      exam: json['exam'] as String? ?? '',
      level: json['level'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      content: (json['content'] as Map<String, dynamic>?) ?? {},
      ragContextUsed: (json['rag_context_used'] as num?)?.toInt() ?? 0,
    );
  }
}

/// State for the material generator page.
class AiGeneratorState {
  const AiGeneratorState({
    this.type = 'reading',
    this.exam = 'IELTS',
    this.level = 'B2',
    this.topic = '',
    this.wordCount,
    this.questionCount,
    this.difficulty,
  });

  final String type;
  final String exam;
  final String level;
  final String topic;
  final int? wordCount;
  final int? questionCount;
  final String? difficulty;

  AiGeneratorState copyWith({
    String? type,
    String? exam,
    String? level,
    String? topic,
    int? wordCount,
    int? questionCount,
    String? difficulty,
  }) => AiGeneratorState(
    type: type ?? this.type,
    exam: exam ?? this.exam,
    level: level ?? this.level,
    topic: topic ?? this.topic,
    wordCount: wordCount ?? this.wordCount,
    questionCount: questionCount ?? this.questionCount,
    difficulty: difficulty ?? this.difficulty,
  );
}

final aiGeneratorStateProvider = StateProvider<AiGeneratorState>(
  (ref) => const AiGeneratorState(),
);

class AiGeneratorNotifier
    extends StateNotifier<AsyncValue<AiGenerationResult?>> {
  AiGeneratorNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<bool> generate() async {
    final config = ref.read(aiGeneratorStateProvider);
    if (config.topic.trim().isEmpty) return false;
    state = const AsyncValue.loading();
    try {
      final dio = ApiClient.create();
      final res = await dio.post(
        '/ai/generate-material',
        data: config.toJson(),
      );
      final result = AiGenerationResult.fromJson(
        res.data as Map<String, dynamic>,
      );
      state = AsyncValue.data(result);
      return true;
    } catch (err, st) {
      state = AsyncValue.error(err, st);
      return false;
    }
  }
}

final aiGeneratorNotifierProvider =
    StateNotifierProvider<AiGeneratorNotifier, AsyncValue<AiGenerationResult?>>(
      (ref) {
        return AiGeneratorNotifier(ref);
      },
    );
