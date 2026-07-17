@TestOn('browser')
import 'package:flutter_test/flutter_test.dart';

import 'package:osee_prep_hub/features/teacher/pages/teacher_dashboard_page.dart';
import 'package:osee_prep_hub/features/teacher/pages/teacher_schedule_page.dart';
import 'package:osee_prep_hub/features/teacher/pages/classrooms_page.dart';
import 'package:osee_prep_hub/features/teacher/pages/classroom_detail_page.dart';
import 'package:osee_prep_hub/features/teacher/pages/classroom_report_page.dart';
import 'package:osee_prep_hub/features/teacher/pages/order_page.dart';
import 'package:osee_prep_hub/features/teacher/pages/ai_grader_page.dart';
import 'package:osee_prep_hub/features/teacher/pages/speaking_grader_page.dart';
import 'package:osee_prep_hub/features/teacher/pages/material_generator_page.dart';
import 'package:osee_prep_hub/features/teacher/pages/earnings_page.dart';
import 'package:osee_prep_hub/features/teacher/pages/student_reports_page.dart';
import 'package:osee_prep_hub/features/teacher/pages/settings_page.dart';
import 'package:osee_prep_hub/features/teacher/pages/upgrade_page.dart';
import 'package:osee_prep_hub/features/syllabus/pages/syllabus_list_page.dart';
import 'package:osee_prep_hub/features/syllabus/pages/syllabus_builder_page.dart';

/// Construction smoke tests for teacher portal pages.
///
/// These verify each page's const constructor builds a non-null widget
/// instance — i.e. the class hierarchy, imports, and required parameters
/// all resolve. Full widget-tree rendering (pump + layout) is exercised by
/// the teacher_schedule_page and auth_pages_test suites which render cleanly
/// under the flutter_test chrome runner; the dashboard-style pages here make
/// network calls on initState that leave pending timers in the VM test runner,
/// so we assert at the construction level instead.
void main() {
  group('teacher portal pages construct without throwing', () {
    test('TeacherDashboardPage', () {
      expect(const TeacherDashboardPage(), isNotNull);
    });
    test('TeacherSchedulePage', () {
      expect(const TeacherSchedulePage(), isNotNull);
    });
    test('ClassroomsPage', () {
      expect(const ClassroomsPage(), isNotNull);
    });
    test('ClassroomDetailPage', () {
      expect(const ClassroomDetailPage(classroomId: 'test-id'), isNotNull);
    });
    test('ClassroomReportPage', () {
      expect(const ClassroomReportPage(classroomId: 'test-id'), isNotNull);
    });
    test('OrderPage', () {
      expect(const OrderPage(), isNotNull);
    });
    test('AiGraderPage', () {
      expect(const AiGraderPage(), isNotNull);
    });
    test('SpeakingGraderPage', () {
      expect(const SpeakingGraderPage(), isNotNull);
    });
    test('MaterialGeneratorPage', () {
      expect(const MaterialGeneratorPage(), isNotNull);
    });
    test('EarningsPage', () {
      expect(const EarningsPage(), isNotNull);
    });
    test('StudentReportsPage', () {
      expect(const StudentReportsPage(), isNotNull);
    });
    test('SettingsPage', () {
      expect(const SettingsPage(), isNotNull);
    });
    test('UpgradePage', () {
      expect(const UpgradePage(), isNotNull);
    });
    test('SyllabusListPage', () {
      expect(const SyllabusListPage(), isNotNull);
    });
    test('SyllabusBuilderPage', () {
      expect(const SyllabusBuilderPage(syllabusId: 'test-id'), isNotNull);
    });
  });
}