import 'package:dio/dio.dart';
import 'package:dio_web_adapter/dio_web_adapter.dart';
import 'package:flutter/foundation.dart';

/// Dio-based HTTP client for the OSEE Prep Hub API.
class ApiClient {
  ApiClient._();

  static const String _defaultBaseUrl = 'https://osee-prep-hub-worker.edubot-leonardus.workers.dev/api';

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

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(responseBody: true, error: true));
    }

    return dio;
  }
}