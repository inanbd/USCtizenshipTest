import 'package:citizenship_test/data/question_repository.dart';
import 'package:citizenship_test/data/state_data.dart';
import 'package:citizenship_test/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the datasets to the official USCIS structure. These are the facts a
/// study app must not get wrong, so they are asserted explicitly rather than
/// derived from the data itself.
void main() {
  // The 20 asterisked (65/20 exemption) questions in each official set.
  const senior2008 = {
    6,
    11,
    13,
    17,
    20,
    27,
    28,
    44,
    45,
    49,
    54,
    56,
    70,
    75,
    78,
    85,
    94,
    95,
    97,
    99,
  };
  const senior2020 = {
    2,
    7,
    12,
    20,
    30,
    36,
    38,
    39,
    44,
    52,
    61,
    66,
    74,
    78,
    86,
    94,
    113,
    115,
    121,
    126,
  };

  // Questions whose answer depends on where the applicant lives.
  const stateDependent2008 = {20, 23, 43, 44};
  const stateDependent2020 = {23, 29, 61, 62};

  // Questions whose answer depends on who currently holds office.
  const timeSensitive2008 = {28, 29, 40, 46, 47};
  const timeSensitive2020 = {30, 38, 39, 57};

  // Questions that require more than one answer ("Name two/three/five...").
  const multi2008 = {9: 2, 17: 2, 36: 2, 45: 2, 51: 2, 55: 2, 64: 3, 100: 2};
  const multi2020 = {10: 2, 19: 2, 48: 2, 65: 3, 67: 2, 69: 2, 81: 5, 126: 3};

  group('2008 test (100 questions)', () {
    final questions = QuestionRepository.forVersion(TestVersion.v2008);

    test('has exactly 100 questions numbered 1-100', () {
      expect(questions.length, 100);
      expect(
        questions.map((q) => q.id).toList(),
        List.generate(100, (i) => i + 1),
      );
    });

    test('marks exactly the official 65/20 questions', () {
      final marked = questions.where((q) => q.senior).map((q) => q.id).toSet();
      expect(marked, senior2008);
      expect(marked.length, 20);
    });

    test('flags exactly the state-dependent questions', () {
      final flagged = questions
          .where((q) => q.isStateDependent)
          .map((q) => q.id)
          .toSet();
      expect(flagged, stateDependent2008);
    });

    test('flags exactly the time-sensitive questions', () {
      final flagged = questions
          .where((q) => q.isTimeSensitive)
          .map((q) => q.id)
          .toSet();
      expect(flagged, timeSensitive2008);
    });

    test('requires the right number of answers on multi-answer questions', () {
      for (final q in questions) {
        expect(
          q.requiredCount,
          multi2008[q.id] ?? 1,
          reason: 'Q${q.id}: "${q.prompt}"',
        );
      }
    });

    test('asks 10 questions and passes at 6', () {
      expect(TestVersion.v2008.askedCount, 10);
      expect(TestVersion.v2008.passCount, 6);
    });
  });

  group('2020 test (128 questions)', () {
    final questions = QuestionRepository.forVersion(TestVersion.v2020);

    test('has exactly 128 questions numbered 1-128', () {
      expect(questions.length, 128);
      expect(
        questions.map((q) => q.id).toList(),
        List.generate(128, (i) => i + 1),
      );
    });

    test('marks exactly the official 65/20 questions', () {
      final marked = questions.where((q) => q.senior).map((q) => q.id).toSet();
      expect(marked, senior2020);
      expect(marked.length, 20);
    });

    test('flags exactly the state-dependent questions', () {
      final flagged = questions
          .where((q) => q.isStateDependent)
          .map((q) => q.id)
          .toSet();
      expect(flagged, stateDependent2020);
    });

    test('flags exactly the time-sensitive questions', () {
      final flagged = questions
          .where((q) => q.isTimeSensitive)
          .map((q) => q.id)
          .toSet();
      expect(flagged, timeSensitive2020);
    });

    test('requires the right number of answers on multi-answer questions', () {
      for (final q in questions) {
        expect(
          q.requiredCount,
          multi2020[q.id] ?? 1,
          reason: 'Q${q.id}: "${q.prompt}"',
        );
      }
    });

    test('asks 20 questions and passes at 12', () {
      expect(TestVersion.v2020.askedCount, 20);
      expect(TestVersion.v2020.passCount, 12);
    });

    test('spot-checks known official answers', () {
      final q2 = QuestionRepository.byId(TestVersion.v2020, 2)!;
      expect(q2.prompt, 'What is the supreme law of the land?');
      expect(q2.answers, contains('(U.S.) Constitution'));

      final q124 = QuestionRepository.byId(TestVersion.v2020, 124)!;
      expect(q124.answers, contains('Out of many, one'));
    });
  });

  group('both versions', () {
    for (final version in TestVersion.values) {
      final questions = QuestionRepository.forVersion(version);

      test('${version.shortLabel}: every question is well formed', () {
        for (final q in questions) {
          expect(q.prompt.trim(), isNotEmpty, reason: 'Q${q.id} prompt');
          expect(q.answers, isNotEmpty, reason: 'Q${q.id} answers');
          for (final a in q.answers) {
            expect(a.trim(), isNotEmpty, reason: 'Q${q.id} blank answer');
          }
          expect(q.section.trim(), isNotEmpty, reason: 'Q${q.id} section');
          expect(q.version, version);
          expect(q.requiredCount, greaterThanOrEqualTo(1));
        }
      });

      test(
        '${version.shortLabel}: multi-answer questions list enough answers',
        () {
          for (final q in questions.where((q) => q.requiredCount > 1)) {
            expect(
              q.answers.length,
              greaterThanOrEqualTo(q.requiredCount),
              reason:
                  'Q${q.id} needs ${q.requiredCount} answers but lists '
                  '${q.answers.length}',
            );
          }
        },
      );

      test('${version.shortLabel}: dynamic questions carry guidance notes', () {
        for (final q in questions.where((q) => q.isDynamic)) {
          expect(q.note, isNotNull, reason: 'Q${q.id} should explain itself');
        }
      });

      test('${version.shortLabel}: storage keys are unique', () {
        final keys = questions.map((q) => q.key).toSet();
        expect(keys.length, questions.length);
      });

      test('${version.shortLabel}: byId round-trips, unknown id is null', () {
        for (final q in questions) {
          expect(QuestionRepository.byId(version, q.id)?.prompt, q.prompt);
        }
        expect(QuestionRepository.byId(version, 9999), isNull);
      });

      test(
        '${version.shortLabel}: senior() returns only starred questions',
        () {
          final senior = QuestionRepository.senior(version);
          expect(senior.length, 20);
          expect(senior.every((q) => q.senior), isTrue);
        },
      );

      test('${version.shortLabel}: sections are ordered and non-empty', () {
        final sections = QuestionRepository.sections(version);
        expect(sections, isNotEmpty);
        expect(
          sections.toSet().length,
          sections.length,
          reason: 'sections should not repeat',
        );
      });
    }

    test('keys do not collide across versions', () {
      final all = [
        ...QuestionRepository.forVersion(TestVersion.v2008),
        ...QuestionRepository.forVersion(TestVersion.v2020),
      ];
      expect(all.map((q) => q.key).toSet().length, all.length);
    });
  });

  group('state data', () {
    test('covers all 50 states plus D.C.', () {
      expect(kStates.length, 51);
      expect(kStates.map((s) => s.code).toSet().length, 51);
      expect(kStates.any((s) => s.code == 'DC'), isTrue);
    });

    test('every state has a name and capital', () {
      for (final s in kStates) {
        expect(s.name.trim(), isNotEmpty);
        expect(s.capital.trim(), isNotEmpty, reason: '${s.code} capital');
        expect(s.code.length, 2);
      }
    });

    test('spot-checks capitals that are commonly confused', () {
      expect(stateByCode('CA')!.capital, 'Sacramento');
      expect(stateByCode('NY')!.capital, 'Albany');
      expect(stateByCode('IL')!.capital, 'Springfield');
      expect(stateByCode('PA')!.capital, 'Harrisburg');
      expect(stateByCode('AK')!.capital, 'Juneau');
      expect(stateByCode('NV')!.capital, 'Carson City');
    });

    test('lookup is case-insensitive and returns null for unknown codes', () {
      expect(stateByCode('tx')!.name, 'Texas');
      expect(stateByCode('ZZ'), isNull);
    });

    test('D.C. is flagged as not a state', () {
      expect(stateByCode('DC')!.isDistrictOfColumbia, isTrue);
      expect(stateByCode('TX')!.isDistrictOfColumbia, isFalse);
    });
  });
}
