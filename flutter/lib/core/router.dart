import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/models/user.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/register_page.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/landing/pages/landing_page.dart';
import '../features/student/pages/student_dashboard_page.dart';
import '../features/teacher/pages/teacher_dashboard_page.dart';
import '../features/teacher/pages/order_page.dart';
import '../features/teacher/pages/ai_grader_page.dart';
import '../features/teacher/pages/material_generator_page.dart';
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
      final path = state.path ?? '';
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
      GoRoute(path: '/student', builder: (c, s) => const StudentDashboardPage()),
      GoRoute(path: '/partner', builder: (c, s) => const PartnerDashboardPage()),
      GoRoute(path: '/ambassador', builder: (c, s) => const AmbassadorDashboardPage()),
      GoRoute(
        path: '/admin',
        builder: (c, s) => Scaffold(
          appBar: AppBar(title: const Text('Admin')),
          body: const Center(child: Text('Admin — use frontend-admin')),
        ),
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