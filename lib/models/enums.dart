/// Which official USCIS civics test a question belongs to.
enum TestVersion {
  /// The 2008 test — 100 questions. Taken by most current applicants.
  v2008,

  /// The redesigned 2020 test — 128 questions. Adopted in December 2020 and
  /// rescinded in 2021, so nobody sits it today; kept for reference.
  v2020,

  /// The 2025 test — 128 questions, M-1778 (09/25). Taken by anyone who filed
  /// Form N-400 on or after 20 October 2025, so this is the current exam.
  v2025,
}

extension TestVersionX on TestVersion {
  String get label => switch (this) {
    TestVersion.v2008 => '2008 test (100 questions)',
    TestVersion.v2020 => '2020 test (128 questions)',
    TestVersion.v2025 => '2025 test (128 questions)',
  };

  String get shortLabel => switch (this) {
    TestVersion.v2008 => '2008 · 100Q',
    TestVersion.v2020 => '2020 · 128Q',
    TestVersion.v2025 => '2025 · 128Q',
  };

  /// The test this applicant sits, based on when they filed Form N-400.
  /// Shown so someone picking a set knows which one applies to them.
  String get applicability => switch (this) {
    TestVersion.v2008 => 'If you filed Form N-400 before 20 Oct 2025',
    TestVersion.v2020 => 'Withdrawn in 2021 — nobody sits this today',
    TestVersion.v2025 => 'If you filed Form N-400 on or after 20 Oct 2025',
  };

  /// True for the test currently administered at interviews.
  bool get isCurrent => this == TestVersion.v2025;

  /// Number of questions asked in the real interview.
  int get askedCount => switch (this) {
    TestVersion.v2008 => 10,
    TestVersion.v2020 => 20,
    TestVersion.v2025 => 20,
  };

  /// Number of correct answers needed to pass the real interview.
  int get passCount => switch (this) {
    TestVersion.v2008 => 6,
    TestVersion.v2020 => 12,
    TestVersion.v2025 => 12,
  };

  /// How many questions a 65/20 applicant is asked, on any version.
  ///
  /// The exemption did not change with the test: someone 65 or older with 20
  /// years as a permanent resident studies only the 20 marked questions and is
  /// asked up to 10 of them — not the 20 the general 2025 test asks.
  int get seniorAskedCount => 10;

  /// How many a 65/20 applicant must get right. Still 60%.
  int get seniorPassCount => 6;

  /// USCIS passes every version at 60% (6 of 10, 12 of 20).
  double get passRatio => 0.6;

  /// How many correct answers a practice test of [total] questions needs.
  ///
  /// Mock tests can be shortened, so the official [passCount] only applies at
  /// the full [askedCount]; shorter sessions are held to the same 60%.
  int passMarkFor(int total) {
    if (total <= 0) return 0;
    if (total == askedCount) return passCount;
    return (total * passRatio).ceil();
  }

  String get storageKey => switch (this) {
    TestVersion.v2008 => 'v2008',
    TestVersion.v2020 => 'v2020',
    TestVersion.v2025 => 'v2025',
  };
}

/// Top-level USCIS grouping for a question.
enum QuestionCategory { americanGovernment, americanHistory, integratedCivics }

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
    AnswerKind.stateRepresentative => true,
    _ => false,
  };

  bool get isTimeSensitive => switch (this) {
    AnswerKind.president ||
    AnswerKind.vicePresident ||
    AnswerKind.speaker ||
    AnswerKind.chiefJustice ||
    AnswerKind.presidentParty => true,
    _ => false,
  };

  bool get isDynamic => !isFixed;
}
