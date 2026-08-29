import 'dart:convert';

import 'package:citizenship_test/api/api_exception.dart';
import 'package:citizenship_test/api/auth_store.dart';
import 'package:citizenship_test/api/civics_api_client.dart';
import 'package:citizenship_test/models/state_answers.dart';
import 'package:citizenship_test/models/state_info.dart';
import 'package:citizenship_test/services/congress_api_service.dart';
import 'package:citizenship_test/services/state_answers_service.dart';
import 'package:citizenship_test/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/test_harness.dart';

/// What the backend's GET /api/states/{code}/answers returns.
String answersBody({
  String code = 'NV',
  String name = 'Nevada',
  String capital = 'Carson City',
  String? governor = 'Joe Lombardo',
  List<String> senators = const ['Catherine Cortez Masto', 'Jacky Rosen'],
  List<Map<String, dynamic>> representatives = const [
    {
      'name': 'Dina Titus',
      'chamber': 'House of Representatives',
      'district': '1',
    },
    {
      'name': 'Mark Amodei',
      'chamber': 'House of Representatives',
      'district': '2',
    },
  ],
  bool congressAvailable = true,
  String? notice,
}) => jsonEncode({
  'stateCode': code,
  'stateName': name,
  'capital': capital,
  'isDistrictOfColumbia': code == 'DC',
  'governor': governor == null
      ? null
      : {
          'name': governor,
          'since': '2023-01-02',
          'asOf': '2026-08-01',
          'source': 'Wikidata',
        },
  'senators': [
    for (final s in senators) {'name': s, 'chamber': 'Senate'},
  ],
  'representatives': representatives,
  'congressAvailable': congressAvailable,
  'congressNotice': notice,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  setUp(() async {
    storage = await freshStorage();
  });

  StateAnswersService serviceWith(
    MockClient client, {
    String baseUrl = testBaseUrl,
    MockClient? congressClient,
  }) => StateAnswersService(
    CivicsApiClient(AuthStore(storage), client: client, baseUrl: baseUrl),
    storage,
    congress: CongressApiService(client: congressClient ?? client),
  );

  group('fetching from the backend', () {
    test('resolves capital, governor, senators and the House list', () async {
      Uri? requested;
      final service = serviceWith(
        MockClient((request) async {
          requested = request.url;
          return http.Response(answersBody(), 200);
        }),
      );

      final answers = await service.fetch('nv');

      expect(requested?.path, '/api/states/NV/answers');
      expect(answers.capital, 'Carson City');
      expect(answers.governor?.name, 'Joe Lombardo');
      expect(answers.governor?.asOf, DateTime.parse('2026-08-01'));
      expect(answers.senatorNames, ['Catherine Cortez Masto', 'Jacky Rosen']);
      expect(answers.representatives.map((r) => r.name), [
        'Dina Titus',
        'Mark Amodei',
      ]);
      expect(answers.congressAvailable, isTrue);
    });

    test('asks anonymously — no account needed for state answers', () async {
      String? authHeader;
      final service = serviceWith(
        MockClient((request) async {
          authHeader = request.headers['Authorization'];
          return http.Response(answersBody(), 200);
        }),
      );

      await service.fetch('NV');

      expect(authHeader, isNull);
    });

    test('representatives keep their district for the picker', () async {
      final service = serviceWith(
        MockClient((_) async => http.Response(answersBody(), 200)),
      );

      final answers = await service.fetch('NV');

      expect(answers.representatives.first.label, contains('District 1'));
    });
  });

  group('caching', () {
    test('a fetched payload is readable offline afterwards', () async {
      var calls = 0;
      final service = serviceWith(
        MockClient((_) async {
          calls++;
          return http.Response(answersBody(), 200);
        }),
      );

      await service.fetch('NV');
      expect(calls, 1);

      // A fresh service over the same storage — as a relaunch would be.
      final offline = serviceWith(
        MockClient((_) async => throw http.ClientException('offline')),
      );

      final cached = offline.cached('NV');
      expect(cached, isNotNull);
      expect(cached!.governor?.name, 'Joe Lombardo');
      expect(cached.senatorNames, hasLength(2));
    });

    test(
      'fetchOrCached falls back to the cache when the server is down',
      () async {
        await serviceWith(
          MockClient((_) async => http.Response(answersBody(), 200)),
        ).fetch('NV');

        final offline = serviceWith(
          MockClient((_) async => throw http.ClientException('offline')),
        );

        final answers = await offline.fetchOrCached('NV');

        // The bundled capital still resolves, and the cached names are kept.
        expect(answers?.capital, 'Carson City');
        expect(offline.cached('NV')?.senatorNames, hasLength(2));
      },
    );

    test('each state gets its own cache entry', () async {
      final service = serviceWith(
        MockClient(
          (request) async => http.Response(
            request.url.path.contains('/CA/')
                ? answersBody(
                    code: 'CA',
                    name: 'California',
                    capital: 'Sacramento',
                    governor: 'Gavin Newsom',
                    senators: ['Alex Padilla', 'Adam Schiff'],
                    representatives: const [],
                  )
                : answersBody(),
            200,
          ),
        ),
      );

      await service.fetch('NV');
      await service.fetch('CA');

      expect(service.cached('NV')?.governor?.name, 'Joe Lombardo');
      expect(service.cached('CA')?.governor?.name, 'Gavin Newsom');
    });

    test('a corrupt cache entry is ignored rather than thrown', () async {
      await storage.setJson(StorageKeys.stateAnswers('NV'), {'senators': 7});

      final service = serviceWith(
        MockClient((_) async => http.Response('', 500)),
      );

      expect(service.cached('NV'), isNull);
    });
  });

  group('without a backend', () {
    test('the bundled capital still resolves', () async {
      final service = serviceWith(
        MockClient((_) async => http.Response('', 500)),
        baseUrl: 'https://api.civicsprep.example',
      );

      final answers = await service.fetch('NV');

      expect(answers.capital, 'Carson City');
      expect(answers.stateName, 'Nevada');
      expect(answers.congressAvailable, isFalse);
      expect(answers.congressNotice, contains('Congress.gov API key'));
    });

    test('the user\'s own Congress.gov key fills in the members', () async {
      final service = serviceWith(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'members': [
                {
                  'name': 'Cortez Masto, Catherine',
                  'terms': {
                    'item': [
                      {'chamber': 'Senate'},
                    ],
                  },
                },
                {
                  'name': 'Titus, Dina',
                  'district': 1,
                  'partyName': 'Democratic',
                  'terms': {
                    'item': [
                      {'chamber': 'House of Representatives'},
                    ],
                  },
                },
              ],
            }),
            200,
          ),
        ),
        baseUrl: 'https://api.civicsprep.example',
      );

      final answers = await service.fetch('NV', congressApiKey: 'a-key');

      expect(answers.congressAvailable, isTrue);
      expect(answers.senatorNames, ['Cortez Masto, Catherine']);
      expect(answers.representatives.single.district, '1');
      expect(answers.congressNotice, isNull);
    });

    test('an unknown state code is reported, not silently empty', () async {
      final service = serviceWith(
        MockClient((_) async => http.Response('', 500)),
        baseUrl: 'https://api.civicsprep.example',
      );

      expect(() => service.fetch('ZZ'), throwsA(isA<ApiException>()));
    });
  });

  group('manual entries win', () {
    StateAnswers nevada() => StateAnswers.fromJson(
      jsonDecode(answersBody()) as Map<String, dynamic>,
    );

    const base = StateInfo(code: 'NV', name: 'Nevada', capital: 'Carson City');

    test('an empty field is filled from the fetched answers', () {
      final merged = base.applyFetched(nevada());

      expect(merged.governor, 'Joe Lombardo');
      expect(merged.senators, hasLength(2));
      expect(merged.source, StateDataSource.api);
    });

    test('a field the user typed survives a refresh', () {
      final typed = base
          .copyWith(governor: 'My Own Governor')
          .markManual(StateInfo.fieldGovernor);

      final merged = typed.applyFetched(nevada());

      expect(merged.governor, 'My Own Governor');
      // Fields the user did not claim are still refreshed.
      expect(merged.senators, hasLength(2));
    });

    test('clearing the manual flag lets the refresh take over again', () {
      final typed = base
          .copyWith(governor: 'My Own Governor')
          .markManual(StateInfo.fieldGovernor)
          .clearManual(StateInfo.fieldGovernor);

      expect(typed.applyFetched(nevada()).governor, 'Joe Lombardo');
    });

    test('the representative is never auto-filled — only the user knows their '
        'district', () {
      final merged = base.applyFetched(nevada());

      expect(merged.representative, isNull);
    });

    test('manual flags survive a save and reload', () {
      final typed = base
          .copyWith(governor: 'My Own Governor')
          .markManual(StateInfo.fieldGovernor);

      final reloaded = StateInfo.fromJson(typed.toJson());

      expect(reloaded.manualFields, contains(StateInfo.fieldGovernor));
      expect(reloaded.applyFetched(nevada()).governor, 'My Own Governor');
    });
  });
}
