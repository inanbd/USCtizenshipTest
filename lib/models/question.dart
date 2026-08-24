import 'enums.dart';

/// A single civics question from an official USCIS test.
class Question {
  const Question({
    required this.id,
    required this.version,
    required this.category,
    required this.section,
    required this.prompt,
    required this.answers,
    this.kind = AnswerKind.fixed,
    this.senior = false,
    this.requiredCount = 1,
    this.note,
  });

  /// Official question number within its test version (1-based).
  final int id;

  final TestVersion version;
  final QuestionCategory category;

  /// USCIS subsection, e.g. "Principles of American Democracy".
  final String section;

  final String prompt;

  /// The statically-listed accepted answers. For [AnswerKind.fixed] these are
  /// the answers; for dynamic kinds they are the official placeholder text
  /// (e.g. "Answers will vary") and the real answers are resolved at runtime.
  final List<String> answers;

  final AnswerKind kind;

  /// True if marked with an asterisk for the 65/20 exemption.
  final bool senior;

  /// How many distinct answers the applicant must give ("Name two…" -> 2).
  final int requiredCount;

  /// Extra guidance shown to the user (official notes, verify reminders, etc.).
  final String? note;

  /// A stable key used for progress/persistence.
  String get key => '${version.storageKey}_$id';

  bool get isDynamic => kind.isDynamic;
  bool get isStateDependent => kind.isStateDependent;
  bool get isTimeSensitive => kind.isTimeSensitive;
}
