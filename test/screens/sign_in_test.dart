import 'dart:convert';

import 'package:citizenship_test/api/auth_store.dart';
import 'package:citizenship_test/api/civics_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/test_harness.dart';

String authBody() => jsonEncode({
  'accessToken': 'access-1',
  'refreshToken': 'refresh-1',
  'expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
  'user': {'id': 'u1', 'email': 'user@example.com', 'displayName': 'Ada'},
});

void main() {
  setUp(mockAudioPlugins);
  tearDown(clearAudioPluginMocks);

  Future<void> openSettings(
    WidgetTester tester, {
    MockClient? httpClient,
  }) async {
    useTallScreen(tester);
    final storage = await freshStorage();
    final api = CivicsApiClient(
      AuthStore(storage),
      client: httpClient,
      baseUrl: 'https://api.test',
    );
    await tester.pumpWidget(
      await buildTestApp(storage: storage, apiClient: api),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('settings offers sign-in while signed out', (tester) async {
    await openSettings(tester);

    expect(find.text('Not signed in'), findsOneWidget);
    expect(
      find.text('Sign in to sync progress with the website'),
      findsOneWidget,
    );
  });

  testWidgets('opens the sign-in screen and explains the benefit', (
    tester,
  ) async {
    await openSettings(tester);

    await tester.tap(find.text('Not signed in'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(
      find.textContaining('Studying works fine without one'),
      findsOneWidget,
    );
  });

  testWidgets('signing in shows the account as synced', (tester) async {
    await openSettings(
      tester,
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/api/auth/login')) {
          return http.Response(authBody(), 200);
        }
        // Progress sync after sign-in.
        return http.Response(
          jsonEncode({'learnedNumbers': <int>[], 'favoriteNumbers': <int>[]}),
          200,
        );
      }),
    );

    await tester.tap(find.text('Not signed in'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'Password123',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Progress syncs with the website'), findsOneWidget);
  });

  testWidgets('a rejected sign-in shows the server message', (tester) async {
    await openSettings(
      tester,
      httpClient: MockClient(
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

    await tester.tap(find.text('Not signed in'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'wrongpassword',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
  });

  testWidgets('validates the form before calling the API', (tester) async {
    var called = false;
    await openSettings(
      tester,
      httpClient: MockClient((_) async {
        called = true;
        return http.Response(authBody(), 200);
      }),
    );

    await tester.tap(find.text('Not signed in'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('can switch to creating an account', (tester) async {
    await openSettings(tester);

    await tester.tap(find.text('Not signed in'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create a new account'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsWidgets);
    expect(
      find.widgetWithText(TextFormField, 'Name (optional)'),
      findsOneWidget,
    );
  });
}
