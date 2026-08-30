import 'package:citizenship_test/models/enums.dart';
import 'package:citizenship_test/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

/// End-to-end coverage of the mock test: seeing and hearing the question, then
/// writing or speaking the answer.
void main() {
  late TtsRecorder tts;
  late SttRecorder stt;

  setUp(() {
    final mocks = mockAudioPlugins();
    tts = mocks.tts;
    stt = mocks.stt;
  });

  tearDown(clearAudioPluginMocks);

  /// Starts a one-question mock test built from a single starred question
  /// (Q1 of the 2008 set: "What is the supreme law of the land?"), so the
  /// expected answer is deterministic.
  Future<void> startOneQuestionTest(WidgetTester tester) async {
    useTallScreen(tester);
    final storage = await freshStorage({
      'progress.favorites.v2008': <String>['1'],
    });
    await tester.pumpWidget(await buildTestApp(storage: storage));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mock Test'));
    await tester.pumpAndSettle();

    // Restrict the pool to the single starred question.
    await tester.tap(find.text('Starred'));
    await tester.pumpAndSettle();
    expect(find.text('1 questions available in this set.'), findsOneWidget);

    await tester.tap(find.text('Start test'));
    await tester.pumpAndSettle();
  }

  testWidgets('runs a full test and reports a passing result', (tester) async {
    await startOneQuestionTest(tester);

    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(find.text('What is the supreme law of the land?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'the constitution');
    await tester.tap(find.text('Submit answer'));
    await tester.pumpAndSettle();

    expect(find.text('Correct!'), findsOneWidget);
    expect(find.text('the Constitution'), findsWidgets);

    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();

    expect(find.text('You passed!'), findsOneWidget);
    expect(find.text('1 of 1 correct · 100%'), findsOneWidget);
  });

  testWidgets('marks a wrong answer and shows the accepted answer', (
    tester,
  ) async {
    await startOneQuestionTest(tester);

    await tester.enterText(find.byType(TextField), 'the declaration');
    await tester.tap(find.text('Submit answer'));
    await tester.pumpAndSettle();

    expect(find.text('Not quite'), findsOneWidget);
    expect(find.text('the Constitution'), findsWidgets);

    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();
    expect(find.text('Keep practicing'), findsOneWidget);
  });

  testWidgets('reads the question aloud when Hear is tapped', (tester) async {
    await startOneQuestionTest(tester);

    expect(tts.spoken, isEmpty);
    await tester.tap(find.text('Hear'));
    await tester.pumpAndSettle();

    expect(tts.spoken, isNotEmpty);
    expect(
      tts.spoken.any((s) => s.contains('supreme law of the land')),
      isTrue,
      reason: 'the question text should be sent to the speech engine',
    );
  });

  testWidgets('accepts a spoken answer through the microphone', (tester) async {
    await startOneQuestionTest(tester);

    await tester.tap(find.byIcon(Icons.mic_rounded));
    // The listening indicator spins forever, so settle is not an option.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(stt.listenCalled, isTrue);
    expect(find.text('Listening…'), findsOneWidget);

    // The native recognizer returns what the user said.
    await emitSpeechResult('the constitution');
    await tester.pump();

    expect(find.widgetWithText(TextField, 'the constitution'), findsOneWidget);

    await tester.tap(find.text('Submit answer'));
    await tester.pumpAndSettle();
    expect(find.text('Correct!'), findsOneWidget);

    // The speech plugin schedules a short cleanup timer on stop.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('stops listening when the mic is tapped again', (tester) async {
    await startOneQuestionTest(tester);

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Listening…'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stop_circle_rounded));
    await tester.pumpAndSettle();

    expect(stt.stopCount, greaterThan(0));
    expect(find.text('Listening…'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('lets the user override the automatic grade', (tester) async {
    await startOneQuestionTest(tester);

    await tester.enterText(find.byType(TextField), 'the declaration');
    await tester.tap(find.text('Submit answer'));
    await tester.pumpAndSettle();
    expect(find.text('Not quite'), findsOneWidget);

    await tester.tap(find.text('Right'));
    await tester.pumpAndSettle();
    expect(find.text('Correct!'), findsOneWidget);

    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();
    expect(find.text('You passed!'), findsOneWidget);
  });

  testWidgets('tracks the running score across several questions', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mock Test'));
    await tester.pumpAndSettle();
    expect(find.text('100 questions available in this set.'), findsOneWidget);

    await tester.tap(find.text('Start test'));
    await tester.pumpAndSettle();

    // The 2008 test asks 10 questions and needs 6 to pass.
    expect(find.text('Question 1 of 10'), findsOneWidget);
    expect(find.textContaining('Need'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'something');
    await tester.tap(find.text('Submit answer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Question 2 of 10'), findsOneWidget);
  });

  testWidgets('warns before quitting a test in progress', (tester) async {
    await startOneQuestionTest(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Quit test?'), findsOneWidget);

    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quit'));
    await tester.pumpAndSettle();
    expect(find.text('Mock Test'), findsWidgets);
  });

  testWidgets('a completed test is saved to history and marks answers known', (
    tester,
  ) async {
    await startOneQuestionTest(tester);

    await tester.enterText(find.byType(TextField), 'the constitution');
    await tester.tap(find.text('Submit answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Home shows the last result and the newly-learned question.
    expect(find.textContaining('Last mock test: 1/1'), findsOneWidget);
    expect(find.text('1 of 100 marked known'), findsOneWidget);
  });

  testWidgets('prompts for state info when it has not been set', (
    tester,
  ) async {
    useTallScreen(tester);
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mock Test'));
    await tester.pumpAndSettle();

    expect(find.text('Set your state'), findsOneWidget);
    await tester.tap(find.text('Set your state'));
    await tester.pumpAndSettle();
    expect(find.text('My State Info'), findsOneWidget);
  });

  group('the 65/20 setup', () {
    Future<void> openSetup(WidgetTester tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(
        await buildTestApp(
          storage: await freshStorage({
            StorageKeys.testVersion: TestVersion.v2025.storageKey,
          }),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mock Test'));
      await tester.pumpAndSettle();
    }

    testWidgets('a 65/20 practice run is 10 questions, not 20', (tester) async {
      await openSetup(tester);

      // The general 2025 test asks 20.
      expect(find.text('20 questions'), findsOneWidget);
      expect(find.textContaining('Pass by answering 12 of 20'), findsOneWidget);

      await tester.tap(find.text('65/20'));
      await tester.pumpAndSettle();

      // The exemption is a shorter test, and the banner has to say so.
      expect(find.text('10 questions'), findsOneWidget);
      expect(find.textContaining('Pass by answering 6 of 10'), findsOneWidget);
      expect(find.text('20 questions available in this set.'), findsOneWidget);
    });

    testWidgets('switching back restores the full-length test', (tester) async {
      await openSetup(tester);

      await tester.tap(find.text('65/20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('20 questions'), findsOneWidget);
      expect(find.textContaining('Pass by answering 12 of 20'), findsOneWidget);
    });
  });
}
