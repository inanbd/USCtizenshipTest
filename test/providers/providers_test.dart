import 'package:citizenship_test/data/question_repository.dart';
import 'package:citizenship_test/models/enums.dart';
import 'package:citizenship_test/models/officials.dart';
import 'package:citizenship_test/models/state_info.dart';
import 'package:citizenship_test/models/test_result.dart';
import 'package:citizenship_test/providers/progress_provider.dart';
import 'package:citizenship_test/providers/settings_provider.dart';
import 'package:citizenship_test/providers/study_plan_provider.dart';
import 'package:citizenship_test/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider', () {
    late StorageService storage;

    setUp(() async {
      storage = await freshStorage();
    });

    test('starts on the 2008 test with system theme', () {
      final settings = SettingsProvider(storage);
      expect(settings.testVersion, TestVersion.v2008);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.stateInfo, isNull);
      expect(settings.seniorOnly, isFalse);
    });

    test('persists the chosen test version across restarts', () async {
      final settings = SettingsProvider(storage);
      await settings.setTestVersion(TestVersion.v2020);
      expect(SettingsProvider(storage).testVersion, TestVersion.v2020);
    });

    test('persists theme, speech rate and 65/20 mode', () async {
      final settings = SettingsProvider(storage);
      await settings.setThemeMode(ThemeMode.dark);
      await settings.setTtsRate(0.6);
      await settings.setSeniorOnly(true);

      final reloaded = SettingsProvider(storage);
      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.ttsRate, 0.6);
      expect(reloaded.seniorOnly, isTrue);
    });

    test('persists state info and current officials', () async {
      final settings = SettingsProvider(storage);
      const info = StateInfo(
        code: 'TX',
        name: 'Texas',
        capital: 'Austin',
        governor: 'Gov Person',
        senators: ['Sen One', 'Sen Two'],
      );
      await settings.setStateInfo(info);
      await settings.setOfficials(
        Officials.defaults.copyWith(president: 'Someone Else'),
      );

      final reloaded = SettingsProvider(storage);
      expect(reloaded.stateInfo!.code, 'TX');
      expect(reloaded.stateInfo!.senators, ['Sen One', 'Sen Two']);
      expect(reloaded.officials.president, 'Someone Else');
    });

    test('clearing state info removes it from storage', () async {
      final settings = SettingsProvider(storage);
      await settings.setStateInfo(
        const StateInfo(code: 'CA', name: 'California', capital: 'Sacramento'),
      );
      await settings.setStateInfo(null);
      expect(SettingsProvider(storage).stateInfo, isNull);
    });

    test('persists the Congress API key', () async {
      final settings = SettingsProvider(storage);
      await settings.setCongressApiKey('abc123');
      expect(SettingsProvider(storage).congressApiKey, 'abc123');
    });

    test('notifies listeners when settings change', () async {
      final settings = SettingsProvider(storage);
      var notified = 0;
      settings.addListener(() => notified++);
      await settings.setTestVersion(TestVersion.v2020);
      await settings.setThemeMode(ThemeMode.light);
      expect(notified, 2);
    });

    test('setting the same version again does not notify', () async {
      final settings = SettingsProvider(storage);
      var notified = 0;
      settings.addListener(() => notified++);
      await settings.setTestVersion(TestVersion.v2008);
      expect(notified, 0);
    });
  });

  group('ProgressProvider', () {
    late StorageService storage;

    setUp(() async {
      storage = await freshStorage();
    });

    test('starts with nothing learned', () {
      final progress = ProgressProvider(storage);
      expect(progress.learnedCount(TestVersion.v2008), 0);
      expect(progress.history, isEmpty);
    });

    test('toggles and persists learned questions', () async {
      final progress = ProgressProvider(storage);
      await progress.toggleLearned(TestVersion.v2008, 5);
      expect(progress.isLearned(TestVersion.v2008, 5), isTrue);

      final reloaded = ProgressProvider(storage);
      expect(reloaded.isLearned(TestVersion.v2008, 5), isTrue);

      await reloaded.toggleLearned(TestVersion.v2008, 5);
      expect(reloaded.isLearned(TestVersion.v2008, 5), isFalse);
      expect(
        ProgressProvider(storage).isLearned(TestVersion.v2008, 5),
        isFalse,
      );
    });

    test('keeps the two test versions separate', () async {
      final progress = ProgressProvider(storage);
      await progress.toggleLearned(TestVersion.v2008, 1);
      expect(progress.isLearned(TestVersion.v2008, 1), isTrue);
      expect(progress.isLearned(TestVersion.v2020, 1), isFalse);
    });

    test('setLearned is idempotent', () async {
      final progress = ProgressProvider(storage);
      await progress.setLearned(TestVersion.v2008, 3, true);
      await progress.setLearned(TestVersion.v2008, 3, true);
      expect(progress.learnedCount(TestVersion.v2008), 1);
      await progress.setLearned(TestVersion.v2008, 3, false);
      expect(progress.learnedCount(TestVersion.v2008), 0);
    });

    test('toggles and persists favorites', () async {
      final progress = ProgressProvider(storage);
      await progress.toggleFavorite(TestVersion.v2020, 42);
      expect(progress.isFavorite(TestVersion.v2020, 42), isTrue);
      expect(
        ProgressProvider(storage).isFavorite(TestVersion.v2020, 42),
        isTrue,
      );
    });

    test('resetting learned marks clears only that version', () async {
      final progress = ProgressProvider(storage);
      await progress.toggleLearned(TestVersion.v2008, 1);
      await progress.toggleLearned(TestVersion.v2020, 1);
      await progress.resetLearned(TestVersion.v2008);
      expect(progress.learnedCount(TestVersion.v2008), 0);
      expect(progress.learnedCount(TestVersion.v2020), 1);
    });

    test('stores test results newest first and persists them', () async {
      final progress = ProgressProvider(storage);
      await progress.addResult(
        TestResult(
          version: TestVersion.v2008,
          takenAt: DateTime(2026, 1, 1),
          answers: const [],
        ),
      );
      await progress.addResult(
        TestResult(
          version: TestVersion.v2008,
          takenAt: DateTime(2026, 2, 2),
          answers: const [],
        ),
      );

      expect(progress.history.first.takenAt, DateTime(2026, 2, 2));
      expect(ProgressProvider(storage).history.length, 2);
    });

    test('filters history by version', () async {
      final progress = ProgressProvider(storage);
      await progress.addResult(
        TestResult(
          version: TestVersion.v2008,
          takenAt: DateTime(2026, 1, 1),
          answers: const [],
        ),
      );
      await progress.addResult(
        TestResult(
          version: TestVersion.v2020,
          takenAt: DateTime(2026, 1, 2),
          answers: const [],
        ),
      );

      expect(progress.historyFor(TestVersion.v2008).length, 1);
      expect(progress.historyFor(TestVersion.v2020).length, 1);
    });

    test('caps stored history at 100 results', () async {
      final progress = ProgressProvider(storage);
      for (var i = 0; i < 105; i++) {
        await progress.addResult(
          TestResult(
            version: TestVersion.v2008,
            takenAt: DateTime(2026, 1, 1).add(Duration(days: i)),
            answers: const [],
          ),
        );
      }
      expect(progress.history.length, 100);
      // The oldest entries were dropped, newest kept.
      expect(
        progress.history.first.takenAt,
        DateTime(2026, 1, 1).add(const Duration(days: 104)),
      );
    });

    test('clears history', () async {
      final progress = ProgressProvider(storage);
      await progress.addResult(
        TestResult(
          version: TestVersion.v2008,
          takenAt: DateTime(2026, 1, 1),
          answers: const [],
        ),
      );
      await progress.clearHistory();
      expect(progress.history, isEmpty);
      expect(ProgressProvider(storage).history, isEmpty);
    });
  });

  group('StudyPlanProvider', () {
    late StorageService storage;

    setUp(() async {
      storage = await freshStorage();
    });

    test('starts with no plan', () {
      expect(StudyPlanProvider(storage).hasPlan, isFalse);
    });

    test('creates and persists a plan', () async {
      final provider = StudyPlanProvider(storage);
      await provider.createPlan(
        version: TestVersion.v2020,
        testDate: DateTime.now().add(const Duration(days: 7)),
      );
      expect(provider.hasPlan, isTrue);
      expect(provider.plan!.version, TestVersion.v2020);

      final reloaded = StudyPlanProvider(storage);
      expect(reloaded.hasPlan, isTrue);
      expect(reloaded.plan!.days.length, provider.plan!.days.length);
    });

    test('marks days complete and persists them', () async {
      final provider = StudyPlanProvider(storage);
      await provider.createPlan(
        version: TestVersion.v2008,
        testDate: DateTime.now().add(const Duration(days: 5)),
      );
      await provider.toggleDayComplete(1);
      expect(provider.plan!.completedDayNumbers, {1});
      expect(StudyPlanProvider(storage).plan!.completedDayNumbers, {1});

      await provider.toggleDayComplete(1);
      expect(provider.plan!.completedDayNumbers, isEmpty);
    });

    test('finds today in the plan', () async {
      final provider = StudyPlanProvider(storage);
      await provider.createPlan(
        version: TestVersion.v2008,
        testDate: DateTime.now().add(const Duration(days: 5)),
      );
      expect(provider.todayDay, isNotNull);
      expect(provider.todayDay!.dayNumber, 1);
    });

    test('clears the plan', () async {
      final provider = StudyPlanProvider(storage);
      await provider.createPlan(
        version: TestVersion.v2008,
        testDate: DateTime.now().add(const Duration(days: 3)),
      );
      await provider.clearPlan();
      expect(provider.hasPlan, isFalse);
      expect(StudyPlanProvider(storage).hasPlan, isFalse);
    });

    test('a 65/20 plan only contains starred questions', () async {
      final provider = StudyPlanProvider(storage);
      await provider.createPlan(
        version: TestVersion.v2020,
        testDate: DateTime.now().add(const Duration(days: 6)),
        seniorOnly: true,
      );
      final taught = <int>{};
      for (final d in provider.plan!.days.where((d) => !d.isReviewDay)) {
        taught.addAll(d.questionIds);
      }
      expect(taught.length, 20);
      expect(
        taught,
        QuestionRepository.senior(TestVersion.v2020).map((q) => q.id).toSet(),
      );
    });

    test('ignores corrupt stored plan data instead of crashing', () async {
      final store = await freshStorage({'studyPlan.current': 'not json'});
      expect(StudyPlanProvider(store).hasPlan, isFalse);
    });
  });

  group('StorageService', () {
    test('stores and reads typed values', () async {
      final storage = await freshStorage();
      await storage.setString('s', 'hello');
      await storage.setBool('b', true);
      await storage.setDouble('d', 1.5);
      await storage.setStringList('l', ['a', 'b']);

      expect(storage.getString('s'), 'hello');
      expect(storage.getBool('b'), isTrue);
      expect(storage.getDouble('d'), 1.5);
      expect(storage.getStringList('l'), ['a', 'b']);
    });

    test('stores and reads JSON objects and lists', () async {
      final storage = await freshStorage();
      await storage.setJson('obj', {'a': 1});
      await storage.setJsonList('list', [
        {'a': 1},
        {'b': 2},
      ]);
      expect(storage.getJson('obj'), {'a': 1});
      expect(storage.getJsonList('list')!.length, 2);
    });

    test('returns null for missing or corrupt JSON', () async {
      final storage = await freshStorage({'bad': 'not json'});
      expect(storage.getJson('missing'), isNull);
      expect(storage.getJson('bad'), isNull);
      expect(storage.getJsonList('bad'), isNull);
      expect(storage.getStringList('missing'), isEmpty);
    });

    test('removes values', () async {
      final storage = await freshStorage();
      await storage.setString('k', 'v');
      await storage.remove('k');
      expect(storage.getString('k'), isNull);
    });
  });
}
