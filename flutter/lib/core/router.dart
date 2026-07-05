import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// App router — go_router with placeholder routes.
///
/// Task 1.8 will add full role-based redirect logic.
/// For now, this provides the route structure with placeholder pages
/// so the app builds and router initializes correctly.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const _Placeholder(title: 'Login'),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const _Placeholder(title: 'Register'),
      ),
      GoRoute(
        path: '/teacher',
        builder: (context, state) => const _Placeholder(title: 'Teacher Dashboard'),
      ),
      GoRoute(
        path: '/student',
        builder: (context, state) => const _Placeholder(title: 'Student Dashboard'),
      ),
      GoRoute(
        path: '/partner',
        builder: (context, state) => const _Placeholder(title: 'Partner Dashboard'),
      ),
    ],
  );
});

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            Text(
              'Placeholder — implemented in subsequent tasks',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}