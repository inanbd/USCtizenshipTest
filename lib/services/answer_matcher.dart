/// Grades a free-text (typed or spoken) answer against the accepted answers.
///
/// USCIS answers are checked for meaning, not exact wording, so this matcher is
/// deliberately lenient: it ignores case, punctuation, parenthetical hints and
/// leading filler words, and tolerates small typos / speech-recognition slips
/// via an edit-distance similarity check. For "name two/three" questions it
/// requires that many distinct accepted answers to be present.
class AnswerMatcher {
  const AnswerMatcher._();

  static const Set<String> _fillers = {
    'the', 'a', 'an', 'of', 'to', 'because', 'and',
  };

  /// Result of grading, including which accepted answers were matched.
  static MatchResult evaluate(
    String userInput,
    List<String> acceptedAnswers, {
    int requiredCount = 1,
  }) {
    final parts = _splitParts(userInput);
    final matched = <String>{};

    for (final accepted in acceptedAnswers) {
      final variants = _variants(accepted);
      final hit = _matchesWhole(userInput, variants) ||
          parts.any((p) => _matchesPart(p, variants));
      if (hit) matched.add(accepted);
    }

    final correct = matched.length >= requiredCount;
    return MatchResult(correct: correct, matchedAnswers: matched.toList());
  }

  static bool isCorrect(
    String userInput,
    List<String> acceptedAnswers, {
    int requiredCount = 1,
  }) =>
      evaluate(userInput, acceptedAnswers, requiredCount: requiredCount)
          .correct;

  // --- internals ---

  static List<String> _splitParts(String input) => input
      .split(RegExp(r'[,;/\n]|\band\b|&|\+', caseSensitive: false))
      .map(_normalize)
      .where((s) => s.isNotEmpty)
      .toList();

  static bool _matchesWhole(String userInput, List<String> variants) {
    final u = _normalize(userInput);
    if (u.isEmpty) return false;
    for (final v in variants) {
      if (v.isEmpty) continue;
      if (u == v) return true;
      // The user gave a longer phrase that contains the accepted answer.
      if (_containsWords(u, v)) return true;
    }
    return false;
  }

  static bool _matchesPart(String part, List<String> variants) {
    if (part.isEmpty) return false;
    for (final v in variants) {
      if (v.isEmpty) continue;
      if (part == v) return true;
      if (_containsWords(part, v)) return true;
      if (_containsWords(v, part) && part.length >= 3) return true;
      if (_similar(part, v)) return true;
    }
    return false;
  }

  /// True if [haystack] contains [needle] as a run of whole words.
  static bool _containsWords(String haystack, String needle) {
    if (needle.isEmpty) return false;
    return (' $haystack ').contains(' $needle ');
  }

  /// Edit-distance similarity for typo / speech tolerance.
  static bool _similar(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen < 4) return a == b; // too short to fuzz safely
    final distance = _levenshtein(a, b);
    final ratio = 1 - distance / maxLen;
    return ratio >= 0.84;
  }

  static String _normalize(String s) {
    var t = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    final words = t
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    // Drop leading filler words only (keep internal ones for word matching).
    var start = 0;
    while (start < words.length && _fillers.contains(words[start])) {
      start++;
    }
    return words.sublist(start).join(' ');
  }

  /// Variants of an accepted answer: one keeping parenthetical content, one
  /// dropping it entirely (both normalized). e.g. "(James) Madison" ->
  /// {"james madison", "madison"}.
  static List<String> _variants(String answer) {
    final keepParens = answer.replaceAll(RegExp(r'[()]'), ' ');
    final dropParens = answer.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    final set = <String>{};
    for (final candidate in [answer, keepParens, dropParens]) {
      final n = _normalize(candidate);
      if (n.isNotEmpty) set.add(n);
    }
    return set.toList();
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
