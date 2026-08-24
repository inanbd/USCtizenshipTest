import 'package:citizenship_test/data/question_repository.dart';
import 'package:citizenship_test/models/enums.dart';
import 'package:citizenship_test/models/officials.dart';
import 'package:citizenship_test/models/question.dart';
import 'package:citizenship_test/models/state_info.dart';
import 'package:citizenship_test/providers/mock_test_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final officials = Officials.defaults.copyWith(president: 'Test President');

  const texas = StateInfo(
    code: 'TX',
    name: 'Texas',
    capital: 'Austin',
    governor: 'Jane Governor',
    senators: ['Senator One', 'Senator Two'],
  );

  MockTestController controllerFor(
    List<int> ids, {
    StateInfo? state,
    TestVersion version = TestVersion.v2008,
  }) {
    final questions = ids
        .map((id) => QuestionRepository.byId(version, id))
        .whereType<Question>()
        .toList();
    return MockTestController(
      version: version,
      questions: questions,
      officials: officials,
      state: state,
    );
  }

  group('session flow', () {
    test('starts at the first question and reports totals', () {
      final c = controllerFor([1, 2, 3]);
      expect(c.index, 0);
      expect(c.total, 3);
      expect(c.current.id, 1);
      expect(c.isLast, isFalse);
      expect(c.isFinished, isFalse);
      expect(c.correctSoFar, 0);
    });

    test('advances through questions and stops at the last one', () {
      final c = controllerFor([1, 2]);
      c.next();
      expect(c.index, 1);
      expect(c.isLast, isTrue);
      c.next();
      expect(c.index, 1, reason: 'must not run past the end');
    });

    test('is finished once every question has been answered', () {
      final c = controllerFor([1, 2]);
      c.submit('the Constitution');
      expect(c.isFinished, isFalse);
      c.next();
      c.submit('anything');
      expect(c.isFinished, isTrue);
    });

    test('notifies listeners on submit and next', () {
      final c = controllerFor([1, 2]);
      var notified = 0;
      c.addListener(() => notified++);
      c.submit('the Constitution');
      c.next();
      expect(notified, 2);
    });
  });

  group('grading', () {
    test('grades a correct written answer', () {
      final c = controllerFor([1]); // supreme law of the land
      expect(c.submit('the constitution'), isTrue);
      expect(c.correctSoFar, 1);
      expect(c.answers.single.correct, isTrue);
      expect(c.answers.single.questionId, 1);
    });

    test('grades a wrong answer', () {
      final c = controllerFor([1]);
      expect(c.submit('the declaration of independence'), isFalse);
      expect(c.correctSoFar, 0);
    });

    test('records the user answer trimmed, with the accepted answers', () {
      final c = controllerFor([1]);
      c.submit('  the constitution  ');
      expect(c.answers.single.userAnswer, 'the constitution');
      expect(c.answers.single.acceptedAnswers, ['the Constitution']);
    });

    test('requires both answers on a "name two" question', () {
      final c = controllerFor([45]); // two major political parties
      expect(c.requiredCountFor(c.current), 2);
      expect(c.submit('Democratic'), isFalse);

      final c2 = controllerFor([45]);
      expect(c2.submit('Democratic and Republican'), isTrue);
    });

    test('grades a state-dependent question against the saved state', () {
      final c = controllerFor([44], state: texas); // capital of your state
      expect(c.acceptedFor(c.current), ['Austin']);
      expect(c.submit('Austin'), isTrue);
    });

    test('accepts either senator and only needs one', () {
      final c = controllerFor([20], state: texas);
      expect(c.requiredCountFor(c.current), 1);
      expect(c.submit('Senator Two'), isTrue);
    });

    test('grades a current-officials question from settings', () {
      final c = controllerFor([28]); // name of the President now
      expect(c.acceptedFor(c.current), ['Test President']);
      expect(c.submit('Test President'), isTrue);
    });

    test('marks an unanswerable state question wrong for self-grading', () {
      // No state set, so there is nothing to grade against.
      final c = controllerFor([44]);
      expect(c.acceptedFor(c.current), isEmpty);
      expect(c.submit('Austin'), isFalse);
      expect(c.answers.single.correct, isFalse);
    });

    test('falls back to the official placeholder text when unresolved', () {
      final c = controllerFor([44]);
      c.submit('Austin');
      expect(
        c.answers.single.acceptedAnswers,
        isNotEmpty,
        reason: 'the review screen still needs something to show',
      );
    });
  });

  group('manual override', () {
    test('can mark an auto-graded answer correct', () {
      final c = controllerFor([44]); // unresolved, auto-graded wrong
      c.submit('Austin');
      expect(c.correctSoFar, 0);
      c.overrideLast(correct: true);
      expect(c.correctSoFar, 1);
      expect(
        c.answers.single.userAnswer,
        'Austin',
        reason: 'override must not lose the answer',
      );
    });

    test('can mark an auto-graded answer wrong', () {
      final c = controllerFor([1]);
      c.submit('the constitution');
      expect(c.correctSoFar, 1);
      c.overrideLast(correct: false);
      expect(c.correctSoFar, 0);
    });

    test('override only affects the most recent answer', () {
      final c = controllerFor([1, 2]);
      c.submit('the constitution'); // correct
      c.next();
      c.submit('nonsense'); // wrong
      c.overrideLast(correct: true);
      expect(c.answers[0].correct, isTrue);
      expect(c.answers[1].correct, isTrue);
      expect(c.correctSoFar, 2);
    });

    test('override on an empty session is a no-op', () {
      final c = controllerFor([1]);
      c.overrideLast(correct: true);
      expect(c.answers, isEmpty);
    });

    test('answers list is unmodifiable from outside', () {
      final c = controllerFor([1]);
      c.submit('x');
      expect(() => c.answers.clear(), throwsUnsupportedError);
    });
  });

  group('result', () {
    test('builds a result carrying every answer and the version', () {
      final c = controllerFor([1, 2, 3]);
      c.submit('the constitution');
      c.next();
      c.submit('wrong');
      c.next();
      c.submit('We the People');

      final result = c.buildResult();
      expect(result.version, TestVersion.v2008);
      expect(result.total, 3);
      expect(result.correctCount, 2);
      expect(result.answers.map((a) => a.questionId), [1, 2, 3]);
    });

    test('a 2020 session passes at 12 of 20', () {
      final ids = List.generate(20, (i) => i + 1);
      final c = controllerFor(ids, version: TestVersion.v2020);
      for (var i = 0; i < 20; i++) {
        c.submit(i < 12 ? c.acceptedFor(c.current).firstOrNull ?? '' : 'zzz');
        if (i < 19) c.next();
      }
      final result = c.buildResult();
      expect(result.total, 20);
      expect(result.passed, result.correctCount >= 12);
    });

    test('the result snapshot is independent of later changes', () {
      final c = controllerFor([1, 2]);
      c.submit('the constitution');
      final snapshot = c.buildResult();
      c.next();
      c.submit('more');
      expect(snapshot.total, 1);
      expect(c.buildResult().total, 2);
    });
  });
}
