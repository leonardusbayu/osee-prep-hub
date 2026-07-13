import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../models/user.dart';

String get _apiUrl => kDebugMode
    ? 'http://localhost:8787/api'
    : 'https://osee-prep-hub-worker.edubot-leonardus.workers.dev/api';

class AuthState {
  const AuthState({this.user, this.token, this.isLoading = false, this.error});
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;
  bool get isAuthenticated => user != null && token != null;
  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => AuthState(
    user: user ?? this.user,
    token: token ?? this.token,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  @override
  set state(AuthState value) {
    // Mirror token into ApiClient so the auth interceptor picks it up on every
    // subsequent Dio request — required for cross-domain auth where the
    // HttpOnly SSO cookie is scoped to a parent domain the browser can't see.
    ApiClient.currentToken = value.token;
    super.state = value;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String role,
    String? referralCode,
    String? institutionName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'name': name,
        'role': role,
        if (referralCode != null && referralCode.isNotEmpty) 'referral_code': referralCode,
        if (institutionName != null && institutionName.isNotEmpty) 'institution_name': institutionName,
      };
      final res = await _post('/auth/register', body);
      final user = User.fromJson(res['user'] as Map<String, dynamic>);
      final token = res['jwt'] as String;
      state = AuthState(user: user, token: token);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _post('/auth/login', {'email': email, 'password': password});
      final user = User.fromJson(res['user'] as Map<String, dynamic>);
      final token = res['jwt'] as String;
      state = AuthState(user: user, token: token);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    try { await _post('/auth/logout', {}); } catch (_) {}
    state = const AuthState();
  }

  Future<bool> verify() async {
    if (state.token == null) return false;
    try {
      final res = await _post('/auth/verify', {});
      if (res['valid'] == true) {
        final user = User.fromJson(res['user'] as Map<String, dynamic>);
        state = AuthState(user: user, token: state.token);
        return true;
      }
    } catch (_) {}
    state = const AuthState();
    return false;
  }
}

/// XMLHttpRequest via dart:js_interop — raw, no packages.
@JS('XMLHttpRequest')
extension type JSHttpRequest._(JSObject _) implements JSObject {
  external JSHttpRequest();
  external void open(String method, String url, bool async);
  external set withCredentials(bool value);
  external void setRequestHeader(String header, String value);
  external void send(String? body);
  external int get status;
  external String get responseText;
  external set onload(JSFunction value);
  external set onerror(JSFunction value);
}

Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
  final url = '$_apiUrl$path';
  final completer = Completer<Map<String, dynamic>>();

  final xhr = JSHttpRequest();
  xhr.open('POST', url, true);
  xhr.withCredentials = true;
  xhr.setRequestHeader('Content-Type', 'application/json');

  xhr.onload = (() {
    try {
      final data = jsonDecode(xhr.responseText) as Map<String, dynamic>;
      if (xhr.status >= 400) {
        final err = data['error'] as Map<String, dynamic>?;
        completer.completeError(Exception(err?['message'] ?? 'Failed (${xhr.status})'));
      } else {
        completer.complete(data);
      }
    } catch (e) {
      completer.completeError(Exception('Parse error: $e'));
    }
  }).toJS;

  xhr.onerror = (() {
    completer.completeError(Exception('Network error'));
  }).toJS;

  // CRITICAL: send the request
  xhr.send(jsonEncode(body));

  return completer.future;
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
