import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  late TtsRecorder tts;

  setUp(() => tts = mockAudioPlugins().tts);
  tearDown(clearAudioPluginMocks);

  Future<void> openFlashcards(WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flashcards'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the first card showing the question side', (
    tester,
  ) async {
    await openFlashcards(tester);

    expect(find.text('1 / 100'), findsOneWidget);
    expect(find.text('Q1'), findsOneWidget);
    expect(find.text('What is the supreme law of the land?'), findsOneWidget);
    expect(find.text('Tap to flip'), findsOneWidget);
    // The answer stays hidden until the card is flipped.
    expect(find.text('the Constitution'), findsNothing);
  });

  testWidgets('flips to reveal the answer and back', (tester) async {
    await openFlashcards(tester);

    await tester.tap(find.text('Tap to flip'));
    await tester.pumpAndSettle();
    expect(find.text('the Constitution'), findsOneWidget);

    await tester.tap(find.text('the Constitution'));
    await tester.pumpAndSettle();
    expect(find.text('What is the supreme law of the land?'), findsOneWidget);
  });

  testWidgets('moves between cards with Next and Previous', (tester) async {
    await openFlashcards(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 100'), findsOneWidget);
    expect(find.text('What does the Constitution do?'), findsOneWidget);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 100'), findsOneWidget);
  });

  testWidgets('a flipped card resets to the question when moving on', (
    tester,
  ) async {
    await openFlashcards(tester);

    await tester.tap(find.text('Tap to flip'));
    await tester.pumpAndSettle();
    expect(find.text('the Constitution'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.text('Tap to flip'),
      findsOneWidget,
      reason: 'the next card should start on its question side',
    );
  });

  testWidgets('reads the card aloud', (tester) async {
    await openFlashcards(tester);

    await tester.tap(find.text('Hear'));
    await tester.pumpAndSettle();
    expect(
      tts.spoken.any((s) => s.contains('supreme law of the land')),
      isTrue,
    );
  });

  testWidgets('marks a card known and remembers it', (tester) async {
    await openFlashcards(tester);

    expect(find.text('Learn'), findsOneWidget);
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Known'), findsOneWidget);

    // Progress is reflected back on the home screen.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 of 100 marked known'), findsOneWidget);
  });

  testWidgets('stars a card for later practice', (tester) async {
    await openFlashcards(tester);

    expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.star_border_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('filters down to the 20 starred 65/20 questions', (tester) async {
    await openFlashcards(tester);

    await tester.tap(find.text('65/20 only'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 20'), findsOneWidget);
  });

  testWidgets('shuffling keeps the full deck and returns to the first card', (
    tester,
  ) async {
    await openFlashcards(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 100'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.shuffle_rounded));
    await tester.pumpAndSettle();
    expect(find.text('1 / 100'), findsOneWidget);
  });

  testWidgets('uses the 2020 set when that version is selected', (
    tester,
  ) async {
    useTallScreen(tester);
    final storage = await freshStorage({'settings.testVersion': 'v2020'});
    await tester.pumpWidget(await buildTestApp(storage: storage));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Flashcards'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 128'), findsOneWidget);
  });
}
