import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Test-only helper: builds a [Dio] whose every request immediately resolves
/// to a configurable canned response. Used to set [ApiClient.testDioOverride]
/// so widget tests never make a real network call (which would leave a pending
/// Timer and hang the flutter_test binding).
Dio fakeDio({
  Object defaultResponse = const <String, dynamic>{},
  int statusCode = 200,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://fake.test/api'));
  dio.httpClientAdapter =
      _FakeAdapter(defaultResponse: defaultResponse, statusCode: statusCode);
  return dio;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.defaultResponse, required this.statusCode});

  final Object defaultResponse;
  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(defaultResponse),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}