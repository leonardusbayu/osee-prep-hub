import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/api_client.dart';
import 'core/router.dart';
import 'features/auth/providers/auth_provider.dart';

void main() {
  // Create the container up-front so we can wire the global 401 handler
  // before the first frame. When any Dio request returns 401, the interceptor
  // invokes this callback → which clears the stale token + storage, flipping
  // auth.isAuthenticated to false so the router redirect guard routes to
  // /login on the next navigation.
  final container = ProviderContainer();
  ApiClient.onUnauthorized = () =>
      container.read(authProvider.notifier).handleUnauthorized();

  runApp(
    UncontrolledProviderScope(container: container, child: const OseePrepHub()),
  );
}

class OseePrepHub extends ConsumerWidget {
  const OseePrepHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // TODO(T4): wire locale from SharedPreferences (defaults to 'en' until T4 finalize).
    return OseeApp(router: router, locale: const Locale('en'));
  }
}
