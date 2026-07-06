import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';

const String _apiUrl = 'https://osee-prep-hub-worker.edubot-leonardus.workers.dev/api';

class AuthState {
  const AuthState({this.user, this.token, this.isLoading = false, this.error});
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;
  bool get isAuthenticated => user != null && token != null;
  AuthState copyWith({User? user, String? token, bool? isLoading, String? error, bool clearError = false}) =>
      AuthState(user: user ?? this.user, token: token ?? this.token, isLoading: isLoading ?? this.isLoading, error: clearError ? null : (error ?? this.error));
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

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

  Future<bool> login({required String email, required String password}) async {
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

/// Uses dart:html HttpRequest directly — guaranteed to work in Flutter Web.
Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
  final url = '$_apiUrl$path';
  final completer = html.HttpRequest();
  completer.open('POST', url, async: true);
  completer.withCredentials = true;
  completer.setRequestHeader('Content-Type', 'application/json');

  final result = await completer.onLoad.first;
  final status = completer.status ?? 0;
  final responseText = completer.responseText ?? '{}';
  final data = jsonDecode(responseText) as Map<String, dynamic>;

  if (status >= 400) {
    final err = data['error'] as Map<String, dynamic>?;
    throw Exception(err?['message'] ?? 'Request failed ($status)');
  }
  return data;
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());