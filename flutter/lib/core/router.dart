import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/models/user.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/register_page.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/landing/pages/landing_page.dart';
import '../features/student/pages/student_dashboard_page.dart';
import '../features/student/pages/student_progress_page.dart';
import '../features/student/pages/student_syllabus_page.dart';
import '../features/student/pages/readiness_page.dart';
import '../features/student/pages/video_lessons_page.dart';
import '../features/student/pages/live_classes_page.dart';
import '../features/student/pages/cross_exam_page.dart';
import '../features/student/pages/book_test_page.dart';
import '../features/student/widgets/student_shell.dart';
import '../features/teacher/pages/teacher_dashboard_page.dart';
import '../features/teacher/pages/teacher_schedule_page.dart';
import '../features/teacher/pages/classrooms_page.dart';
import '../features/teacher/pages/classroom_detail_page.dart';
import '../features/teacher/pages/order_page.dart';
import '../features/teacher/pages/ai_grader_page.dart';
import '../features/teacher/pages/speaking_grader_page.dart';
import '../features/teacher/pages/material_generator_page.dart';
import '../features/teacher/pages/earnings_page.dart';
import '../features/teacher/pages/student_reports_page.dart';
import '../features/teacher/pages/classroom_report_page.dart';
import '../features/teacher/pages/settings_page.dart';
import '../features/teacher/pages/upgrade_page.dart';
import '../features/teacher/widgets/teacher_shell.dart';
import '../features/syllabus/pages/syllabus_list_page.dart';
import '../features/syllabus/pages/syllabus_builder_page.dart';
import '../features/partner/pages/partner_dashboard_page.dart';
import '../features/ambassador/pages/ambassador_dashboard_page.dart';
import '../features/ambassador/pages/ambassador_recruitment_page.dart';
import '../features/admin/pages/admin_page.dart';

/// App router — go_router with role-based auth guards (Task 1.8).
///
/// Teacher routes use a `StatefulShellRoute.indexedStack` so the sidebar +
/// topbar shell stays mounted (persistent state, no rebuild) while only the
/// body swaps during navigation.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path.isEmpty
          ? (state.path ?? '/')
          : state.uri.path;
      final isAuthRoute =
          path == '/login' ||
          path == '/register' ||
          path.startsWith('/r/') ||
          path == '/ambassador/join';

      if (!auth.isAuthenticated && !isAuthRoute) {
        return '/login';
      }
      if (auth.isAuthenticated && isAuthRoute && path != '/ambassador/join') {
        return _dashboardForRole(auth.user!.role);
      }
      if (auth.isAuthenticated) {
        final role = auth.user!.role;
        final onTeacherRoute = path.startsWith('/teacher');
        final onStudentRoute = path.startsWith('/student');
        final onPartnerRoute = path.startsWith('/partner');
        if ((onStudentRoute || onPartnerRoute) && role == UserRole.teacher)
          return '/teacher';
        if ((onTeacherRoute || onPartnerRoute) && role == UserRole.student)
          return '/student';
        if ((onTeacherRoute || onStudentRoute) && role == UserRole.partner)
          return '/partner';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (c, s) => const LandingPage()),
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterPage()),
      GoRoute(
        path: '/r/:code',
        builder: (c, s) => RegisterPage(referralCode: s.pathParameters['code']),
      ),

      // ---- Teacher: persistent shell (sidebar + topbar) ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            TeacherShell(navigationShell: navigationShell),
        branches: [
          // 0: /teacher — My Schedule (default landing)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher',
                builder: (c, s) => const TeacherSchedulePage(),
              ),
            ],
          ),
          // 1: /teacher/legacy — old dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/legacy',
                builder: (c, s) => const TeacherDashboardPage(),
              ),
            ],
          ),
          // 2: /teacher/orders
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/orders',
                builder: (c, s) => const OrderPage(),
              ),
            ],
          ),
          // 3: /teacher/schedule
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/schedule',
                builder: (c, s) => const TeacherSchedulePage(),
              ),
            ],
          ),
          // 4: /teacher/ai-grader
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/ai-grader',
                builder: (c, s) => const AiGraderPage(),
              ),
            ],
          ),
          // 5: /teacher/speaking-grader
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/speaking-grader',
                builder: (c, s) => const SpeakingGraderPage(),
              ),
            ],
          ),
          // 6: /teacher/generator
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/generator',
                builder: (c, s) => const MaterialGeneratorPage(),
              ),
            ],
          ),
          // 7: /teacher/syllabi
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/syllabi',
                builder: (c, s) => const SyllabusListPage(),
              ),
              GoRoute(
                path: '/teacher/syllabi/:id',
                builder: (c, s) =>
                    SyllabusBuilderPage(syllabusId: s.pathParameters['id']!),
              ),
            ],
          ),
          // 8: /teacher/classrooms
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/classrooms',
                builder: (c, s) => const ClassroomsPage(),
              ),
              GoRoute(
                path: '/teacher/classrooms/:id',
                builder: (c, s) =>
                    ClassroomDetailPage(classroomId: s.pathParameters['id']!),
              ),
              GoRoute(
                path: '/teacher/classrooms/:id/report',
                builder: (c, s) => ClassroomReportPage(
                    classroomId: s.pathParameters['id']!),
              ),
            ],
          ),
          // 9: /teacher/commission
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/commission',
                builder: (c, s) => const EarningsPage(),
              ),
            ],
          ),
          // 10: /teacher/reports
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/reports',
                builder: (c, s) => const StudentReportsPage(),
              ),
            ],
          ),
          // 11: /teacher/settings
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/settings',
                builder: (c, s) => const SettingsPage(),
              ),
            ],
          ),
          // 12: /teacher/upgrade
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/upgrade',
                builder: (c, s) => const UpgradePage(),
              ),
            ],
          ),
        ],
      ),

      // ---- Student: persistent shell (sidebar) ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            StudentShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student',
                builder: (c, s) => const StudentDashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/progress',
                builder: (c, s) => const StudentProgressPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/syllabus',
                builder: (c, s) => const StudentSyllabusPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/readiness',
                builder: (c, s) => const ReadinessPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/videos',
                builder: (c, s) => const VideoLessonsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/classes',
                builder: (c, s) => const LiveClassesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/cross-exam',
                builder: (c, s) => const CrossExamPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/book-test',
                builder: (c, s) => const BookTestPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/partner',
        builder: (c, s) => const PartnerDashboardPage(),
      ),
      GoRoute(
        path: '/ambassador',
        builder: (c, s) => const AmbassadorDashboardPage(),
      ),
      GoRoute(
        path: '/ambassador/join',
        builder: (c, s) => const AmbassadorRecruitmentPage(),
      ),
      GoRoute(path: '/admin', builder: (c, s) => const AdminPage()),
    ],
    errorBuilder: (c, s) =>
        Scaffold(body: Center(child: Text('Not found: ${s.path}'))),
  );
});

String _dashboardForRole(UserRole role) {
  switch (role) {
    case UserRole.teacher:
      return '/teacher';
    case UserRole.student:
      return '/student';
    case UserRole.partner:
      return '/partner';
    case UserRole.admin:
      return '/admin';
  }
}