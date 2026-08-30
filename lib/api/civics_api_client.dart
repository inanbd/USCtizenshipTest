import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/enums.dart';
import 'api_config.dart';
import 'api_exception.dart';
import 'auth_store.dart';

/// Talks to the Civics Prep backend.
///
/// Every call the app makes goes through here, so the backend stays the single
/// source of truth for questions, grading and progress. The access token is
/// attached automatically and refreshed once when the server says it expired.
class CivicsApiClient {
  CivicsApiClient(this._authStore, {http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final AuthStore _authStore;
  final http.Client _client;
  final String _baseUrl;

  AuthSession? _session;

  /// Called whenever the session changes, so providers can react.
  void Function(AuthSession? session)? onSessionChanged;

  AuthSession? get session => _session;
  bool get isSignedIn => _session != null;

  /// True when this build points at a real backend. A plain release APK does
  /// not, and every study feature still has to work.
  bool get isBackendConfigured => ApiConfig.isRealBaseUrl(_baseUrl);

  /// Loads any saved session from disk. Call once at startup.
  AuthSession? restore() {
    _session = _authStore.read();
    return _session;
  }

  // ---- auth ----

  Future<AuthSession> register({
    required String email,
    required String password,
    String? displayName,
  }) => _authenticate('/api/auth/register', {
    'email': email,
    'password': password,
    'displayName': displayName,
  });

  Future<AuthSession> login({
    required String email,
    required String password,
  }) =>
      _authenticate('/api/auth/login', {'email': email, 'password': password});

  Future<void> logout() async {
    final refreshToken = _session?.refreshToken;
    if (refreshToken != null) {
      try {
        await _send(
          'POST',
          '/api/auth/logout',
          body: {'refreshToken': refreshToken},
          authenticated: false,
        );
      } on ApiException {
        // The local session is cleared regardless; a stale server token expires.
      }
    }
    await _setSession(null);
  }

  Future<AuthSession> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    final json = await _send('POST', path, body: body, authenticated: false);
    final session = AuthSession.fromJson(json as Map<String, dynamic>);
    await _setSession(session);
    return session;
  }

  Future<void> _setSession(AuthSession? session) async {
    _session = session;
    if (session == null) {
      await _authStore.clear();
    } else {
      await _authStore.write(session);
    }
    onSessionChanged?.call(session);
  }

  // ---- questions ----

  Future<Map<String, dynamic>> fetchQuestions({
    TestVersion? version,
    String? filter,
    String? search,
  }) async {
    final query = <String, String>{};
    if (version != null) query['version'] = _version(version);
    if (filter != null && filter.isNotEmpty) query['filter'] = filter;
    if (search != null && search.isNotEmpty) query['search'] = search;
    final json = await _send('GET', '/api/questions', query: query);
    return json as Map<String, dynamic>;
  }

  // ---- progress ----

  Future<Map<String, dynamic>> fetchProgress({TestVersion? version}) async {
    final json = await _send(
      'GET',
      '/api/progress',
      query: {if (version != null) 'version': _version(version)},
    );
    return json as Map<String, dynamic>;
  }

  Future<void> setQuestionProgress({
    required int number,
    required TestVersion version,
    bool? isLearned,
    bool? isFavorite,
  }) => _send(
    'PUT',
    '/api/progress/questions/$number',
    query: {'version': _version(version)},
    body: {'isLearned': isLearned, 'isFavorite': isFavorite},
  );

  Future<void> resetProgress(TestVersion version) => _send(
    'POST',
    '/api/progress/reset',
    query: {'version': _version(version)},
    body: const {},
  );

  // ---- state info and officials ----

  Future<Map<String, dynamic>> fetchStateInfo() async =>
      await _send('GET', '/api/states/me') as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateStateInfo({
    required String stateCode,
    String? governor,
    String? senatorOne,
    String? senatorTwo,
    String? representative,
  }) async => await _send(
    'PUT',
    '/api/states/me',
    body: {
      'stateCode': stateCode,
      'governor': governor,
      'senatorOne': senatorOne,
      'senatorTwo': senatorTwo,
      'representative': representative,
    },
  ) as Map<String, dynamic>;

  /// Live lookup of a state's members of Congress, proxied by the backend so
  /// the API key never ships inside the app.
  Future<List<Map<String, dynamic>>> lookupCongress(String stateCode) async {
    final json = await _send('GET', '/api/states/$stateCode/congress');
    return (json as List).cast<Map<String, dynamic>>();
  }

  /// Every state-dependent answer for [stateCode] in one call: capital,
  /// governor, senators and the full House delegation. Anonymous on purpose —
  /// state answers are not personal, so the app can refresh them without an
  /// account.
  Future<Map<String, dynamic>> fetchStateAnswers(String stateCode) async =>
      await _send(
        'GET',
        '/api/states/${stateCode.toUpperCase()}/answers',
        authenticated: false,
      ) as Map<String, dynamic>;

  Future<Map<String, dynamic>> fetchOfficials() async =>
      await _send('GET', '/api/settings/officials') as Map<String, dynamic>;

  /// The naturalization process guide. Anonymous — someone still deciding
  /// whether to apply has no account yet.
  Future<Map<String, dynamic>> fetchGuide() async =>
      await _send('GET', '/api/guide', authenticated: false)
          as Map<String, dynamic>;

  // ---- plumbing ----

  static String _version(TestVersion version) => switch (version) {
    TestVersion.v2008 => 'V2008',
    TestVersion.v2020 => 'V2020',
    TestVersion.v2025 => 'V2025',
  };

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
    bool allowRetry = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: query?.isEmpty ?? true ? null : query);

    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };

    if (authenticated && _session != null) {
      headers['Authorization'] = 'Bearer ${_session!.accessToken}';
    }

    http.Response response;
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(ApiConfig.timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } catch (_) {
      throw const ApiException(
        'Could not reach the server. Check your connection.',
      );
    }

    // One silent refresh, so a long study session is not interrupted.
    if (response.statusCode == 401 && authenticated && allowRetry) {
      if (await _tryRefresh()) {
        return _send(
          method,
          path,
          query: query,
          body: body,
          authenticated: authenticated,
          allowRetry: false,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    throw ApiException(_messageFrom(response), statusCode: response.statusCode);
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = _session?.refreshToken;
    if (refreshToken == null) return false;

    try {
      final json = await _send(
        'POST',
        '/api/auth/refresh',
        body: {'refreshToken': refreshToken},
        authenticated: false,
        allowRetry: false,
      );
      await _setSession(AuthSession.fromJson(json as Map<String, dynamic>));
      return true;
    } on ApiException {
      // The refresh token is dead too; the user has to sign in again.
      await _setSession(null);
      return false;
    }
  }

  /// Turns the API's problem response into something worth showing a user.
  static String _messageFrom(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      final errors = body['errors'] as Map<String, dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        return errors.values
            .expand((v) => (v as List).cast<String>())
            .join(' ');
      }

      return (body['detail'] as String?) ??
          (body['title'] as String?) ??
          'Request failed (${response.statusCode}).';
    } catch (_) {
      return 'Request failed (${response.statusCode}).';
    }
  }

  void dispose() => _client.close();
}
