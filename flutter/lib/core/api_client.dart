import 'package:dio/dio.dart';
import 'package:dio_web_adapter/dio_web_adapter.dart';
import 'package:flutter/foundation.dart';

/// Dio-based HTTP client for the OSEE Prep Hub API.
class ApiClient {
  ApiClient._();

  static const String _defaultBaseUrl = 'https://osee-prep-hub-worker.edubot-leonardus.workers.dev/api';

  /// Currently active JWT, set by AuthNotifier on login/register and cleared on logout.
  /// Read by [_AuthInterceptor] on every request so cookies (which are scoped to
  /// the production `.osee.co.id` domain) don't have to do the work across the
  /// `pages.dev` <-> `workers.dev` boundary.
  static String? currentToken;

  static Dio create({String? baseUrl, String? authToken}) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? _defaultBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
    ));

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
}