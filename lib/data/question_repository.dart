import '../models/enums.dart';
import '../models/officials.dart';
import '../models/question.dart';
import '../models/state_info.dart';
import 'questions_2008.dart';
import 'questions_2020.dart';

/// Central access point for the question sets and for resolving the answers
/// that depend on the user's state or on current officeholders.
class QuestionRepository {
  const QuestionRepository._();

  static List<Question> forVersion(TestVersion version) => switch (version) {
        TestVersion.v2008 => kQuestions2008,
        TestVersion.v2020 => kQuestions2020,
      };

  static Question? byId(TestVersion version, int id) {
    for (final q in forVersion(version)) {
      if (q.id == id) return q;
    }
    return null;
  }

  static List<Question> senior(TestVersion version) =>
      forVersion(version).where((q) => q.senior).toList();

  static List<String> sections(TestVersion version) {
    final seen = <String>[];
    for (final q in forVersion(version)) {
      if (!seen.contains(q.section)) seen.add(q.section);
    }
    return seen;
  }

  /// The accepted answers for grading, with dynamic (state/official) answers
  /// resolved. Returns an empty list when a state-dependent answer has not
  /// been provided yet.
  static List<String> effectiveAnswers(
    Question q, {
    StateInfo? state,
    required Officials officials,
  }) {
    switch (q.kind) {
      case AnswerKind.fixed:
        return q.answers;
      case AnswerKind.president:
      case AnswerKind.vicePresident:
      case AnswerKind.speaker:
      case AnswerKind.chiefJustice:
      case AnswerKind.presidentParty:
        final v = officials.forKind(q.kind).trim();
        return v.isEmpty ? const [] : [v];
      case AnswerKind.stateCapital:
        if (state == null) return const [];
        if (state.isDistrictOfColumbia) {
          return ['D.C. is not a state and has no capital.'];
        }
        return [state.capital];
      case AnswerKind.governor:
        if (state == null) return const [];
        if (state.isDistrictOfColumbia) {
          return ['D.C. does not have a Governor.'];
        }
        return state.hasGovernor ? [state.governor!.trim()] : const [];
      case AnswerKind.stateSenator:
        if (state == null) return const [];
        if (state.isDistrictOfColumbia) {
          return ['D.C. has no U.S. Senators.'];
        }
        return state.senators
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      case AnswerKind.stateRepresentative:
        if (state == null) return const [];
        return state.hasRepresentative
            ? [state.representative!.trim()]
            : const [];
    }
  }

  /// How many distinct answers are required to be considered correct, adjusted
  /// for how many are actually available (e.g. a state has 2 senators, but the
  /// question only needs 1).
  static int requiredCountFor(Question q, List<String> effective) {
    if (q.kind == AnswerKind.stateSenator) return 1;
    return q.requiredCount;
  }

  /// A human-readable version of the correct answer(s) for flashcards/reveal.
  static String displayAnswer(
    Question q, {
    StateInfo? state,
    required Officials officials,
  }) {
    final resolved = effectiveAnswers(q, state: state, officials: officials);
    if (resolved.isEmpty) {
      if (q.isStateDependent) {
        return 'Set your state info to see this answer.';
      }
      return q.answers.join(' • ');
    }
    if (q.requiredCount > 1) {
      return 'Give ${q.requiredCount}: ${resolved.join(', ')}';
    }
    return resolved.join('  •  ');
  }

  /// Whether this question still needs the user to provide data before it can
  /// be answered/graded.
  static bool needsUserData(
    Question q, {
    StateInfo? state,
    required Officials officials,
  }) {
    if (!q.isStateDependent) return false;
    return effectiveAnswers(q, state: state, officials: officials).isEmpty;
  }
}
