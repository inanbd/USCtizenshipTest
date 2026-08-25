import 'dart:convert';

import 'package:citizenship_test/api/auth_store.dart';
import 'package:citizenship_test/api/civics_api_client.dart';
import 'package:citizenship_test/models/enums.dart';
import 'package:citizenship_test/providers/progress_provider.dart';
import 'package:citizenship_test/providers/progress_sync.dart';
import 'package:citizenship_test/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/test_harness.dart';
import 'civics_api_client_test.dart' show authBody;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const version = TestVersion.v2008;

  /// A signed-in client whose responses the test controls.
  Future<(CivicsApiClient, StorageService)> signedInClient(
    MockClient httpClient,
  ) async {
    final storage = await freshStorage();
    final api = CivicsApiClient(
      AuthStore(storage),
      client: httpClient,
      baseUrl: 'https://api.test',
    );
    await api.login(email: 'a@b.com', password: 'Password123');
    return (api, storage);
  }

  test('does nothing at all while signed out', () async {
    var calls = 0;
    final storage = await freshStorage();
    final api = CivicsApiClient(
      AuthStore(storage),
      baseUrl: 'https://api.test',
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    final progress = ProgressProvider(storage);
    final sync = ProgressSync(api, progress);

    await sync.pull(version);
    await sync.pushQuestion(version, 1, isLearned: true);
    await sync.pushAll(version);

    expect(calls, 0, reason: 'offline study must not call the backend');
  });

  test('pull merges the server view into local progress', () async {
    final (api, storage) = await signedInClient(
      MockClient((request) async {
        if (request.url.path.contains('login')) {
          return http.Response(authBody(), 200);
        }
        return http.Response(
          jsonEncode({
            'learnedNumbers': [1, 2, 3],
            'favoriteNumbers': [7],
          }),
          200,
        );
      }),
    );

    final progress = ProgressProvider(storage);
    await ProgressSync(api, progress).pull(version);

    expect(progress.learnedFor(version), containsAll([1, 2, 3]));
    expect(progress.isFavorite(version, 7), isTrue);
  });

  test('pull keeps work done offline instead of overwriting it', () async {
    final (api, storage) = await signedInClient(
      MockClient((request) async {
        if (request.url.path.contains('login')) {
          return http.Response(authBody(), 200);
        }
        return http.Response(
          jsonEncode({
            'learnedNumbers': [5],
            'favoriteNumbers': <int>[],
          }),
          200,
        );
      }),
    );

    final progress = ProgressProvider(storage);
    await progress.setLearned(version, 99, true); // learned before signing in

    await ProgressSync(api, progress).pull(version);

    expect(
      progress.isLearned(version, 5),
      isTrue,
      reason: 'server view applied',
    );
    expect(progress.isLearned(version, 99), isTrue, reason: 'local work kept');
  });

  test('pushQuestion sends the change to the backend', () async {
    Map<String, dynamic>? body;
    String? path;

    final (api, storage) = await signedInClient(
      MockClient((request) async {
        if (request.url.path.contains('login')) {
          return http.Response(authBody(), 200);
        }
        path = request.url.path;
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('', 204);
      }),
    );

    await ProgressSync(
      api,
      ProgressProvider(storage),
    ).pushQuestion(version, 12, isLearned: true, isFavorite: false);

    expect(path, contains('/api/progress/questions/12'));
    expect(body, {'isLearned': true, 'isFavorite': false});
  });

  test('pushAll sends everything already known locally', () async {
    final pushed = <int>[];

    final (api, storage) = await signedInClient(
      MockClient((request) async {
        if (request.url.path.contains('login')) {
          return http.Response(authBody(), 200);
        }
        pushed.add(int.parse(request.url.pathSegments.last));
        return http.Response('', 204);
      }),
    );

    final progress = ProgressProvider(storage);
    await progress.setLearned(version, 3, true);
    await progress.toggleFavorite(version, 8);

    await ProgressSync(api, progress).pushAll(version);

    expect(pushed..sort(), [3, 8]);
  });

  test('a failing sync is recorded but never throws at the UI', () async {
    final (api, storage) = await signedInClient(
      MockClient((request) async {
        if (request.url.path.contains('login')) {
          return http.Response(authBody(), 200);
        }
        return http.Response(
          jsonEncode({'title': 'Server error', 'status': 500}),
          500,
        );
      }),
    );

    final sync = ProgressSync(api, ProgressProvider(storage));

    await sync.pull(version); // must not throw
    await sync.pushQuestion(version, 1, isLearned: true);

    expect(sync.lastError, isNotNull);
  });
}
