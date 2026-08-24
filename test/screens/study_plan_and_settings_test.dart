import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(mockAudioPlugins);
  tearDown(clearAudioPluginMocks);

  group('study plan', () {
    Future<void> openStudyPlan(WidgetTester tester) async {
      useTallScreen(tester);
      await tester.pumpWidget(await buildTestApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Study Plan'));
      await tester.pumpAndSettle();
    }

    testWidgets('offers to build a plan from a test date', (tester) async {
      await openStudyPlan(tester);

      expect(find.textContaining('spread all 100'), findsOneWidget);
      expect(find.text('Create study plan'), findsOneWidget);
      expect(find.textContaining('days to study'), findsOneWidget);
    });

    testWidgets('creates a dated plan covering every question', (tester) async {
      await openStudyPlan(tester);

      await tester.tap(find.text('Create study plan'));
      await tester.pumpAndSettle();

      // Default is two weeks out, so 15 days including today.
      expect(find.text('0 of 15 days complete'), findsOneWidget);
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
    });

    testWidgets('checking a day off updates progress and persists', (
      tester,
    ) async {
      useTallScreen(tester);
      final storage = await freshStorage();
      await tester.pumpWidget(await buildTestApp(storage: storage));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Study Plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create study plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('1 of 15 days complete'), findsOneWidget);

      // Relaunching keeps the plan and the tick.
      await tester.pumpWidget(await buildTestApp(storage: storage));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Study Plan'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 15 days complete'), findsOneWidget);
    });

    testWidgets('a day expands to list its questions, which open in detail', (
      tester,
    ) async {
      await openStudyPlan(tester);
      await tester.tap(find.text('Create study plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Day 1'));
      await tester.pumpAndSettle();

      expect(find.text('What is the supreme law of the land?'), findsOneWidget);
      await tester.tap(find.text('What is the supreme law of the land?'));
      await tester.pumpAndSettle();
      expect(find.text('Question 1'), findsOneWidget);
    });

    testWidgets('a 65/20 plan only schedules the starred questions', (
      tester,
    ) async {
      await openStudyPlan(tester);

      await tester.tap(find.text('65/20 questions only'));
      await tester.pumpAndSettle();
      expect(find.textContaining('spread all 20'), findsOneWidget);

      await tester.tap(find.text('Create study plan'));
      await tester.pumpAndSettle();
      expect(find.text('Day 1'), findsOneWidget);
    });

    testWidgets('the home screen surfaces the active plan', (tester) async {
      await openStudyPlan(tester);
      await tester.tap(find.text('Create study plan'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.textContaining('15-day plan'), findsOneWidget);
    });

    testWidgets('a plan can be cleared', (tester) async {
      await openStudyPlan(tester);
      await tester.tap(find.text('Create study plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Create study plan'), findsOneWidget);
    });
  });

  group('settings', () {
    Future<void> openSettings(WidgetTester tester, {dynamic storage}) async {
      useTallScreen(tester);
      await tester.pumpWidget(await buildTestApp(storage: storage));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the current configuration', (tester) async {
      await openSettings(tester);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('2008 test (100 questions)'), findsOneWidget);
      expect(
        find.text('Not set — needed for state-specific questions'),
        findsOneWidget,
      );
      expect(find.textContaining('President:'), findsOneWidget);
    });

    testWidgets('switches theme to dark', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
    });

    testWidgets('switches the test version from settings', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('2020 · 128Q'));
      await tester.pumpAndSettle();
      expect(find.text('2020 test (128 questions)'), findsOneWidget);
    });

    testWidgets('edits and saves the current officials', (tester) async {
      await openSettings(tester);

      await tester.tap(find.text('Current officials'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('These answers change with elections'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'President'),
        'New President',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('President: New President'), findsOneWidget);
    });

    testWidgets('saves state info and resolves the state capital answer', (
      tester,
    ) async {
      await openSettings(tester);

      await tester.tap(find.text('My state info'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Texas').last);
      await tester.pumpAndSettle();

      expect(find.text('Austin'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Governor'),
        'Gov Person',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'U.S. Senator 1'),
        'Sen Person',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Texas · capital Austin'), findsOneWidget);
    });

    testWidgets('D.C. is handled as not being a state', (tester) async {
      final storage = await freshStorage({
        'state.info':
            '{"code":"DC","name":"District of Columbia",'
            '"capital":"N/A","senators":[]}',
      });
      await openSettings(tester, storage: storage);

      await tester.tap(find.text('My state info'));
      await tester.pumpAndSettle();

      expect(
        find.text('D.C. is not a state and has no capital.'),
        findsOneWidget,
      );
      // D.C. has no governor or senators, so those fields are not offered.
      expect(find.widgetWithText(TextField, 'Governor'), findsNothing);
      expect(find.widgetWithText(TextField, 'U.S. Senator 1'), findsNothing);
    });

    testWidgets('D.C. gets the official answers in the question detail', (
      tester,
    ) async {
      useTallScreen(tester);
      final storage = await freshStorage({
        'state.info':
            '{"code":"DC","name":"District of Columbia",'
            '"capital":"N/A","senators":[]}',
      });
      await tester.pumpWidget(await buildTestApp(storage: storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Browse Questions'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Governor of your state');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Who is the Governor of your state now?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();

      expect(find.text('D.C. does not have a Governor.'), findsOneWidget);
    });

    testWidgets('live refresh explains that an API key is needed', (
      tester,
    ) async {
      await openSettings(tester);
      await tester.tap(find.text('My state info'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('California').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Refresh reps from Congress.gov'));
      await tester.pumpAndSettle();

      expect(find.text('Congress.gov API key needed'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    });

    testWidgets('resetting progress clears the known marks', (tester) async {
      useTallScreen(tester);
      final storage = await freshStorage({
        'progress.learned.v2008': <String>['1', '2'],
      });
      await tester.pumpWidget(await buildTestApp(storage: storage));
      await tester.pumpAndSettle();
      expect(find.text('2 of 100 marked known'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset "known" marks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('0 of 100 marked known'), findsOneWidget);
    });
  });

  group('state-specific answers end to end', () {
    testWidgets('a saved state makes the capital question answerable', (
      tester,
    ) async {
      useTallScreen(tester);
      final storage = await freshStorage({
        'state.info':
            '{"code":"TX","name":"Texas","capital":"Austin","senators":[]}',
      });
      await tester.pumpWidget(await buildTestApp(storage: storage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Browse Questions'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'capital of your state');
      await tester.pumpAndSettle();
      await tester.tap(find.text('What is the capital of your state?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show answer'));
      await tester.pumpAndSettle();

      expect(find.text('Austin'), findsOneWidget);
      expect(find.textContaining('depends on your state'), findsNothing);
    });
  });
}
