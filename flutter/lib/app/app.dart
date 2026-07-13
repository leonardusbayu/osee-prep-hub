import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';

/// Root MaterialApp with go_router + Riverpod scope.
class OseeApp extends ConsumerWidget {
  const OseeApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'OSEE Prep Hub',
      theme: OseeTheme.light(),
      darkTheme: OseeTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
