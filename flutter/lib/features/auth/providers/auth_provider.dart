import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../auth_storage.dart';
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
  AuthNotifier() : super(const AuthState()) {
    _restoreFromStorage();
    _verifyOnStartup();
  }

  /// Restore auth state from localStorage on app start / page refresh.
  void _restoreFromStorage() {
    final token = AuthStorage.token;
    final userJson = AuthStorage.userJson;
    if (token != null && userJson != null) {
      try {
        final user = User.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
        state = AuthState(user: user, token: token);
      } catch (_) {
        // Corrupt storage — clear it.
        AuthStorage.clear();
      }
    }
  }

  /// Validate the restored token against the server on startup so a stale /
  /// expired JWT isn't trusted unconditionally. If verification fails the
  /// state is cleared and the router redirect guard sends the user to /login.
  /// Fire-and-forget — runs in the background; UI shows the dashboard until
  /// verification completes, then redirects if the token turned out invalid.
  void _verifyOnStartup() {
    if (state.token == null) return;
    verify().then((valid) {
      if (!valid) {
        // verify() already cleared state + storage; re-arm the 401 callback
        // so subsequent failures (e.g. on the login page) are still handled.
        ApiClient.onUnauthorized = handleUnauthorized;
      }
    });
  }

  /// Called by ApiClient when any Dio response returns 401. Clears the stale
  /// token + storage and re-arms the callback so the next 401 (post-relogin)
  /// is handled again. The router redirect guard routes to /login on the
  /// next navigation because isAuthenticated flips to false.
  void handleUnauthorized() {
    ApiClient.currentToken = null;
    AuthStorage.clear();
    state = const AuthState();
    ApiClient.onUnauthorized = handleUnauthorized;
  }

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
        if (referralCode != null && referralCode.isNotEmpty)
          'referral_code': referralCode,
        if (institutionName != null && institutionName.isNotEmpty)
          'institution_name': institutionName,
      };
      final res = await _post('/auth/register', body);
      final user = User.fromJson(res['user'] as Map<String, dynamic>);
      final token = res['jwt'] as String;
      state = AuthState(user: user, token: token);
      AuthStorage.save(token, jsonEncode(user.toJson()));
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _post('/auth/login', {
        'email': email,
        'password': password,
      });
      final user = User.fromJson(res['user'] as Map<String, dynamic>);
      final token = res['jwt'] as String;
      state = AuthState(user: user, token: token);
      AuthStorage.save(token, jsonEncode(user.toJson()));
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _post('/auth/logout', {});
    } catch (_) {}
    AuthStorage.clear();
    state = const AuthState();
    // Re-arm so a future 401 (after re-login) is still handled.
    ApiClient.onUnauthorized = handleUnauthorized;
  }

  Future<bool> verify() async {
    if (state.token == null) return false;
    try {
      final res = await _post('/auth/verify', {});
      if (res['valid'] == true) {
        final user = User.fromJson(res['user'] as Map<String, dynamic>);
        state = AuthState(user: user, token: state.token);
        AuthStorage.save(state.token!, jsonEncode(user.toJson()));
        return true;
      }
    } catch (_) {}
    AuthStorage.clear();
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

Future<Map<String, dynamic>> _post(
  String path,
  Map<String, dynamic> body,
) async {
  final url = '$_apiUrl$path';
  final completer = Completer<Map<String, dynamic>>();

  final xhr = JSHttpRequest();
  xhr.open('POST', url, true);
  xhr.withCredentials = true;
  xhr.setRequestHeader('Content-Type', 'application/json');
  if (ApiClient.currentToken != null) {
    xhr.setRequestHeader('Authorization', 'Bearer ${ApiClient.currentToken}');
  }

  xhr.onload = (() {
    try {
      final data = jsonDecode(xhr.responseText) as Map<String, dynamic>;
      if (xhr.status >= 400) {
        final err = data['error'] as Map<String, dynamic>?;
        completer.completeError(
          Exception(err?['message'] ?? 'Failed (${xhr.status})'),
        );
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

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
