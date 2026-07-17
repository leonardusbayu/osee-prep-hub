@TestOn('browser')
import 'package:flutter_test/flutter_test.dart';

import 'package:osee_prep_hub/features/student/pages/student_dashboard_page.dart';
import 'package:osee_prep_hub/features/student/pages/student_syllabus_page.dart';
import 'package:osee_prep_hub/features/student/pages/student_progress_page.dart';
import 'package:osee_prep_hub/features/student/pages/readiness_page.dart';
import 'package:osee_prep_hub/features/student/pages/video_lessons_page.dart';
import 'package:osee_prep_hub/features/student/pages/live_classes_page.dart';
import 'package:osee_prep_hub/features/student/pages/cross_exam_page.dart';
import 'package:osee_prep_hub/features/student/pages/book_test_page.dart';
import 'package:osee_prep_hub/features/partner/pages/partner_dashboard_page.dart';
import 'package:osee_prep_hub/features/admin/pages/admin_page.dart';
import 'package:osee_prep_hub/features/ambassador/pages/ambassador_dashboard_page.dart';
import 'package:osee_prep_hub/features/ambassador/pages/ambassador_recruitment_page.dart';

/// Construction smoke tests for student, partner, admin, and ambassador pages.
///
/// These assert each page's constructor builds a non-null instance — i.e.
/// class hierarchy, imports, and required parameters all resolve. Pages that
/// make network calls on initState are tested at the construction level
/// because the flutter_test VM runner leaves pending timers from dio that
/// hang the binding. (Render-level tests for non-network pages live in
/// auth_pages_test.dart.)
void main() {
  group('student portal pages construct without throwing', () {
    test('StudentDashboardPage', () {
      expect(const StudentDashboardPage(), isNotNull);
    });
    test('StudentSyllabusPage', () {
      expect(const StudentSyllabusPage(), isNotNull);
    });
    test('StudentProgressPage', () {
      expect(const StudentProgressPage(), isNotNull);
    });
    test('ReadinessPage', () {
      expect(const ReadinessPage(), isNotNull);
    });
    test('VideoLessonsPage', () {
      expect(const VideoLessonsPage(), isNotNull);
    });
    test('LiveClassesPage', () {
      expect(const LiveClassesPage(), isNotNull);
    });
    test('CrossExamPage', () {
      expect(const CrossExamPage(), isNotNull);
    });
    test('BookTestPage', () {
      expect(const BookTestPage(), isNotNull);
    });
  });

  group('partner + admin + ambassador pages construct without throwing', () {
    test('PartnerDashboardPage', () {
      expect(const PartnerDashboardPage(), isNotNull);
    });
    test('AdminPage', () {
      expect(const AdminPage(), isNotNull);
    });
    test('AmbassadorDashboardPage', () {
      expect(const AmbassadorDashboardPage(), isNotNull);
    });
    test('AmbassadorRecruitmentPage', () {
      expect(const AmbassadorRecruitmentPage(), isNotNull);
    });
  });
}