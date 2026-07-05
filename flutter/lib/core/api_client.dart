import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Dio-based HTTP client for the OSEE Prep Hub API.
///
/// Base URL is configurable via environment. In dev, defaults to localhost:8787
/// (the Cloudflare Workers dev port). In production, set VITE_API_URL equivalent.
class ApiClient {
  ApiClient._();

  static const String _defaultBaseUrl = 'https://osee-prep-hub-worker.edubot-leonardus.workers.dev/api';

  /// Build a configured Dio instance.
  ///
  /// Auth interceptor attaches JWT from storage on every request.
  /// Errors are logged in dev mode.
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

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: true,
        error: true,
      ));
    }

    return dio;
  }
}