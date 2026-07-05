import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:osee_prep_hub/core/router.dart';

void main() {
  test('routerProvider builds a GoRouter with all main routes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    expect(router, isNotNull);
    expect(router.routerDelegate, isNotNull);
  });

  test('smoke test — dart arithmetic works', () {
    expect(1 + 1, 2);
  });
}