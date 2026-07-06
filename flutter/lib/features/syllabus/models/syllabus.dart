/// Syllabus domain models — match backend service `services/syllabus.ts`.

import 'labels.dart';

/// Top-level syllabus owned by a teacher. Holds ordered items via [SyllabusItem].
class Syllabus {
  final String id;
  final String teacherId;
  final String? classroomId;
  final String name;
  final String? description;
  final String? targetExam; // TOEFL_IBT | TOEFL_ITP | IELTS | TOEIC | GENERAL
  final bool isTemplate;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Syllabus({
    required this.id,
    required this.teacherId,
    required this.classroomId,
    required this.name,
    required this.description,
    required this.targetExam,
    required this.isTemplate,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Syllabus.fromJson(Map<String, dynamic> json) => Syllabus(
        id: json['id'] as String,
        teacherId: json['teacher_id'] as String,
        classroomId: json['classroom_id'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        targetExam: json['target_exam'] as String?,
        isTemplate: json['is_template'] as bool? ?? false,
        isPublished: json['is_published'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'teacher_id': teacherId,
        'classroom_id': classroomId,
        'name': name,
        'description': description,
        'target_exam': targetExam,
        'is_template': isTemplate,
        'is_published': isPublished,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Syllabus copyWith({String? name, String? description, String? targetExam, bool? isPublished}) =>
      Syllabus(
        id: id,
        teacherId: teacherId,
        classroomId: classroomId,
        name: name ?? this.name,
        description: description ?? this.description,
        targetExam: targetExam ?? this.targetExam,
        isTemplate: isTemplate,
        isPublished: isPublished ?? this.isPublished,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/// A single learning unit placed inside a syllabus column (week/unit).
class SyllabusItem {
  /// Local-only identifier used during editing. New items from the catalog
  /// get a temp id (`catalog:<source>:<materialId>`) until they're saved.
  final String id;
  final String syllabusId;
  final int sortOrder;
  final String sourceType; // platform_ibt, edubot, teacher_custom, ...
  final String? sourceMaterialId;
  final String? sourcePlatformUrl;
  final String title;
  final String? description;
  final String itemType; // reading | listening | speaking | writing | grammar | vocab | mock_test | video | live_class | review | assignment | diagnostic
  final String? section;
  final String? difficulty; // A1..C2
  final int? estimatedMinutes;
  final String? flavorTag; // bitter | sweet | umami | spicy | cooling
  final String? temperatureTag; // hot | cold
  final DateTime? unlockedAt;

  // ----- Planka-style client-only fields (not persisted to backend yet) -----
  /// IDs of [SyllabusLabel]s applied to this item.
  final List<String> labelIds;
  /// Comments threaded on this item.
  final List<SyllabusComment> comments;
  /// Attachments (file/url) on this item.
  final List<SyllabusAttachment> attachments;

  const SyllabusItem({
    required this.id,
    required this.syllabusId,
    required this.sortOrder,
    required this.sourceType,
    required this.sourceMaterialId,
    required this.sourcePlatformUrl,
    required this.title,
    required this.description,
    required this.itemType,
    required this.section,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.flavorTag,
    required this.temperatureTag,
    required this.unlockedAt,
    this.labelIds = const [],
    this.comments = const [],
    this.attachments = const [],
  });

  factory SyllabusItem.fromJson(Map<String, dynamic> json) => SyllabusItem(
        id: json['id'] as String,
        syllabusId: json['syllabus_id'] as String,
        sortOrder: json['sort_order'] as int,
        sourceType: json['source_type'] as String,
        sourceMaterialId: json['source_material_id'] as String?,
        sourcePlatformUrl: json['source_platform_url'] as String?,
        title: json['title'] as String,
        description: json['description'] as String?,
        itemType: json['item_type'] as String,
        section: json['section'] as String?,
        difficulty: json['difficulty'] as String?,
        estimatedMinutes: json['estimated_minutes'] as int?,
        flavorTag: json['flavor_tag'] as String?,
        temperatureTag: json['temperature_tag'] as String?,
        unlockedAt: json['unlocked_at'] != null
            ? DateTime.parse(json['unlocked_at'] as String)
            : null,
      );

  /// JSON payload for `PUT /api/teacher/syllabi/:id/items` (no id / created_at).
  Map<String, dynamic> toSaveJson() => {
        'sort_order': sortOrder,
        'source_type': sourceType,
        'source_material_id': sourceMaterialId,
        'source_platform_url': sourcePlatformUrl,
        'title': title,
        'description': description,
        'item_type': itemType,
        'section': section,
        'difficulty': difficulty,
        'estimated_minutes': estimatedMinutes,
        'flavor_tag': flavorTag,
        'temperature_tag': temperatureTag,
        'unlocked_at': unlockedAt?.toIso8601String(),
      };

  SyllabusItem copyWith({
    int? sortOrder,
    String? title,
    String? description,
    int? estimatedMinutes,
    String? section,
    List<String>? labelIds,
    List<SyllabusComment>? comments,
    List<SyllabusAttachment>? attachments,
  }) =>
      SyllabusItem(
        id: id,
        syllabusId: syllabusId,
        sortOrder: sortOrder ?? this.sortOrder,
        sourceType: sourceType,
        sourceMaterialId: sourceMaterialId,
        sourcePlatformUrl: sourcePlatformUrl,
        title: title ?? this.title,
        description: description ?? this.description,
        itemType: itemType,
        section: section ?? this.section,
        difficulty: difficulty,
        estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
        flavorTag: flavorTag,
        temperatureTag: temperatureTag,
        unlockedAt: unlockedAt,
        labelIds: labelIds ?? this.labelIds,
        comments: comments ?? this.comments,
        attachments: attachments ?? this.attachments,
      );
}

/// Where a syllabus item originates from. Used for icon/color and the catalog.
enum CatalogSource {
  platformIbt('platform_ibt', 'TOEFL iBT', IconsType.assignment),
  platformItp('platform_itp', 'TOEFL ITP', IconsType.assignment),
  platformIelts('platform_ielts', 'IELTS', IconsType.assignment),
  platformToeic('platform_toeic', 'TOEIC', IconsType.assignment),
  edubot('edubot', 'EduBot', IconsType.smartToy),
  teacherCustom('teacher_custom', 'Custom Material', IconsType.uploadFile),
  aiGenerated('ai_generated', 'AI Generated', IconsType.autoAwesome),
  videoLesson('video_lesson', 'Video Lesson', IconsType.videoLibrary),
  liveClass('live_class', 'Live Class', IconsType.event);

  final String value;
  final String label;
  final IconsType icon;
  const CatalogSource(this.value, this.label, this.icon);
}

/// Tiny icon-name enum so the model file stays free of Material import
/// (the page maps these to actual IconData).
enum IconsType {
  assignment,
  smartToy,
  uploadFile,
  autoAwesome,
  videoLibrary,
  event,
}

/// A single entry in the material catalog (sidebar in the builder).
class CatalogEntry {
  final String sourceType; // matches CatalogSource.value
  final String materialId; // synthetic for catalog-only items
  final String title;
  final String? description;
  final String itemType; // reading | listening | ...
  final String? section;
  final String? difficulty;
  final int estimatedMinutes;

  const CatalogEntry({
    required this.sourceType,
    required this.materialId,
    required this.title,
    required this.description,
    required this.itemType,
    this.section,
    this.difficulty,
    this.estimatedMinutes = 20,
  });
}