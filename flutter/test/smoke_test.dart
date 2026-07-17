import 'package:flutter_test/flutter_test.dart';

import 'package:osee_prep_hub/features/auth/models/user.dart';
import 'package:osee_prep_hub/features/syllabus/models/syllabus.dart';

/// VM-safe smoke tests — no web interop imports, run on the Dart VM.
/// These verify core domain model serialization (fromJson/toJson round-trips)
/// which is a real regression guard, not a placeholder arithmetic test.
void main() {
  group('User model serialization', () {
    test('fromJson → toJson round-trips losslessly', () {
      const original = User(
        id: 'u1',
        email: 'budi@example.com',
        displayName: 'Budi Santoso',
        role: UserRole.student,
        avatarUrl: 'https://img.example.com/a.png',
        telegramId: '@budi',
        targetExam: 'IELTS',
        currentLevel: 'B2',
        teacherInstitution: null,
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-02T00:00:00Z',
      );
      final json = original.toJson();
      final rebuilt = User.fromJson(json);
      expect(rebuilt.id, original.id);
      expect(rebuilt.email, original.email);
      expect(rebuilt.displayName, original.displayName);
      expect(rebuilt.role, original.role);
      expect(rebuilt.avatarUrl, original.avatarUrl);
      expect(rebuilt.telegramId, original.telegramId);
      expect(rebuilt.targetExam, original.targetExam);
      expect(rebuilt.currentLevel, original.currentLevel);
      expect(rebuilt.createdAt, original.createdAt);
      expect(rebuilt.updatedAt, original.updatedAt);
    });

    test('UserRole.fromString maps known roles', () {
      expect(UserRole.fromString('student'), UserRole.student);
      expect(UserRole.fromString('teacher'), UserRole.teacher);
      expect(UserRole.fromString('partner'), UserRole.partner);
      expect(UserRole.fromString('admin'), UserRole.admin);
    });

    test('UserRole.fromString defaults to student for unknown/null', () {
      expect(UserRole.fromString(null), UserRole.student);
      expect(UserRole.fromString('unknown'), UserRole.student);
    });

    test('UserRole.label renders human-readable names', () {
      expect(UserRole.student.label, 'Student');
      expect(UserRole.teacher.label, 'Teacher');
      expect(UserRole.partner.label, 'Partner (Institution)');
      expect(UserRole.admin.label, 'Admin');
    });
  });

  group('SyllabusItem model serialization', () {
    test('fromJson parses label_ids from backend', () {
      final item = SyllabusItem.fromJson({
        'id': 'item-1',
        'syllabus_id': 'syl-1',
        'sort_order': 3,
        'source_type': 'teacher_custom',
        'source_material_id': null,
        'source_platform_url': 'https://ibt.osee.co.id/ex/1',
        'title': 'Reading Basics',
        'description': 'Foundation reading',
        'item_type': 'reading',
        'section': 'reading',
        'difficulty': 'B1',
        'estimated_minutes': 30,
        'flavor_tag': 'sweet',
        'temperature_tag': 'cold',
        'unlocked_at': null,
        'label_ids': ['important', 'review'],
      });
      expect(item.id, 'item-1');
      expect(item.sortOrder, 3);
      expect(item.sourceType, 'teacher_custom');
      expect(item.title, 'Reading Basics');
      expect(item.itemType, 'reading');
      expect(item.difficulty, 'B1');
      expect(item.labelIds, ['important', 'review']);
    });

    test('fromJson handles missing label_ids (empty default)', () {
      final item = SyllabusItem.fromJson({
        'id': 'i2',
        'syllabus_id': 's2',
        'sort_order': 0,
        'source_type': 'edubot',
        'source_material_id': null,
        'source_platform_url': null,
        'title': 'X',
        'description': null,
        'item_type': 'grammar',
        'section': null,
        'difficulty': null,
        'estimated_minutes': null,
        'flavor_tag': null,
        'temperature_tag': null,
        'unlocked_at': null,
      });
      expect(item.labelIds, isEmpty);
    });

    test('toSaveJson includes label_ids for backend persistence', () {
      const item = SyllabusItem(
        id: 'i3',
        syllabusId: 's3',
        sortOrder: 1,
        sourceType: 'ai_generated',
        sourceMaterialId: 'm1',
        sourcePlatformUrl: null,
        title: 'AI Material',
        description: 'gen',
        itemType: 'writing',
        section: 'writing',
        difficulty: 'C1',
        estimatedMinutes: 45,
        flavorTag: 'spicy',
        temperatureTag: 'hot',
        unlockedAt: null,
        labelIds: ['important'],
      );
      final json = item.toSaveJson();
      expect(json['label_ids'], ['important']);
      expect(json['sort_order'], 1);
      expect(json['source_type'], 'ai_generated');
      expect(json['item_type'], 'writing');
    });
  });

  group('CatalogEntry model', () {
    test('constructs with required fields', () {
      const entry = CatalogEntry(
        sourceType: 'platform_ibt',
        materialId: 'ibt-reading-1',
        title: 'iBT Reading 1',
        description: 'Reading passage',
        itemType: 'reading',
        section: 'reading',
        difficulty: 'B2',
        estimatedMinutes: 30,
      );
      expect(entry.sourceType, 'platform_ibt');
      expect(entry.materialId, 'ibt-reading-1');
      expect(entry.itemType, 'reading');
      expect(entry.estimatedMinutes, 30);
    });

    test('uses default estimatedMinutes when omitted', () {
      const entry = CatalogEntry(
        sourceType: 'video',
        materialId: 'v1',
        title: 'Video Lesson',
        description: null,
        itemType: 'video',
      );
      expect(entry.estimatedMinutes, 20);
    });
  });
}
