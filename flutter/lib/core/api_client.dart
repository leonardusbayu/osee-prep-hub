import 'package:dio/dio.dart';
import 'package:dio_web_adapter/dio_web_adapter.dart';
import 'package:flutter/foundation.dart';

/// Dio-based HTTP client for the OSEE Prep Hub API.
class ApiClient {
  ApiClient._();

  static String get _defaultBaseUrl => kDebugMode
      ? 'http://localhost:8787/api'
      : 'https://osee-prep-hub-worker.edubot-leonardus.workers.dev/api';

  /// Currently active JWT, set by AuthNotifier on login/register and cleared on logout.
  /// Read by [_AuthInterceptor] on every request so cookies (which are scoped to
  /// the production `.osee.co.id` domain) don't have to do the work across the
  /// `pages.dev` <-> `workers.dev` boundary.
  static String? currentToken;

  /// Invoked once when any Dio response returns 401 Unauthorized. Set up in
  /// `main()` from the ProviderContainer so it can drive a Riverpod logout +
  /// router redirect to `/login` without the interceptor needing a BuildContext.
  /// Mirrors the `setUnauthorizedHandler` pattern used by frontend-admin.
  static void Function()? onUnauthorized;

  /// Test hook: when set, [create] returns this Dio instance instead of
  /// building a fresh one. Lets widget tests inject a mock adapter so no real
  /// network call is made (which would otherwise leave a pending Timer and
  /// hang the flutter_test binding). Null in production.
  static Dio? testDioOverride;

  static Dio create({String? baseUrl, String? authToken}) {
    if (testDioOverride != null) {
      return testDioOverride!;
    }
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? _defaultBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      ),
    );

    // Flutter Web: use BrowserHttpClientAdapter with withCredentials
    if (kIsWeb) {
      dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
    }

    // Attach the latest JWT on every request, even if it changed after `create`.
    dio.interceptors.add(_AuthInterceptor());

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(responseBody: true, error: true));
    }

    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ApiClient.currentToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Surface 401s globally so the app can clear the stale token + redirect
    // to login. We only fire the callback once per process to avoid looping
    // when many requests fail in parallel.
    if (err.response?.statusCode == 401 && ApiClient.onUnauthorized != null) {
      final void Function() cb = ApiClient.onUnauthorized!;
      // Null first so concurrent 401s don't all invoke it.
      ApiClient.onUnauthorized = null;
      // The callback is responsible for re-arming onUnauthorized (it does
      // so after clearing state + redirecting, so the next 401 post-login
      // is handled again).
      cb();
    }
    handler.next(err);
  }
}
