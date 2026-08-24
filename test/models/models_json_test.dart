import 'package:citizenship_test/models/enums.dart';
import 'package:citizenship_test/models/officials.dart';
import 'package:citizenship_test/models/state_info.dart';
import 'package:citizenship_test/models/study_plan.dart';
import 'package:citizenship_test/models/test_result.dart';
import 'package:flutter_test/flutter_test.dart';

/// Everything persisted to disk must survive a JSON round-trip, or the user
/// loses progress between launches.
void main() {
  group('StateInfo', () {
    const info = StateInfo(
      code: 'TX',
      name: 'Texas',
      capital: 'Austin',
      governor: 'Jane Governor',
      senators: ['A Senator', 'B Senator'],
      representative: 'C Rep',
      source: StateDataSource.manual,
    );

    test('round-trips through JSON', () {
      final restored = StateInfo.fromJson(info.toJson());
      expect(restored.code, 'TX');
      expect(restored.name, 'Texas');
      expect(restored.capital, 'Austin');
      expect(restored.governor, 'Jane Governor');
      expect(restored.senators, ['A Senator', 'B Senator']);
      expect(restored.representative, 'C Rep');
      expect(restored.source, StateDataSource.manual);
    });

    test('round-trips the updated timestamp', () {
      final stamped = info.copyWith(updatedAt: DateTime(2026, 3, 4, 5, 6));
      final restored = StateInfo.fromJson(stamped.toJson());
      expect(restored.updatedAt, DateTime(2026, 3, 4, 5, 6));
    });

    test(
      'copyWith preserves identity fields and changes only what is given',
      () {
        final updated = info.copyWith(governor: 'New Gov');
        expect(updated.governor, 'New Gov');
        expect(updated.code, info.code);
        expect(updated.capital, info.capital);
        expect(updated.senators, info.senators);
      },
    );

    test('reports which fields are filled in', () {
      expect(info.hasGovernor, isTrue);
      expect(info.hasSenators, isTrue);
      expect(info.hasRepresentative, isTrue);

      const bare = StateInfo(
        code: 'CA',
        name: 'California',
        capital: 'Sacramento',
      );
      expect(bare.hasGovernor, isFalse);
      expect(bare.hasSenators, isFalse);
      expect(bare.hasRepresentative, isFalse);
    });

    test('blank-only values do not count as filled in', () {
      const blank = StateInfo(
        code: 'CA',
        name: 'California',
        capital: 'Sacramento',
        governor: '   ',
        senators: ['  ', ''],
      );
      expect(blank.hasGovernor, isFalse);
      expect(blank.hasSenators, isFalse);
    });

    test('defaults missing optional fields when reading old data', () {
      final restored = StateInfo.fromJson({
        'code': 'NV',
        'name': 'Nevada',
        'capital': 'Carson City',
      });
      expect(restored.senators, isEmpty);
      expect(restored.governor, isNull);
      expect(restored.source, StateDataSource.bundled);
    });
  });

  group('Officials', () {
    test('round-trips through JSON', () {
      final officials = Officials(
        president: 'P',
        vicePresident: 'V',
        speaker: 'S',
        chiefJustice: 'C',
        presidentParty: 'Party',
        asOf: DateTime(2026, 1, 2),
      );
      final restored = Officials.fromJson(officials.toJson());
      expect(restored.president, 'P');
      expect(restored.vicePresident, 'V');
      expect(restored.speaker, 'S');
      expect(restored.chiefJustice, 'C');
      expect(restored.presidentParty, 'Party');
      expect(restored.asOf, DateTime(2026, 1, 2));
    });

    test('falls back to defaults for missing fields', () {
      final restored = Officials.fromJson(const {});
      expect(restored.president, Officials.defaults.president);
      expect(restored.chiefJustice, Officials.defaults.chiefJustice);
    });

    test('forKind returns the matching officeholder', () {
      final o = Officials.defaults;
      expect(o.forKind(AnswerKind.president), o.president);
      expect(o.forKind(AnswerKind.vicePresident), o.vicePresident);
      expect(o.forKind(AnswerKind.speaker), o.speaker);
      expect(o.forKind(AnswerKind.chiefJustice), o.chiefJustice);
      expect(o.forKind(AnswerKind.presidentParty), o.presidentParty);
      expect(o.forKind(AnswerKind.stateCapital), '');
    });

    test('defaults are all populated', () {
      final d = Officials.defaults;
      for (final v in [
        d.president,
        d.vicePresident,
        d.speaker,
        d.chiefJustice,
        d.presidentParty,
      ]) {
        expect(v.trim(), isNotEmpty);
      }
    });
  });

  group('TestResult', () {
    TestResult resultWith(int correct, int total, TestVersion version) =>
        TestResult(
          version: version,
          takenAt: DateTime(2026, 5, 5),
          answers: List.generate(
            total,
            (i) => AnsweredQuestion(
              questionId: i + 1,
              prompt: 'Q${i + 1}',
              userAnswer: 'a',
              acceptedAnswers: const ['a'],
              correct: i < correct,
            ),
          ),
        );

    test('round-trips through JSON', () {
      final result = resultWith(7, 10, TestVersion.v2008);
      final restored = TestResult.fromJson(result.toJson());
      expect(restored.version, TestVersion.v2008);
      expect(restored.takenAt, DateTime(2026, 5, 5));
      expect(restored.total, 10);
      expect(restored.correctCount, 7);
      expect(restored.answers.first.prompt, 'Q1');
    });

    test('scores and pass/fail follow the version threshold', () {
      expect(resultWith(6, 10, TestVersion.v2008).passed, isTrue);
      expect(resultWith(5, 10, TestVersion.v2008).passed, isFalse);
      expect(resultWith(12, 20, TestVersion.v2020).passed, isTrue);
      expect(resultWith(11, 20, TestVersion.v2020).passed, isFalse);
    });

    test('computes the score fraction', () {
      expect(resultWith(5, 10, TestVersion.v2008).score, 0.5);
    });

    test('an empty result scores zero without dividing by zero', () {
      final empty = TestResult(
        version: TestVersion.v2008,
        takenAt: DateTime(2026, 1, 1),
        answers: const [],
      );
      expect(empty.score, 0);
      expect(empty.total, 0);
    });
  });

  group('StudyPlan', () {
    final plan = StudyPlan(
      version: TestVersion.v2020,
      createdAt: DateTime(2026, 2, 1),
      testDate: DateTime(2026, 2, 10),
      days: [
        StudyDay(
          dayNumber: 1,
          date: DateTime(2026, 2, 1),
          questionIds: const [1, 2, 3],
          isReviewDay: false,
        ),
        StudyDay(
          dayNumber: 2,
          date: DateTime(2026, 2, 2),
          questionIds: const [1, 2, 3],
          isReviewDay: true,
        ),
      ],
      completedDayNumbers: const {1},
    );

    test('round-trips through JSON', () {
      final restored = StudyPlan.fromJson(plan.toJson());
      expect(restored.version, TestVersion.v2020);
      expect(restored.testDate, DateTime(2026, 2, 10));
      expect(restored.days.length, 2);
      expect(restored.days.first.questionIds, [1, 2, 3]);
      expect(restored.days[1].isReviewDay, isTrue);
      expect(restored.completedDayNumbers, {1});
    });

    test('tracks completion progress', () {
      expect(plan.totalDays, 2);
      expect(plan.completedCount, 1);
      expect(plan.progress, 0.5);
    });

    test('copyWith replaces only the completed set', () {
      final updated = plan.copyWith(completedDayNumbers: {1, 2});
      expect(updated.progress, 1.0);
      expect(updated.days, plan.days);
      expect(updated.testDate, plan.testDate);
    });
  });

  group('TestVersion', () {
    test('exposes stable storage keys and labels', () {
      expect(TestVersion.v2008.storageKey, 'v2008');
      expect(TestVersion.v2020.storageKey, 'v2020');
      expect(TestVersion.v2008.label, contains('100'));
      expect(TestVersion.v2020.label, contains('128'));
    });
  });

  group('AnswerKind', () {
    test('classifies fixed, state-dependent and time-sensitive answers', () {
      expect(AnswerKind.fixed.isFixed, isTrue);
      expect(AnswerKind.fixed.isDynamic, isFalse);

      expect(AnswerKind.stateCapital.isStateDependent, isTrue);
      expect(AnswerKind.governor.isStateDependent, isTrue);
      expect(AnswerKind.stateSenator.isStateDependent, isTrue);
      expect(AnswerKind.stateRepresentative.isStateDependent, isTrue);

      expect(AnswerKind.president.isTimeSensitive, isTrue);
      expect(AnswerKind.speaker.isTimeSensitive, isTrue);
      expect(AnswerKind.president.isStateDependent, isFalse);
      expect(AnswerKind.stateCapital.isTimeSensitive, isFalse);
    });
  });
}
