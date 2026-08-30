import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  setUp(mockAudioPlugins);
  tearDown(clearAudioPluginMocks);

  /// The three tabs are all in the tree at once, so a scroll has to name the
  /// list it means.
  Finder listIn(String tab) => find.descendant(
    of: find.byKey(PageStorageKey('guide.$tab')),
    matching: find.byType(Scrollable),
  );

  Future<void> scrollTo(WidgetTester tester, String tab, Finder target) =>
      tester.scrollUntilVisible(target, 300, scrollable: listIn(tab));

  Future<void> openGuide(WidgetTester tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('From application to citizen'));
    await tester.pumpAndSettle();
  }

  testWidgets('home offers the process guide', (tester) async {
    useTallScreen(tester);
    await tester.pumpWidget(await buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('The process'), findsOneWidget);
    expect(find.textContaining('how to apply, what it costs'), findsOneWidget);
  });

  testWidgets('the steps run from filing to the oath', (tester) async {
    await openGuide(tester);

    expect(find.text('Check that you qualify'), findsOneWidget);
    expect(find.text('File Form N-400'), findsOneWidget);
    expect(find.text('Biometrics appointment'), findsOneWidget);
    expect(find.text('Interview and tests'), findsOneWidget);

    // The oath is at the bottom of a long list.
    await scrollTo(tester, 'steps', find.text('Oath of Allegiance'));
    expect(find.text('Oath of Allegiance'), findsOneWidget);
    expect(find.text('Once you are sworn in'), findsOneWidget);
  });

  testWidgets('each step says when it happens', (tester) async {
    await openGuide(tester);

    expect(
      find.textContaining('Typically 3–8 weeks after filing'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Typically 4–10 months after filing'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Most people are sworn in 6 to 12 months'),
      findsOneWidget,
    );
  });

  testWidgets('the apply tab covers both filing routes and the fees', (
    tester,
  ) async {
    await openGuide(tester);
    await tester.tap(find.text('Apply & cost'));
    await tester.pumpAndSettle();

    expect(find.text('Two ways to file'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('By mail'), findsOneWidget);
    expect(find.text(r'$710'), findsWidgets);
    expect(find.text(r'$760'), findsWidgets);

    await scrollTo(tester, 'apply', find.text('Reduced fee (Form I-942)'));
    expect(find.text(r'$380'), findsOneWidget);
  });

  testWidgets('a proposed fee is never shown as the current one', (
    tester,
  ) async {
    await openGuide(tester);
    await tester.tap(find.text('Apply & cost'));
    await tester.pumpAndSettle();

    await scrollTo(
      tester,
      'apply',
      find.text('A fee increase has been proposed'),
    );
    expect(find.text('PROPOSED, NOT IN EFFECT'), findsOneWidget);
    expect(
      find.textContaining('Nothing changes until a final rule'),
      findsOneWidget,
    );
  });

  testWidgets('the tests tab explains which civics set applies', (
    tester,
  ) async {
    await openGuide(tester);
    await tester.tap(find.text('The tests'));
    await tester.pumpAndSettle();

    await scrollTo(tester, 'tests', find.text('The civics test'));
    expect(find.text('Filed before 20 October 2025'), findsOneWidget);
    expect(find.text('Filed on or after 20 October 2025'), findsOneWidget);

    await scrollTo(tester, 'tests', find.text('65/20'));
    expect(find.text('65/20'), findsOneWidget);
  });

  testWidgets('says when it was last checked, and against what', (
    tester,
  ) async {
    await openGuide(tester);

    await scrollTo(tester, 'steps', find.text('Sources'));
    expect(find.text('https://www.uscis.gov/n-400'), findsOneWidget);
    expect(find.textContaining('Reviewed 2026-'), findsOneWidget);
  });
}
