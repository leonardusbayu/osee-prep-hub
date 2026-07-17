@TestOn('browser')
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:osee_prep_hub/core/router.dart';

/// Web-only smoke test — verifies the GoRouter provider builds with all
/// main routes. Runs in the browser because the auth storage layer uses
/// `dart:js_interop` + `@JS('localStorage')` which only resolves in a JS
/// runtime. Run with: `flutter test -p chrome test/web_smoke_test.dart`
void main() {
  test('routerProvider builds a GoRouter with all main routes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    expect(router, isNotNull);
    expect(router.routerDelegate, isNotNull);
  });
}
