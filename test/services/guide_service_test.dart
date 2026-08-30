import 'dart:convert';

import 'package:citizenship_test/api/auth_store.dart';
import 'package:citizenship_test/api/civics_api_client.dart';
import 'package:citizenship_test/models/naturalization_guide.dart';
import 'package:citizenship_test/services/guide_service.dart';
import 'package:citizenship_test/services/storage_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/test_harness.dart';

/// A guide payload shaped like the backend's, dated so the test controls
/// whether it counts as fresher than the bundled copy.
String guideBody({
  required String reviewedOn,
  String summary = 'From the server',
}) => jsonEncode({
  'reviewedOn': reviewedOn,
  'disclaimer': 'Study aid only.',
  'timeline': {
    'medianMonths': 6,
    'typicalLowMonths': 6,
    'typicalHighMonths': 12,
    'summary': summary,
    'note': 'Varies by field office.',
  },
  'steps': [
    {
      'key': 'file',
      'title': 'File Form N-400',
      'timing': 'Day 0',
      'timingDetail': '',
      'summary': 'Apply online or by mail.',
      'details': ['Online is cheaper.'],
    },
  ],
  'afterOath': ['Apply for a passport.'],
  'applying': {
    'methods': [
      {
        'name': 'Online',
        'fee': r'$710',
        'summary': 'Use a USCIS account.',
        'points': ['Cheaper.'],
      },
    ],
    'checklist': ['Your green card.'],
  },
  'costs': {
    'items': [
      {
        'label': 'Form N-400, filed online',
        'amount': r'$710',
        'when': 'At filing',
      },
    ],
    'notes': ['Not refunded if denied.'],
    'proposedChange': {
      'status': 'Proposed, not in effect',
      'summary': 'A rise was proposed.',
      'impact': 'Nothing changes yet.',
      'url': 'https://example.gov/rule',
    },
  },
  'tests': {
    'english': {
      'summary': 'Three parts.',
      'parts': ['Speaking.'],
    },
    'civics': {
      'summary': 'Depends on your filing date.',
      'variants': [
        {
          'label': 'Before',
          'detail': '10 of 100, pass with 6.',
          'version': 'v2008',
        },
      ],
      'note': 'Stops early.',
    },
    'exemptions': [
      {'label': '65/20', 'detail': 'Up to 10 questions, pass with 6.'},
    ],
    'retake': 'A second interview 60 to 90 days later.',
  },
  'sources': [
    {'label': 'Form N-400', 'url': 'https://www.uscis.gov/n-400'},
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  setUp(() async {
    storage = await freshStorage();
  });

  GuideService serviceWith(MockClient client, {String baseUrl = testBaseUrl}) =>
      GuideService(
        CivicsApiClient(AuthStore(storage), client: client, baseUrl: baseUrl),
        storage,
      );

  group('the bundled guide', () {
    test('is the same file the backend ships', () async {
      // If these ever diverge the app and the website tell applicants
      // different things, which is the whole reason for one source of truth.
      final asset = await rootBundle.loadString(GuideService.assetPath);
      final parsed = jsonDecode(asset) as Map<String, dynamic>;

      expect(parsed['reviewedOn'], isNotNull);
      expect((parsed['steps'] as List).map((s) => s['key']), [
        'eligibility',
        'file',
        'receipt',
        'biometrics',
        'interview',
        'decision',
        'oath',
      ]);
    });

    test('reads with no backend at all', () async {
      final guide = await serviceWith(
        MockClient((_) async => throw http.ClientException('offline')),
        baseUrl: 'https://api.civicsprep.example',
      ).current();

      expect(guide.steps, hasLength(7));
      expect(guide.stepByKey('biometrics')?.timing, contains('weeks'));
      expect(guide.applying.methods, hasLength(2));
      expect(guide.costs.items, isNotEmpty);
    });

    test('answers how to apply and what it costs', () async {
      final guide = await serviceWith(
        MockClient((_) async => throw http.ClientException('offline')),
      ).current();

      expect(
        guide.applying.methods.map((m) => m.name),
        containsAll(['Online', 'By mail']),
      );
      expect(
        guide.costs.items.map((c) => c.amount),
        containsAll([r'$710', r'$760']),
      );
      expect(guide.applying.checklist, isNotEmpty);
    });

    test('never presents a proposed fee as the current one', () async {
      final guide = await serviceWith(
        MockClient((_) async => throw http.ClientException('offline')),
      ).current();

      final proposed = guide.costs.proposedChange;
      if (proposed != null) {
        expect(proposed.status.toLowerCase(), contains('not in effect'));
        expect(proposed.impact, isNotEmpty);
      }
    });
  });

  group('refreshing from the backend', () {
    test('a server copy reviewed later wins', () async {
      final service = serviceWith(
        MockClient(
          (_) async => http.Response(guideBody(reviewedOn: '2099-01-01'), 200),
        ),
      );

      final refreshed = await service.refresh();
      expect(refreshed.timeline.summary, 'From the server');

      // And it is remembered, so the next launch starts from the newer copy.
      expect((await service.current()).timeline.summary, 'From the server');
    });

    test('an older server copy is ignored', () async {
      final service = serviceWith(
        MockClient(
          (_) async => http.Response(guideBody(reviewedOn: '1999-01-01'), 200),
        ),
      );

      final refreshed = await service.refresh();

      expect(refreshed.steps, hasLength(7));
      expect(refreshed.timeline.summary, isNot('From the server'));
    });

    test('a stale cache is dropped once the bundle catches up', () async {
      await storage.setJson(
        StorageKeys.guide,
        jsonDecode(guideBody(reviewedOn: '1999-01-01')) as Map<String, dynamic>,
      );

      final service = serviceWith(
        MockClient(
          (_) async => http.Response(guideBody(reviewedOn: '1999-01-01'), 200),
        ),
      );
      await service.refresh();

      expect(storage.getJson(StorageKeys.guide), isNull);
    });

    test('a failed refresh still returns a usable guide', () async {
      final service = serviceWith(
        MockClient((_) async => throw http.ClientException('offline')),
      );

      final guide = await service.refresh();

      expect(guide.steps, hasLength(7));
    });

    test('a build with no backend never calls the network', () async {
      var calls = 0;
      final service = serviceWith(
        MockClient((_) async {
          calls++;
          return http.Response(guideBody(reviewedOn: '2099-01-01'), 200);
        }),
        baseUrl: 'https://api.civicsprep.example',
      );

      await service.refresh();

      expect(calls, 0);
    });

    test('a corrupt cache is ignored rather than thrown', () async {
      await storage.setJson(StorageKeys.guide, {'steps': 'not a list'});

      final guide = await serviceWith(
        MockClient((_) async => throw http.ClientException('offline')),
      ).current();

      expect(guide.steps, hasLength(7));
    });
  });

  group('parsing', () {
    test('survives a payload missing everything optional', () {
      final guide = NaturalizationGuide.fromJson(const {});

      expect(guide.steps, isEmpty);
      expect(guide.costs.proposedChange, isNull);
      expect(guide.timeline.medianMonths, 0);
      expect(guide.stepByKey('file'), isNull);
    });
  });
}
