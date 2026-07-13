import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/router.dart';

void main() {
  runApp(const ProviderScope(child: OseePrepHub()));
}

class OseePrepHub extends ConsumerWidget {
  const OseePrepHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return OseeApp(router: router);
  }
}
