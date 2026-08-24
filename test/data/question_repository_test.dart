import 'package:citizenship_test/data/question_repository.dart';
import 'package:citizenship_test/models/enums.dart';
import 'package:citizenship_test/models/officials.dart';
import 'package:citizenship_test/models/state_info.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the runtime resolution of answers that depend on the user's state or
/// on who currently holds office.
void main() {
  final officials = Officials(
    president: 'Test President',
    vicePresident: 'Test VP',
    speaker: 'Test Speaker',
    chiefJustice: 'Test Chief',
    presidentParty: 'Test Party',
    asOf: DateTime(2026, 1, 1),
  );

  const texas = StateInfo(
    code: 'TX',
    name: 'Texas',
    capital: 'Austin',
    governor: 'Jane Governor',
    senators: ['Senator One', 'Senator Two'],
    representative: 'Rep Person',
  );

  const dc = StateInfo(
    code: 'DC',
    name: 'District of Columbia',
    capital: 'N/A',
  );

  const bareState = StateInfo(
    code: 'CA',
    name: 'California',
    capital: 'Sacramento',
  );

  // 2008 question ids for the dynamic kinds.
  final qSenator = QuestionRepository.byId(TestVersion.v2008, 20)!;
  final qRep = QuestionRepository.byId(TestVersion.v2008, 23)!;
  final qPresident = QuestionRepository.byId(TestVersion.v2008, 28)!;
  final qChief = QuestionRepository.byId(TestVersion.v2008, 40)!;
  final qGovernor = QuestionRepository.byId(TestVersion.v2008, 43)!;
  final qCapital = QuestionRepository.byId(TestVersion.v2008, 44)!;
  final qParty = QuestionRepository.byId(TestVersion.v2008, 46)!;
  final qFixed = QuestionRepository.byId(TestVersion.v2008, 1)!;

  group('effectiveAnswers - fixed questions', () {
    test('returns the static answers unchanged', () {
      expect(
        QuestionRepository.effectiveAnswers(qFixed, officials: officials),
        ['the Constitution'],
      );
    });

    test('is unaffected by state or officials', () {
      expect(
        QuestionRepository.effectiveAnswers(
          qFixed,
          state: texas,
          officials: officials,
        ),
        QuestionRepository.effectiveAnswers(qFixed, officials: officials),
      );
    });
  });

  group('effectiveAnswers - current officials', () {
    test('resolves each time-sensitive kind from settings', () {
      expect(
        QuestionRepository.effectiveAnswers(qPresident, officials: officials),
        ['Test President'],
      );
      expect(
        QuestionRepository.effectiveAnswers(qChief, officials: officials),
        ['Test Chief'],
      );
      expect(
        QuestionRepository.effectiveAnswers(qParty, officials: officials),
        ['Test Party'],
      );
    });

    test('returns empty when an official has been cleared', () {
      final blank = officials.copyWith(president: '   ');
      expect(
        QuestionRepository.effectiveAnswers(qPresident, officials: blank),
        isEmpty,
      );
    });
  });

  group('effectiveAnswers - state dependent', () {
    test('resolves capital, governor, senators and representative', () {
      expect(
        QuestionRepository.effectiveAnswers(
          qCapital,
          state: texas,
          officials: officials,
        ),
        ['Austin'],
      );
      expect(
        QuestionRepository.effectiveAnswers(
          qGovernor,
          state: texas,
          officials: officials,
        ),
        ['Jane Governor'],
      );
      expect(
        QuestionRepository.effectiveAnswers(
          qSenator,
          state: texas,
          officials: officials,
        ),
        ['Senator One', 'Senator Two'],
      );
      expect(
        QuestionRepository.effectiveAnswers(
          qRep,
          state: texas,
          officials: officials,
        ),
        ['Rep Person'],
      );
    });

    test('returns empty when no state is set', () {
      for (final q in [qCapital, qGovernor, qSenator, qRep]) {
        expect(
          QuestionRepository.effectiveAnswers(q, officials: officials),
          isEmpty,
          reason: 'Q${q.id} without a state',
        );
      }
    });

    test('returns empty for names the user has not filled in yet', () {
      // Capital is bundled so it still resolves; the people do not.
      expect(
        QuestionRepository.effectiveAnswers(
          qCapital,
          state: bareState,
          officials: officials,
        ),
        ['Sacramento'],
      );
      expect(
        QuestionRepository.effectiveAnswers(
          qGovernor,
          state: bareState,
          officials: officials,
        ),
        isEmpty,
      );
      expect(
        QuestionRepository.effectiveAnswers(
          qSenator,
          state: bareState,
          officials: officials,
        ),
        isEmpty,
      );
    });

    test('gives the official D.C. answers', () {
      expect(
        QuestionRepository.effectiveAnswers(
          qCapital,
          state: dc,
          officials: officials,
        ).single,
        contains('not a state'),
      );
      expect(
        QuestionRepository.effectiveAnswers(
          qGovernor,
          state: dc,
          officials: officials,
        ).single,
        contains('does not have a Governor'),
      );
      expect(
        QuestionRepository.effectiveAnswers(
          qSenator,
          state: dc,
          officials: officials,
        ).single,
        contains('no U.S. Senators'),
      );
    });

    test('ignores blank senator entries', () {
      const messy = StateInfo(
        code: 'CA',
        name: 'California',
        capital: 'Sacramento',
        senators: ['  ', 'Real Senator', ''],
      );
      expect(
        QuestionRepository.effectiveAnswers(
          qSenator,
          state: messy,
          officials: officials,
        ),
        ['Real Senator'],
      );
    });
  });

  group('requiredCountFor', () {
    test('only one senator is needed even though two are listed', () {
      final answers = QuestionRepository.effectiveAnswers(
        qSenator,
        state: texas,
        officials: officials,
      );
      expect(answers.length, 2);
      expect(QuestionRepository.requiredCountFor(qSenator, answers), 1);
    });

    test('keeps the declared count for ordinary questions', () {
      final q = QuestionRepository.byId(TestVersion.v2008, 64)!; // name three
      expect(QuestionRepository.requiredCountFor(q, q.answers), 3);
    });
  });

  group('needsUserData', () {
    test('is true for state questions with nothing entered', () {
      expect(
        QuestionRepository.needsUserData(qGovernor, officials: officials),
        isTrue,
      );
    });

    test('is false once the user has entered the data', () {
      expect(
        QuestionRepository.needsUserData(
          qGovernor,
          state: texas,
          officials: officials,
        ),
        isFalse,
      );
    });

    test('is false for fixed and official-based questions', () {
      expect(
        QuestionRepository.needsUserData(qFixed, officials: officials),
        isFalse,
      );
      expect(
        QuestionRepository.needsUserData(qPresident, officials: officials),
        isFalse,
      );
    });
  });

  group('displayAnswer', () {
    test('joins resolved answers for display', () {
      expect(
        QuestionRepository.displayAnswer(qFixed, officials: officials),
        contains('the Constitution'),
      );
    });

    test('prompts the user to set their state when unresolved', () {
      expect(
        QuestionRepository.displayAnswer(qGovernor, officials: officials),
        contains('Set your state info'),
      );
    });

    test('shows how many answers are needed for multi-answer questions', () {
      final q = QuestionRepository.byId(TestVersion.v2008, 64)!;
      expect(
        QuestionRepository.displayAnswer(q, officials: officials),
        startsWith('Give 3:'),
      );
    });
  });
}
