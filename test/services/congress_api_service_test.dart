import 'dart:convert';

import 'package:citizenship_test/services/congress_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Builds a Congress.gov-shaped member record.
Map<String, dynamic> member(
  String name,
  String chamber, {
  String? district,
  String? party,
}) => {
  'name': name,
  'partyName': party,
  'district': district,
  'terms': {
    'item': [
      {'chamber': chamber},
    ],
  },
};

void main() {
  final body = jsonEncode({
    'members': [
      member('Doe, Jane', 'Senate', party: 'Democratic'),
      member('Roe, Richard', 'Senate', party: 'Republican'),
      member('Smith, Sam', 'House of Representatives', district: '3'),
      member('Jones, Jo', 'House of Representatives', district: '12'),
    ],
  });

  group('fetchSenators', () {
    test('returns only senators for the state', () async {
      final api = CongressApiService(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      final senators = await api.fetchSenators('TX', 'key123');
      expect(senators, ['Doe, Jane', 'Roe, Richard']);
    });

    test('calls the current-member endpoint for the given state', () async {
      Uri? seen;
      final api = CongressApiService(
        client: MockClient((req) async {
          seen = req.url;
          return http.Response(body, 200);
        }),
      );
      await api.fetchSenators('ca', 'key123');
      expect(seen!.path, contains('/member/congress/current/CA'));
      expect(seen!.queryParameters['api_key'], 'key123');
      expect(seen!.queryParameters['currentMember'], 'true');
    });
  });

  group('fetchRepresentatives', () {
    test('returns only House members with their districts', () async {
      final api = CongressApiService(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      final reps = await api.fetchRepresentatives('TX', 'key123');
      expect(reps.map((r) => r.name), ['Smith, Sam', 'Jones, Jo']);
      expect(reps.first.district, '3');
    });
  });

  group('error handling', () {
    test('refuses to call the API without a key', () async {
      var called = false;
      final api = CongressApiService(
        client: MockClient((_) async {
          called = true;
          return http.Response(body, 200);
        }),
      );
      expect(
        () => api.fetchSenators('TX', '   '),
        throwsA(
          isA<CongressApiException>().having(
            (e) => e.message,
            'message',
            contains('No Congress.gov API key'),
          ),
        ),
      );
      expect(called, isFalse);
    });

    test('explains a rejected API key on 403', () async {
      final api = CongressApiService(
        client: MockClient((_) async => http.Response('denied', 403)),
      );
      expect(
        () => api.fetchSenators('TX', 'bad'),
        throwsA(
          isA<CongressApiException>().having(
            (e) => e.message,
            'message',
            contains('rejected the API key'),
          ),
        ),
      );
    });

    test('reports other HTTP failures', () async {
      final api = CongressApiService(
        client: MockClient((_) async => http.Response('oops', 500)),
      );
      expect(
        () => api.fetchSenators('TX', 'key'),
        throwsA(
          isA<CongressApiException>().having(
            (e) => e.message,
            'message',
            contains('500'),
          ),
        ),
      );
    });

    test('wraps network errors instead of leaking them', () async {
      final api = CongressApiService(
        client: MockClient((_) async => throw const SocketishError()),
      );
      expect(
        () => api.fetchSenators('TX', 'key'),
        throwsA(isA<CongressApiException>()),
      );
    });

    test('survives an unexpected payload shape', () async {
      final api = CongressApiService(
        client: MockClient(
          (_) async => http.Response(jsonEncode({'members': []}), 200),
        ),
      );
      expect(await api.fetchSenators('TX', 'key'), isEmpty);
    });

    test('tolerates members with no term information', () async {
      final api = CongressApiService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'members': [
                {'name': 'Mystery, M'},
              ],
            }),
            200,
          ),
        ),
      );
      expect(await api.fetchSenators('TX', 'key'), isEmpty);
    });
  });
}

/// Stand-in for a transport-level failure.
class SocketishError implements Exception {
  const SocketishError();
}
