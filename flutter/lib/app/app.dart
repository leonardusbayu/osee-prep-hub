import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:osee_prep_hub/l10n/app_localizations.dart';
import 'theme.dart';

/// Root MaterialApp with go_router + Riverpod scope + i18n (Task 4 Wave 1).
class OseeApp extends ConsumerWidget {
  const OseeApp({super.key, required this.router, this.locale = const Locale('en')});

  final GoRouter router;
  final Locale locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'OSEE Prep Hub',
      theme: OseeTheme.light(),
      darkTheme: OseeTheme.dark(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('id')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}