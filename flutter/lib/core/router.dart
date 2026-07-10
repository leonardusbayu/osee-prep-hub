import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/models/user.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/register_page.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/landing/pages/landing_page.dart';
import '../features/admin/pages/insight_page.dart';
import '../features/public/verify_credential_page.dart';
import '../features/student/pages/coach_page.dart';
import '../features/student/pages/passport_page.dart';
import '../features/student/pages/student_dashboard_page.dart';
import '../features/student/pages/student_syllabus_page.dart';
import '../features/student/pages/student_profile_page.dart';
import '../features/student/pages/student_practice_page.dart';
import '../features/teacher/pages/teacher_dashboard_page.dart';
import '../features/teacher/pages/order_page.dart';
import '../features/teacher/pages/ai_grader_page.dart';
import '../features/teacher/pages/material_generator_page.dart';
import '../features/syllabus/pages/syllabus_list_page.dart';
import '../features/syllabus/pages/syllabus_builder_page.dart';
import '../features/syllabus/pages/syllabus_assign_page.dart';
import '../features/teacher/pages/mind_map_recipe_page.dart';
import '../features/teacher/pages/material_bank_page.dart';
import '../features/teacher/pages/studio_page.dart';
import '../features/student/pages/live_class_page.dart';
import '../features/teacher/pages/student_progress_page.dart';
import '../features/partner/pages/partner_dashboard_page.dart';
import '../features/ambassador/pages/ambassador_dashboard_page.dart';

/// App router — go_router with role-based auth guards (Task 1.8).
///
/// Redirect logic:
/// - Unauthenticated + protected route → /login
/// - Authenticated + /login or /register → dashboard (role-based)
/// - Role mismatch (e.g. teacher on /student) → own dashboard
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      // In go_router v14 hash-mode, `state.path` is empty for hash routes.
      // Use `state.uri.path` which is the reliable cross-mode source of truth.
      final path = state.uri.path.isEmpty ? (state.path ?? '/') : state.uri.path;
      final isAuthRoute = path == '/login' || path == '/register' || path.startsWith('/r/');

      // Unauthenticated → /login (except auth routes)
      if (!auth.isAuthenticated && !isAuthRoute) {
        return '/login';
      }
      // Authenticated on auth route → dashboard
      if (auth.isAuthenticated && isAuthRoute) {
        return _dashboardForRole(auth.user!.role);
      }
      // Role mismatch — redirect to own dashboard
      if (auth.isAuthenticated) {
        final role = auth.user!.role;
        final onTeacherRoute = path.startsWith('/teacher');
        final onStudentRoute = path.startsWith('/student');
        final onPartnerRoute = path.startsWith('/partner');
        if ((onStudentRoute || onPartnerRoute) && role == UserRole.teacher) return '/teacher';
        if ((onTeacherRoute || onPartnerRoute) && role == UserRole.student) return '/student';
        if ((onTeacherRoute || onStudentRoute) && role == UserRole.partner) return '/partner';
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
      GoRoute(path: '/teacher', builder: (c, s) => const TeacherDashboardPage()),
      GoRoute(path: '/teacher/orders', builder: (c, s) => const OrderPage()),
      GoRoute(path: '/teacher/ai-grader', builder: (c, s) => const AiGraderPage()),
      GoRoute(path: '/teacher/generator', builder: (c, s) => const MaterialGeneratorPage()),
      GoRoute(path: '/teacher/syllabi', builder: (c, s) => const SyllabusListPage()),
      GoRoute(
        path: '/teacher/syllabi/:id',
        builder: (c, s) => SyllabusBuilderPage(syllabusId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/teacher/syllabi/:id/assign',
        builder: (c, s) => SyllabusAssignPage(syllabusId: s.pathParameters['id']!, syllabusName: s.uri.queryParameters['name'] ?? ''),
      ),
      GoRoute(
        path: '/teacher/syllabi/:id/recipe',
        builder: (c, s) => MindMapRecipePage(syllabusId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/student', builder: (c, s) => const StudentDashboardPage()),
      GoRoute(path: '/student/syllabus', builder: (c, s) => const StudentSyllabusPage()),
      GoRoute(path: '/student/profile', builder: (c, s) => const StudentProfilePage()),
      GoRoute(path: '/student/practice', builder: (c, s) => const StudentPracticePage()),
      GoRoute(path: '/student/coach', builder: (c, s) => const CoachPage()),
      GoRoute(path: '/student/passport', builder: (c, s) => const PassportPage()),
      GoRoute(
        path: '/verify/:credentialId',
        builder: (c, s) => VerifyCredentialPage(credentialId: s.pathParameters['credentialId']!),
      ),
      GoRoute(path: '/teacher/materials', builder: (c, s) => const MaterialBankPage()),
      GoRoute(path: '/teacher/progress/:classroomId', builder: (c, s) => StudentProgressPage(classroomId: s.pathParameters['classroomId']!)),
      GoRoute(path: '/partner', builder: (c, s) => const PartnerDashboardPage()),
      GoRoute(path: '/ambassador', builder: (c, s) => const AmbassadorDashboardPage()),
      GoRoute(
        path: '/admin',
        builder: (c, s) => Scaffold(
          appBar: AppBar(title: const Text('Admin')),
          body: const Center(child: Text('Admin — use frontend-admin')),
        ),
      ),
      GoRoute(path: '/insight', builder: (c, s) => const InsightPage()),
      GoRoute(
        path: '/teacher/studio/:syllabusId',
        builder: (c, s) => StudioPage(syllabusId: s.pathParameters['syllabusId']!),
      ),
      GoRoute(
        path: '/student/live-class/:classId',
        builder: (c, s) => LiveClassPage(classId: s.pathParameters['classId']!),
      ),
    ],
    errorBuilder: (c, s) => Scaffold(body: Center(child: Text('Not found: ${s.path}'))),
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