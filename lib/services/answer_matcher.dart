/// Grades a free-text (typed or spoken) answer against the accepted answers.
///
/// USCIS answers are checked for meaning, not exact wording, so this matcher is
/// deliberately lenient: it ignores case, punctuation, leading articles and
/// parenthetical hints, accepts a longer phrase that contains the answer or a
/// shorter phrase drawn from it, and tolerates typos / speech-recognition slips
/// via an edit-distance check.
///
/// Two rules keep that leniency from becoming wrong:
///
///  * **Modifiers must agree.** A word like "vice" or "not" has to be present
///    on both sides or neither, so "the Vice President" is never accepted for
///    "the President" and "not the Constitution" is never accepted for "the
///    Constitution".
///  * **One phrase credits one answer.** For "name two/three" questions each
///    accepted answer can be credited once, and each thing the user said can
///    credit only one answer — so the single word "freedom" cannot stand in
///    for five different First Amendment freedoms.
class AnswerMatcher {
  const AnswerMatcher._();

  /// Dropped from the front of a phrase so "the Constitution" == "Constitution".
  static const Set<String> _leadingArticles = {'the', 'a', 'an'};

  /// Words that change or negate meaning. They must appear on both sides of a
  /// comparison or on neither.
  static const Set<String> _modifiers = {
    'vice',
    'not',
    'never',
    'no',
    'deputy',
    'acting',
    'former',
    'without',
  };

  /// A phrase made only of these carries no answer content on its own.
  static const Set<String> _connectives = {
    'the',
    'a',
    'an',
    'of',
    'and',
    'or',
    'to',
    'in',
    'on',
    'at',
    'for',
    'is',
    'are',
    'was',
    'were',
    'be',
    'it',
    'its',
    'that',
    'this',
    'i',
    'we',
    'you',
    'they',
    'my',
    'our',
    's',
    't',
  };

  /// Grades [userInput], reporting which accepted answers it covered.
  static MatchResult evaluate(
    String userInput,
    List<String> acceptedAnswers, {
    int requiredCount = 1,
  }) {
    final candidates = _candidates(userInput);
    final claimed = List<bool>.filled(candidates.length, false);
    final matched = <String>[];

    for (final accepted in acceptedAnswers) {
      final variants = _variants(accepted);
      for (var i = 0; i < candidates.length; i++) {
        if (claimed[i]) continue;
        if (variants.any((v) => _matches(candidates[i], v))) {
          claimed[i] = true;
          matched.add(accepted);
          break;
        }
      }
    }

    return MatchResult(
      correct: matched.length >= requiredCount,
      matchedAnswers: matched,
    );
  }

  static bool isCorrect(
    String userInput,
    List<String> acceptedAnswers, {
    int requiredCount = 1,
  }) => evaluate(
    userInput,
    acceptedAnswers,
    requiredCount: requiredCount,
  ).correct;

  // --- matching strategies ---

  /// True if the user phrase [u] conveys the accepted answer [a].
  static bool _matches(List<String> u, List<String> a) {
    if (u.isEmpty || a.isEmpty) return false;
    if (!_modifiersAgree(u, a)) return false;
    if (_sameWords(u, a)) return true;
    // The user said at least the whole accepted answer, plus extra words.
    if (_containsRun(u, a)) return true;
    // The user said a shorter phrase drawn entirely from the accepted answer.
    if (a.toSet().containsAll(u)) return true;
    // Typo / speech-recognition slip.
    return _similar(u.join(' '), a.join(' '));
  }

  /// Meaning-changing words must be present on both sides or on neither.
  static bool _modifiersAgree(List<String> u, List<String> a) {
    for (final m in _modifiers) {
      if (u.contains(m) != a.contains(m)) return false;
    }
    return true;
  }

  static bool _sameWords(List<String> u, List<String> a) {
    if (u.length != a.length) return false;
    for (var i = 0; i < u.length; i++) {
      if (u[i] != a[i]) return false;
    }
    return true;
  }

  /// True if [a] appears inside [u] as a run of whole words.
  static bool _containsRun(List<String> u, List<String> a) =>
      ' ${u.join(' ')} '.contains(' ${a.join(' ')} ');

  static bool _similar(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen < 4) return a == b; // too short to fuzz safely
    return 1 - _levenshtein(a, b) / maxLen >= 0.84;
  }

  // --- text preparation ---

  /// The whole input plus each comma/"and"-separated piece, as word lists.
  /// Duplicates and content-free fragments are dropped.
  static List<List<String>> _candidates(String input) {
    final pieces = <String>[
      input,
      ...input.split(RegExp(r'[,;/\n]|\band\b|&|\+', caseSensitive: false)),
    ];
    final seen = <String>{};
    final result = <List<String>>[];
    for (final piece in pieces) {
      final words = _normalize(piece);
      if (words.isEmpty || !_hasContent(words)) continue;
      final key = words.join(' ');
      if (seen.add(key)) result.add(words);
    }
    return result;
  }

  static bool _hasContent(List<String> words) =>
      words.any((w) => !_connectives.contains(w));

  /// Lowercases, strips punctuation, and drops leading articles.
  static List<String> _normalize(String s) {
    final words = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    var start = 0;
    while (start < words.length && _leadingArticles.contains(words[start])) {
      start++;
    }
    return words.sublist(start);
  }

  /// Word-list forms of an accepted answer: one keeping parenthetical content
  /// and one dropping it, so "(James) Madison" matches both "James Madison"
  /// and "Madison".
  static List<List<String>> _variants(String answer) {
    final forms = [
      answer.replaceAll(RegExp(r'[()]'), ' '),
      answer.replaceAll(RegExp(r'\([^)]*\)'), ' '),
    ];
    final seen = <String>{};
    final result = <List<String>>[];
    for (final form in forms) {
      final words = _normalize(form);
      if (words.isEmpty) continue;
      if (seen.add(words.join(' '))) result.add(words);
    }
    return result;
  }

  static int _levenshtein(String a, String b) {
    final m = a.length, n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;
    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);
    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        curr[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }
}

class MatchResult {
  const MatchResult({required this.correct, required this.matchedAnswers});

  final bool correct;
  final List<String> matchedAnswers;
}
