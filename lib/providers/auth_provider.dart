import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../api/civics_api_client.dart';
import '../api/auth_store.dart';

/// Whether the app is working against the backend or purely offline.
enum AuthStatus { signedOut, signedIn }

/// Owns sign-in state for the app.
///
/// Signing in is optional: every study feature works offline against the
/// bundled question set. An account adds progress that follows the user across
/// devices and the website.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api) {
    _session = _api.restore();
    _api.onSessionChanged = (session) {
      _session = session;
      notifyListeners();
    };
  }

  final CivicsApiClient _api;

  AuthSession? _session;
  bool _busy = false;
  String? _error;

  AuthSession? get session => _session;
  AuthUser? get user => _session?.user;
  bool get isSignedIn => _session != null;
  AuthStatus get status =>
      isSignedIn ? AuthStatus.signedIn : AuthStatus.signedOut;
  bool get busy => _busy;
  String? get error => _error;

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) => _run(
    () => _api.register(
      email: email,
      password: password,
      displayName: displayName,
    ),
  );

  Future<bool> login({required String email, required String password}) =>
      _run(() => _api.login(email: email, password: password));

  Future<void> logout() async {
    await _api.logout();
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _run(Future<AuthSession> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
