import 'package:flutter/foundation.dart';

import '../data/question_repository.dart';
import '../models/enums.dart';
import '../models/officials.dart';
import '../models/question.dart';
import '../models/state_info.dart';
import '../models/test_result.dart';
import '../services/answer_matcher.dart';

/// Drives a single mock-test session: current question, grading, and the
/// running list of answers. State/official-dependent answers are resolved with
/// the [officials] and [state] supplied at construction.
class MockTestController extends ChangeNotifier {
  MockTestController({
    required this.version,
    required this.questions,
    required this.officials,
    required this.state,
  });

  final TestVersion version;
  final List<Question> questions;
  final Officials officials;
  final StateInfo? state;

  int _index = 0;
  final List<AnsweredQuestion> _answers = [];

  int get index => _index;
  int get total => questions.length;
  bool get isLast => _index >= questions.length - 1;
  bool get isFinished => _answers.length >= questions.length;
  Question get current => questions[_index];
  List<AnsweredQuestion> get answers => List.unmodifiable(_answers);

  int get correctSoFar => _answers.where((a) => a.correct).length;

  /// How many correct answers this session needs to pass (60%, scaled to the
  /// number of questions actually asked).
  int get passMark => version.passMarkFor(total);

  List<String> acceptedFor(Question q) => QuestionRepository.effectiveAnswers(
    q,
    state: state,
    officials: officials,
  );

  int requiredCountFor(Question q) =>
      QuestionRepository.requiredCountFor(q, acceptedFor(q));

  /// Grades [userAnswer] for the current question and records the result.
  /// Returns whether it was judged correct.
  bool submit(String userAnswer) {
    final q = current;
    final accepted = acceptedFor(q);
    final correct = accepted.isEmpty
        ? false
        : AnswerMatcher.isCorrect(
            userAnswer,
            accepted,
            requiredCount: requiredCountFor(q),
          );
    _answers.add(
      AnsweredQuestion(
        questionId: q.id,
        prompt: q.prompt,
        userAnswer: userAnswer.trim(),
        acceptedAnswers: accepted.isEmpty ? q.answers : accepted,
        correct: correct,
      ),
    );
    notifyListeners();
    return correct;
  }

  /// Lets the user override auto-grading for the most recent answer.
  void overrideLast({required bool correct}) {
    if (_answers.isEmpty) return;
    final last = _answers.removeLast();
    _answers.add(
      AnsweredQuestion(
        questionId: last.questionId,
        prompt: last.prompt,
        userAnswer: last.userAnswer,
        acceptedAnswers: last.acceptedAnswers,
        correct: correct,
      ),
    );
    notifyListeners();
  }

  void next() {
    if (_index < questions.length - 1) {
      _index++;
      notifyListeners();
    }
  }

  TestResult buildResult() => TestResult(
    version: version,
    takenAt: DateTime.now(),
    answers: List.of(_answers),
  );
}
