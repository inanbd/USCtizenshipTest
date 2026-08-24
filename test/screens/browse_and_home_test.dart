import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  late TtsRecorder tts;

  setUp(() => tts = mockAudioPlugins().tts);
  tearDown(clearAudioPluginMocks);

  group('home screen', () {
    testWidgets('shows every study mode', (tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(await buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('U.S. Citizenship Test'), findsOneWidget);
      expect(find.text('Mock Test'), findsOneWidget);
      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('Study Plan'), findsOneWidget);
      expect(find.text('Browse Questions'), findsOneWidget);
      expect(find.text('0 of 100 marked known'), findsOneWidget);
    });

    testWidgets('switching to the 2020 test updates the whole screen', (
      tester,
    ) async {
      useTallScreen(tester);
      await tester.pumpWidget(await buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('0 of 100 marked known'), findsOneWidget);

      await tester.tap(find.text('2020 · 128Q'));
      await tester.pumpAndSettle();

      expect(find.text('0 of 128 marked known'), findsOneWidget);
      expect(
        find.text('Flip through all 128 questions with audio.'),
        findsOneWidget,
      );
      expect(find.textContaining('20 questions, pass with 12'), findsOneWidget);
    });

    testWidgets('remembers the chosen version after a restart', (tester) async {
      useTallScreen(tester);
      final storage = await freshStorage();
      await tester.pumpWidget(await buildTestApp(storage: storage));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2020 · 128Q'));
      await tester.pumpAndSettle();

      // Rebuild the app from the same storage, as a relaunch would.
      await tester.pumpWidget(await buildTestApp(storage: storage));
      await tester.pumpAndSettle();
      expect(find.text('0 of 128 marked known'), findsOneWidget);
    });
  });

  group('browse questions', () {
    Future<void> openBrowse(WidgetTester tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(await buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse Questions'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists questions grouped by USCIS topic', (tester) async {
      await openBrowse(tester);

      expect(find.text('Browse · 2008 · 100Q'), findsOneWidget);
      expect(find.text('Principles of American Democracy'), findsOneWidget);
      expect(find.text('What is the supreme law of the land?'), findsOneWidget);
    });

    testWidgets('searches by question text', (tester) async {
      await openBrowse(tester);

      await tester.enterText(find.byType(TextField), 'Statue of Liberty');
      await tester.pumpAndSettle();

      expect(find.text('Where is the Statue of Liberty?'), findsOneWidget);
      expect(find.text('What is the supreme law of the land?'), findsNothing);
    });

    testWidgets('searches by answer text', (tester) async {
      await openBrowse(tester);

      await tester.enterText(find.byType(TextField), 'Woodrow');
      await tester.pumpAndSettle();

      expect(
        find.text('Who was President during World War I?'),
        findsOneWidget,
      );
    });

    testWidgets('reports when nothing matches', (tester) async {
      await openBrowse(tester);

      await tester.enterText(find.byType(TextField), 'zzzznotaquestion');
      await tester.pumpAndSettle();
      expect(find.text('No questions match.'), findsOneWidget);
    });

    testWidgets('filters to the 65/20 questions', (tester) async {
      await openBrowse(tester);

      await tester.tap(find.text('65/20'));
      await tester.pumpAndSettle();

      // Q1 is not starred; Q6 is.
      expect(find.text('What is the supreme law of the land?'), findsNothing);
      expect(
        find.text('What is one right or freedom from the First Amendment?'),
        findsOneWidget,
      );
    });

    testWidgets('opens a question, reveals the answer and marks it known', (
      tester,
    ) async {
      await openBrowse(tester);

      await tester.tap(find.text('What is the supreme law of the land?'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1'), findsOneWidget);
      expect(find.text('American Government'), findsOneWidget);
      expect(find.text('the Constitution'), findsNothing);

      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      expect(find.text('the Constitution'), findsOneWidget);

      await tester.tap(find.text('Mark as known'));
      await tester.pumpAndSettle();
      expect(find.text('Marked as known'), findsOneWidget);
    });

    testWidgets('reads a question aloud from the detail screen', (
      tester,
    ) async {
      await openBrowse(tester);
      await tester.tap(find.text('What is the supreme law of the land?'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hear'));
      await tester.pumpAndSettle();
      expect(
        tts.spoken.any((s) => s.contains('supreme law of the land')),
        isTrue,
      );
    });

    testWidgets('a state question explains that state info is needed', (
      tester,
    ) async {
      await openBrowse(tester);

      await tester.enterText(find.byType(TextField), 'capital of your state');
      await tester.pumpAndSettle();
      await tester.tap(find.text('What is the capital of your state?'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This answer depends on your state'),
        findsOneWidget,
      );
    });

    testWidgets('a time-sensitive question warns that it changes', (
      tester,
    ) async {
      await openBrowse(tester);

      await tester.enterText(find.byType(TextField), 'name of the President');
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          'What is the name of the President of the United States now?',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('changes over time'), findsOneWidget);
    });

    testWidgets('the not-yet-known filter hides learned questions', (
      tester,
    ) async {
      useTallScreen(tester);
      final storage = await freshStorage({
        'progress.learned.v2008': <String>['1'],
      });
      await tester.pumpWidget(await buildTestApp(storage: storage));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browse Questions'));
      await tester.pumpAndSettle();

      expect(find.text('What is the supreme law of the land?'), findsOneWidget);

      await tester.tap(find.text('Not yet known'));
      await tester.pumpAndSettle();
      expect(find.text('What is the supreme law of the land?'), findsNothing);
    });
  });
}
