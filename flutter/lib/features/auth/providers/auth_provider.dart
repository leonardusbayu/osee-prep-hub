import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../models/user.dart';

/// Auth state — tracks current user + JWT token.
class AuthState {
  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

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
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Auth notifier — manages login, register, logout, verify state.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._dio) : super(const AuthState());

  final Dio _dio;

  /// Register a new user.
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
    String? referralCode,
    String? institutionName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        'role': role,
        if (phone != null) 'phone': phone,
        if (referralCode != null) 'referral_code': referralCode,
        if (institutionName != null) 'institution_name': institutionName,
      });

      final user = User.fromJson(response.data['user'] as Map<String, dynamic>);
      final token = response.data['jwt'] as String;

      state = AuthState(user: user, token: token);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] as String? ?? 'Registration failed';
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Login existing user.
  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final user = User.fromJson(response.data['user'] as Map<String, dynamic>);
      final token = response.data['jwt'] as String;

      state = AuthState(user: user, token: token);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] as String? ?? 'Login failed';
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Logout — clears state.
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // Ignore errors — we're clearing local state regardless
    }
    state = const AuthState();
  }

  /// Verify token — checks if JWT is still valid.
  Future<bool> verify() async {
    if (state.token == null) return false;

    try {
      final response = await _dio.post('/auth/verify');
      if (response.data['valid'] == true) {
        final user = User.fromJson(response.data['user'] as Map<String, dynamic>);
        state = AuthState(user: user, token: state.token);
        return true;
      }
    } catch (_) {
      // Token invalid — clear state
    }
    state = const AuthState();
    return false;
  }
}

/// Auth provider — exposes AuthNotifier + state.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ApiClient.create());
});