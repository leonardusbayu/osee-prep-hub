import 'dart:js_interop';

/// Web localStorage wrapper for auth persistence.
///
/// Stores the JWT token and serialized user JSON so that a page refresh
/// (or hot restart) restores the authenticated session without requiring
/// a re-login. Mirrors the admin panel's `osee_admin_token` pattern.
@JS('localStorage.getItem')
external JSString? _getItem(String key);

@JS('localStorage.setItem')
external void _setItem(String key, String value);

@JS('localStorage.removeItem')
external void _removeItem(String key);

class AuthStorage {
  AuthStorage._();

  static const _tokenKey = 'osee_token';
  static const _userKey = 'osee_user';

  /// Save token + user JSON to localStorage.
  static void save(String token, String userJson) {
    _setItem(_tokenKey, token);
    _setItem(_userKey, userJson);
  }

  /// Clear stored auth data.
  static void clear() {
    _removeItem(_tokenKey);
    _removeItem(_userKey);
  }

  /// Read stored token (null if absent).
  static String? get token {
    final raw = _getItem(_tokenKey);
    if (raw == null) return null;
    return raw.toDart;
  }

  /// Read stored user JSON (null if absent).
  static String? get userJson {
    final raw = _getItem(_userKey);
    if (raw == null) return null;
    return raw.toDart;
  }
}