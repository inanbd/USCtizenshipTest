import 'dart:convert';

import 'package:citizenship_test/api/api_exception.dart';
import 'package:citizenship_test/api/auth_store.dart';
import 'package:citizenship_test/api/civics_api_client.dart';
import 'package:citizenship_test/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/test_harness.dart';

/// Builds a successful auth payload the client can parse.
String authBody({String access = 'access-1', String refresh = 'refresh-1'}) =>
    jsonEncode({
      'accessToken': access,
      'refreshToken': refresh,
      'expiresAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'user': {'id': 'u1', 'email': 'a@b.com', 'displayName': 'Tester'},
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<CivicsApiClient> clientWith(MockClient http) async {
    final storage = await freshStorage();
    return CivicsApiClient(
      AuthStore(storage),
      client: http,
      baseUrl: 'https://api.test',
    );
  }

  group('authentication', () {
    test('register stores the session and signs the user in', () async {
      final api = await clientWith(
        MockClient((_) async => http.Response(authBody(), 200)),
      );

      final session = await api.register(
        email: 'a@b.com',
        password: 'Password123',
      );

      expect(session.user.email, 'a@b.com');
      expect(api.isSignedIn, isTrue);
    });

    test('a stored session is restored on the next launch', () async {
      final storage = await freshStorage();
      final first = CivicsApiClient(
        AuthStore(storage),
        client: MockClient((_) async => http.Response(authBody(), 200)),
        baseUrl: 'https://api.test',
      );
      await first.login(email: 'a@b.com', password: 'Password123');

      final second = CivicsApiClient(
        AuthStore(storage),
        baseUrl: 'https://api.test',
      );
      expect(second.restore()?.user.email, 'a@b.com');
      expect(second.isSignedIn, isTrue);
    });

    test('logout clears the saved session', () async {
      final storage = await freshStorage();
      final api = CivicsApiClient(
        AuthStore(storage),
        client: MockClient((_) async => http.Response(authBody(), 200)),
        baseUrl: 'https://api.test',
      );
      await api.login(email: 'a@b.com', password: 'Password123');

      await api.logout();

      expect(api.isSignedIn, isFalse);
      expect(CivicsApiClient(AuthStore(storage)).restore(), isNull);
    });

    test('surfaces the API message when sign-in fails', () async {
      final api = await clientWith(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'title': 'Not signed in.',
              'status': 401,
              'detail': 'Email or password is incorrect.',
            }),
            401,
          ),
        ),
      );

      expect(
        () => api.login(email: 'a@b.com', password: 'nope'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Email or password is incorrect.',
          ),
        ),
      );
    });

    test('joins field errors from a validation response', () async {
      final api = await clientWith(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'title': 'One or more validation errors occurred.',
              'status': 400,
              'errors': {
                'Password': ['Use at least 8 characters.'],
              },
            }),
            400,
          ),
        ),
      );

      expect(
        () => api.register(email: 'a@b.com', password: 'x'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('at least 8 characters'),
          ),
        ),
      );
    });
  });

  group('authenticated requests', () {
    test('attaches the bearer token', () async {
      String? seenAuth;
      final storage = await freshStorage();
      final api = CivicsApiClient(
        AuthStore(storage),
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          if (request.url.path.contains('login')) {
            return http.Response(authBody(access: 'token-abc'), 200);
          }
          seenAuth = request.headers['Authorization'];
          return http.Response(jsonEncode({'learnedNumbers': <int>[]}), 200);
        }),
      );

      await api.login(email: 'a@b.com', password: 'Password123');
      await api.fetchProgress(version: TestVersion.v2008);

      expect(seenAuth, 'Bearer token-abc');
    });

    test('sends the version as the API spells it', () async {
      final seen = <String?>[];
      final api = await clientWith(
        MockClient((request) async {
          seen.add(request.url.queryParameters['version']);
          return http.Response(jsonEncode({'total': 0}), 200);
        }),
      );

      await api.fetchQuestions(version: TestVersion.v2008);
      await api.fetchQuestions(version: TestVersion.v2020);

      expect(seen, ['V2008', 'V2020']);
    });

    test('omits empty query parameters', () async {
      Uri? seen;
      final api = await clientWith(
        MockClient((request) async {
          seen = request.url;
          return http.Response(jsonEncode({'total': 0}), 200);
        }),
      );

      await api.fetchQuestions();

      expect(seen!.hasQuery, isFalse);
    });

    test('refreshes once on 401 and retries the original call', () async {
      var progressCalls = 0;
      var refreshCalls = 0;

      final storage = await freshStorage();
      final api = CivicsApiClient(
        AuthStore(storage),
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path.contains('login')) {
            return http.Response(authBody(access: 'old'), 200);
          }
          if (path.contains('refresh')) {
            refreshCalls++;
            return http.Response(authBody(access: 'new'), 200);
          }
          progressCalls++;
          // The first attempt uses the expired token.
          return request.headers['Authorization'] == 'Bearer new'
              ? http.Response(jsonEncode({'learnedNumbers': <int>[]}), 200)
              : http.Response('', 401);
        }),
      );

      await api.login(email: 'a@b.com', password: 'Password123');
      await api.fetchProgress(version: TestVersion.v2008);

      expect(refreshCalls, 1);
      expect(
        progressCalls,
        2,
        reason: 'the call is retried once after refresh',
      );
      expect(api.session?.accessToken, 'new');
    });

    test('signs the user out when the refresh token is also dead', () async {
      final storage = await freshStorage();
      final api = CivicsApiClient(
        AuthStore(storage),
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          if (request.url.path.contains('login')) {
            return http.Response(authBody(), 200);
          }
          return http.Response('', 401);
        }),
      );

      await api.login(email: 'a@b.com', password: 'Password123');

      await expectLater(
        api.fetchProgress(version: TestVersion.v2008),
        throwsA(isA<ApiException>()),
      );
      expect(api.isSignedIn, isFalse);
    });
  });

  group('failure handling', () {
    test(
      'reports an unreachable server without leaking the raw error',
      () async {
        final api = await clientWith(
          MockClient((_) async => throw const SocketishFailure()),
        );

        expect(
          () => api.fetchQuestions(),
          throwsA(
            isA<ApiException>()
                .having((e) => e.isOffline, 'isOffline', isTrue)
                .having(
                  (e) => e.message,
                  'message',
                  contains('Could not reach'),
                ),
          ),
        );
      },
    );

    test(
      'falls back to a status message when the body is not a problem',
      () async {
        final api = await clientWith(
          MockClient((_) async => http.Response('<html>500</html>', 500)),
        );

        expect(
          () => api.fetchQuestions(),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
          ),
        );
      },
    );
  });
}

/// Stands in for a transport-level failure.
class SocketishFailure implements Exception {
  const SocketishFailure();
}
