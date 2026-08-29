import 'dart:convert';

import 'package:citizenship_test/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/test_harness.dart';

/// The backend's answer for Nevada.
String nevadaAnswers() => jsonEncode({
  'stateCode': 'NV',
  'stateName': 'Nevada',
  'capital': 'Carson City',
  'isDistrictOfColumbia': false,
  'governor': {
    'name': 'Joe Lombardo',
    'since': '2023-01-02',
    'asOf': '2026-08-01',
    'source': 'Wikidata',
  },
  'senators': [
    {'name': 'Catherine Cortez Masto', 'chamber': 'Senate'},
    {'name': 'Jacky Rosen', 'chamber': 'Senate'},
  ],
  'representatives': [
    {
      'name': 'Dina Titus',
      'chamber': 'House of Representatives',
      'district': '1',
      'party': 'Democratic',
    },
    {
      'name': 'Mark Amodei',
      'chamber': 'House of Representatives',
      'district': '2',
      'party': 'Republican',
    },
  ],
  'congressAvailable': true,
  'congressNotice': null,
});

void main() {
  setUp(mockAudioPlugins);
  tearDown(clearAudioPluginMocks);

  MockClient backend() =>
      MockClient((_) async => http.Response(nevadaAnswers(), 200));

  /// Opens Settings › My state info with a backend that answers for Nevada.
  Future<void> openStateInfo(
    WidgetTester tester, {
    StorageService? storage,
    http.Client? client,
  }) async {
    useTallScreen(tester);
    await tester.pumpWidget(
      await buildTestApp(
        storage: storage,
        httpClient: client ?? backend(),
        baseUrl: testBaseUrl,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My state info'));
    await tester.pumpAndSettle();
  }

  Future<void> pickNevada(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nevada').last);
    await tester.pumpAndSettle();
  }

  testWidgets('fetching fills the governor and senators from the backend', (
    tester,
  ) async {
    await openStateInfo(tester);
    await pickNevada(tester);

    // The capital is bundled, so it is there before any network call.
    expect(find.text('Carson City'), findsOneWidget);

    await tester.tap(find.text('Fetch my state answers'));
    await tester.pumpAndSettle();

    // The representative picker opens straight away, since only the user
    // knows their congressional district.
    expect(find.text('Pick your U.S. Representative'), findsOneWidget);
    expect(find.textContaining('District 2'), findsOneWidget);
    await tester.tap(find.textContaining('Mark Amodei'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Governor'))
          .controller
          ?.text,
      'Joe Lombardo',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'U.S. Senator 1'))
          .controller
          ?.text,
      'Catherine Cortez Masto',
    );
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'U.S. Representative'),
          )
          .controller
          ?.text,
      'Mark Amodei',
    );
    expect(find.textContaining('governor verified 2026-08-01'), findsOneWidget);
  });

  testWidgets('a name the user types survives the next fetch', (tester) async {
    await openStateInfo(tester);
    await pickNevada(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Governor'),
      'My Own Governor',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fetch my state answers'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Dina Titus'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Governor'))
          .controller
          ?.text,
      'My Own Governor',
    );
    // The fields the user did not claim are still filled from the backend.
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'U.S. Senator 1'))
          .controller
          ?.text,
      'Catherine Cortez Masto',
    );
  });

  testWidgets('saved answers resolve the state questions in Browse', (
    tester,
  ) async {
    final storage = await freshStorage();
    await openStateInfo(tester, storage: storage);
    await pickNevada(tester);

    await tester.tap(find.text('Fetch my state answers'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Dina Titus'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Back on Settings; go home and open the governor question.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browse Questions'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Governor of your');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Governor of your state').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    expect(find.text('Joe Lombardo'), findsWidgets);
  });

  testWidgets('the cached answers survive a relaunch with no network', (
    tester,
  ) async {
    final storage = await freshStorage();
    await openStateInfo(tester, storage: storage);
    await pickNevada(tester);
    await tester.tap(find.text('Fetch my state answers'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Dina Titus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // Back to the home screen, so the relaunch starts where a cold start does.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Relaunch with a dead network. The blank frame unmounts the old tree, so
    // the new app really is built from scratch, as a cold start would be.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      await buildTestApp(
        storage: storage,
        httpClient: MockClient(
          (_) async => throw http.ClientException('offline'),
        ),
        baseUrl: testBaseUrl,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My state info'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Governor'))
          .controller
          ?.text,
      'Joe Lombardo',
    );

    // Refreshing offline keeps what is on the device rather than clearing it.
    await tester.tap(find.text('Fetch my state answers'));
    await tester.pumpAndSettle();
    expect(find.textContaining('saved on this device'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'U.S. Senator 1'))
          .controller
          ?.text,
      'Catherine Cortez Masto',
    );
  });
}
