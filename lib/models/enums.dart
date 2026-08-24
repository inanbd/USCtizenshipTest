/// Which official USCIS civics test a question belongs to.
enum TestVersion {
  /// The 2008 test — 100 questions. Taken by most current applicants.
  v2008,

  /// The redesigned 2020 test — 128 questions.
  v2020,
}

extension TestVersionX on TestVersion {
  String get label => switch (this) {
        TestVersion.v2008 => '2008 test (100 questions)',
        TestVersion.v2020 => '2020 test (128 questions)',
      };

  String get shortLabel => switch (this) {
        TestVersion.v2008 => '2008 · 100Q',
        TestVersion.v2020 => '2020 · 128Q',
      };

  /// Number of questions asked in the real interview.
  int get askedCount => switch (this) {
        TestVersion.v2008 => 10,
        TestVersion.v2020 => 20,
      };

  /// Number of correct answers needed to pass.
  int get passCount => switch (this) {
        TestVersion.v2008 => 6,
        TestVersion.v2020 => 12,
      };

  String get storageKey => switch (this) {
        TestVersion.v2008 => 'v2008',
        TestVersion.v2020 => 'v2020',
      };
}

/// Top-level USCIS grouping for a question.
enum QuestionCategory {
  americanGovernment,
  americanHistory,
  integratedCivics,
}

extension QuestionCategoryX on QuestionCategory {
  String get label => switch (this) {
        QuestionCategory.americanGovernment => 'American Government',
        QuestionCategory.americanHistory => 'American History',
        QuestionCategory.integratedCivics => 'Integrated Civics',
      };
}

/// How the accepted answer for a question is produced.
///
/// Most questions have [fixed] answers that never change. Some depend on the
/// applicant's state, and some depend on who currently holds an office. Those
/// are resolved at runtime from the user's saved state info and the
/// "current officials" settings, and can be refreshed from public APIs.
enum AnswerKind {
  fixed,

  // Time-sensitive federal officials (verify at uscis.gov/citizenship/testupdates).
  president,
  vicePresident,
  speaker,
  chiefJustice,
  presidentParty,

  // State-dependent answers (resolved from the user's saved state info).
  stateCapital,
  governor,
  stateSenator,
  stateRepresentative,
}

extension AnswerKindX on AnswerKind {
  bool get isFixed => this == AnswerKind.fixed;

  bool get isStateDependent => switch (this) {
        AnswerKind.stateCapital ||
        AnswerKind.governor ||
        AnswerKind.stateSenator ||
        AnswerKind.stateRepresentative =>
          true,
        _ => false,
      };

  bool get isTimeSensitive => switch (this) {
        AnswerKind.president ||
        AnswerKind.vicePresident ||
        AnswerKind.speaker ||
        AnswerKind.chiefJustice ||
        AnswerKind.presidentParty =>
          true,
        _ => false,
      };

  bool get isDynamic => !isFixed;
}
