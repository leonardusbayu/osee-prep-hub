/// Planka-style labels for syllabus items. A label has a color + name and
/// can be applied to many items (e.g. "Speaking", "Mock", "B2", "Group work").
class SyllabusLabel {
  final String id;
  final String name;
  final int color; // RGB hex int, e.g. 0xFFE63946

  const SyllabusLabel({required this.id, required this.name, required this.color});

  factory SyllabusLabel.fromJson(Map<String, dynamic> j) =>
      SyllabusLabel(id: j['id'] as String, name: j['name'] as String, color: j['color'] as int);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  static const preset = <SyllabusLabel>[
    SyllabusLabel(id: 'reading', name: 'Reading', color: 0xFF4F8DE0),
    SyllabusLabel(id: 'listening', name: 'Listening', color: 0xFFA66BD6),
    SyllabusLabel(id: 'speaking', name: 'Speaking', color: 0xFFE5913D),
    SyllabusLabel(id: 'writing', name: 'Writing', color: 0xFF5BA674),
    SyllabusLabel(id: 'grammar', name: 'Grammar', color: 0xFFE0B04F),
    SyllabusLabel(id: 'vocab', name: 'Vocabulary', color: 0xFF4FA6A0),
    SyllabusLabel(id: 'mock', name: 'Mock Test', color: 0xFFD65F5F),
    SyllabusLabel(id: 'video', name: 'Video', color: 0xFF7A6BD6),
    SyllabusLabel(id: 'live', name: 'Live Class', color: 0xFFE07AA4),
    SyllabusLabel(id: 'diagnostic', name: 'Diagnostic', color: 0xFF4FB6CC),
    SyllabusLabel(id: 'review', name: 'Review', color: 0xFF8C8C8C),
    SyllabusLabel(id: 'assignment', name: 'Assignment', color: 0xFFB58C4F),
  ];

  static SyllabusLabel? byId(String id) {
    for (final l in preset) {
      if (l.id == id) return l;
    }
    return null;
  }
}

/// Planka-style comment on a syllabus item.
class SyllabusComment {
  final String id;
  final String itemId;
  final String authorId;
  final String? authorName;
  final String text;
  final DateTime createdAt;

  const SyllabusComment({
    required this.id,
    required this.itemId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  factory SyllabusComment.fromJson(Map<String, dynamic> j) => SyllabusComment(
        id: j['id'] as String,
        itemId: j['item_id'] as String,
        authorId: j['author_id'] as String,
        authorName: j['author_name'] as String?,
        text: j['text'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_id': itemId,
        'author_id': authorId,
        'author_name': authorName,
        'text': text,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Planka-style attachment on a syllabus item (file, link, or deep-link).
class SyllabusAttachment {
  final String id;
  final String itemId;
  final String url;
  final String? filename;
  final String? mimeType;
  final int? sizeBytes;
  final DateTime createdAt;

  const SyllabusAttachment({
    required this.id,
    required this.itemId,
    required this.url,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory SyllabusAttachment.fromJson(Map<String, dynamic> j) => SyllabusAttachment(
        id: j['id'] as String,
        itemId: j['item_id'] as String,
        url: j['url'] as String,
        filename: j['filename'] as String?,
        mimeType: j['mime_type'] as String?,
        sizeBytes: j['size_bytes'] as int?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'item_id': itemId,
        'url': url,
        'filename': filename,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'created_at': createdAt.toIso8601String(),
      };
}