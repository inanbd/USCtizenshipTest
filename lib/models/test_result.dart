import 'enums.dart';

/// One graded question within a completed mock test.
class AnsweredQuestion {
  const AnsweredQuestion({
    required this.questionId,
    required this.prompt,
    required this.userAnswer,
    required this.acceptedAnswers,
    required this.correct,
  });

  final int questionId;
  final String prompt;
  final String userAnswer;
  final List<String> acceptedAnswers;
  final bool correct;

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'prompt': prompt,
    'userAnswer': userAnswer,
    'acceptedAnswers': acceptedAnswers,
    'correct': correct,
  };

  factory AnsweredQuestion.fromJson(Map<String, dynamic> json) =>
      AnsweredQuestion(
        questionId: json['questionId'] as int,
        prompt: json['prompt'] as String,
        userAnswer: json['userAnswer'] as String,
        acceptedAnswers:
            (json['acceptedAnswers'] as List?)?.cast<String>() ?? const [],
        correct: json['correct'] as bool,
      );
}

/// The outcome of a completed mock test.
class TestResult {
  const TestResult({
    required this.version,
    required this.takenAt,
    required this.answers,
  });

  final TestVersion version;
  final DateTime takenAt;
  final List<AnsweredQuestion> answers;

  int get total => answers.length;
  int get correctCount => answers.where((a) => a.correct).length;

  /// How many correct answers this session needed to pass.
  int get passMark => version.passMarkFor(total);

  /// Graded at the official 60%, scaled to however many questions were asked.
  bool get passed => total > 0 && correctCount >= passMark;

  double get score => total == 0 ? 0 : correctCount / total;

  Map<String, dynamic> toJson() => {
    'version': version.storageKey,
    'takenAt': takenAt.toIso8601String(),
    'answers': answers.map((a) => a.toJson()).toList(),
  };

  factory TestResult.fromJson(Map<String, dynamic> json) => TestResult(
    version: json['version'] == 'v2020' ? TestVersion.v2020 : TestVersion.v2008,
    takenAt: DateTime.parse(json['takenAt'] as String),
    answers: (json['answers'] as List)
        .map((a) => AnsweredQuestion.fromJson(a as Map<String, dynamic>))
        .toList(),
  );
}
