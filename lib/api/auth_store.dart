import 'dart:convert';

import '../services/storage_service.dart';

/// The signed-in user, as the backend describes them.
class AuthUser {
  const AuthUser({required this.id, required this.email, this.displayName});

  final String id;
  final String email;
  final String? displayName;

  String get label => (displayName != null && displayName!.trim().isNotEmpty)
      ? displayName!.trim()
      : email;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String? ?? '',
    displayName: json['displayName'] as String?,
  );
}

/// A signed-in session: the tokens plus who they belong to.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final AuthUser user;

  /// Treated as expired slightly early so a call does not fail mid-flight.
  bool get isExpired => DateTime.now().toUtc().isAfter(
    expiresAt.toUtc().subtract(const Duration(seconds: 30)),
  );

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'user': user.toJson(),
  };

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
  );
}

/// Persists the session so the user stays signed in between launches.
class AuthStore {
  AuthStore(this._storage);

  static const _key = 'auth.session';

  final StorageService _storage;

  AuthSession? read() {
    final raw = _storage.getString(_key);
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(AuthSession session) =>
      _storage.setString(_key, jsonEncode(session.toJson()));

  Future<void> clear() => _storage.remove(_key);
}
