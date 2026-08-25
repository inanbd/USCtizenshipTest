using System.Text;

namespace CivicsPrep.Domain.Services;

/// <summary>Outcome of grading a free-text answer.</summary>
public sealed record MatchResult(bool Correct, IReadOnlyList<string> MatchedAnswers);

/// <summary>
/// Grades a free-text (typed or spoken) answer against the accepted answers.
/// <para>
/// USCIS answers are checked for meaning, not exact wording, so this matcher is deliberately
/// lenient: it ignores case, punctuation, leading articles and parenthetical hints, accepts a
/// longer phrase that contains the answer or a shorter phrase drawn from it, and tolerates typos
/// and speech-recognition slips via an edit-distance check.
/// </para>
/// <para>Two rules keep that leniency from becoming wrong:</para>
/// <list type="bullet">
/// <item><b>Modifiers must agree.</b> A word like "vice" or "not" has to be present on both sides
/// or neither, so "the Vice President" is never accepted for "the President" and "not the
/// Constitution" is never accepted for "the Constitution".</item>
/// <item><b>One phrase credits one answer.</b> For "name two/three" questions each accepted answer
/// can be credited once, and each thing the user said can credit only one answer - so the single
/// word "freedom" cannot stand in for five different First Amendment freedoms.</item>
/// </list>
/// <para>
/// This mirrors the Flutter client's matcher exactly so a given answer is graded the same whether
/// it is submitted from the app, the website, or the API.
/// </para>
/// </summary>
public static class AnswerMatcher
{
    /// <summary>Dropped from the front of a phrase so "the Constitution" == "Constitution".</summary>
    private static readonly HashSet<string> LeadingArticles = new(StringComparer.Ordinal)
    { "the", "a", "an" };

    /// <summary>
    /// Words that change or negate meaning. They must appear on both sides of a comparison,
    /// or on neither.
    /// </summary>
    private static readonly HashSet<string> Modifiers = new(StringComparer.Ordinal)
    { "vice", "not", "never", "no", "deputy", "acting", "former", "without" };

    /// <summary>A phrase made only of these carries no answer content on its own.</summary>
    private static readonly HashSet<string> Connectives = new(StringComparer.Ordinal)
    {
        "the", "a", "an", "of", "and", "or", "to", "in", "on", "at", "for",
        "is", "are", "was", "were", "be", "it", "its", "that", "this", "i",
        "we", "you", "they", "my", "our", "s", "t",
    };

    private static readonly char[] PartSeparators = [',', ';', '/', '\n', '&', '+'];

    /// <summary>Grades <paramref name="userInput"/>, reporting which accepted answers it covered.</summary>
    public static MatchResult Evaluate(
        string? userInput,
        IReadOnlyList<string> acceptedAnswers,
        int requiredCount = 1)
    {
        var candidates = Candidates(userInput);
        var claimed = new bool[candidates.Count];
        var matched = new List<string>();

        foreach (var accepted in acceptedAnswers)
        {
            var variants = Variants(accepted);
            for (var i = 0; i < candidates.Count; i++)
            {
                if (claimed[i]) continue;
                if (variants.Any(v => Matches(candidates[i], v)))
                {
                    claimed[i] = true;
                    matched.Add(accepted);
                    break;
                }
            }
        }

        return new MatchResult(matched.Count >= requiredCount, matched);
    }

    public static bool IsCorrect(
        string? userInput,
        IReadOnlyList<string> acceptedAnswers,
        int requiredCount = 1) =>
        Evaluate(userInput, acceptedAnswers, requiredCount).Correct;

    // --- matching strategies ---

    /// <summary>True if the user phrase <paramref name="u"/> conveys the accepted answer.</summary>
    private static bool Matches(IReadOnlyList<string> u, IReadOnlyList<string> a)
    {
        if (u.Count == 0 || a.Count == 0) return false;
        if (!ModifiersAgree(u, a)) return false;
        if (SameWords(u, a)) return true;
        // The user said at least the whole accepted answer, plus extra words.
        if (ContainsRun(u, a)) return true;
        // The user said a shorter phrase drawn entirely from the accepted answer.
        if (u.All(a.Contains)) return true;
        // Typo / speech-recognition slip.
        return Similar(string.Join(' ', u), string.Join(' ', a));
    }

    /// <summary>Meaning-changing words must be present on both sides or on neither.</summary>
    private static bool ModifiersAgree(IReadOnlyList<string> u, IReadOnlyList<string> a)
        => Modifiers.All(m => u.Contains(m) == a.Contains(m));

    private static bool SameWords(IReadOnlyList<string> u, IReadOnlyList<string> a)
        => u.Count == a.Count && !u.Where((t, i) => t != a[i]).Any();

    /// <summary>True if <paramref name="a"/> appears inside <paramref name="u"/> as whole words.</summary>
    private static bool ContainsRun(IReadOnlyList<string> u, IReadOnlyList<string> a)
        => $" {string.Join(' ', u)} ".Contains($" {string.Join(' ', a)} ", StringComparison.Ordinal);

    private static bool Similar(string a, string b)
    {
        if (a.Length == 0 || b.Length == 0) return false;
        var maxLen = Math.Max(a.Length, b.Length);
        if (maxLen < 4) return a == b; // too short to fuzz safely
        return 1 - (double)Levenshtein(a, b) / maxLen >= 0.84;
    }

    // --- text preparation ---

    /// <summary>
    /// The whole input plus each comma/"and"-separated piece, as word lists. Duplicates and
    /// content-free fragments are dropped.
    /// </summary>
    private static List<List<string>> Candidates(string? input)
    {
        if (string.IsNullOrWhiteSpace(input)) return [];

        var pieces = new List<string> { input };
        foreach (var chunk in SplitOnAnd(input))
        {
            pieces.AddRange(chunk.Split(PartSeparators, StringSplitOptions.RemoveEmptyEntries));
        }

        var seen = new HashSet<string>(StringComparer.Ordinal);
        var result = new List<List<string>>();
        foreach (var piece in pieces)
        {
            var words = Normalize(piece);
            if (words.Count == 0 || !HasContent(words)) continue;
            if (seen.Add(string.Join(' ', words))) result.Add(words);
        }
        return result;
    }

    /// <summary>Splits on the word "and" only, leaving other separators to the caller.</summary>
    private static IEnumerable<string> SplitOnAnd(string input) =>
        System.Text.RegularExpressions.Regex.Split(
            input, @"\band\b", System.Text.RegularExpressions.RegexOptions.IgnoreCase);

    private static bool HasContent(List<string> words) => words.Any(w => !Connectives.Contains(w));

    /// <summary>Lowercases, strips punctuation, and drops leading articles.</summary>
    private static List<string> Normalize(string s)
    {
        var sb = new StringBuilder(s.Length);
        foreach (var ch in s.ToLowerInvariant())
        {
            sb.Append(char.IsAsciiLetterOrDigit(ch) ? ch : ' ');
        }

        var words = sb.ToString()
            .Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .ToList();

        var start = 0;
        while (start < words.Count && LeadingArticles.Contains(words[start])) start++;
        return words.GetRange(start, words.Count - start);
    }

    /// <summary>
    /// Word-list forms of an accepted answer: one keeping parenthetical content and one dropping
    /// it, so "(James) Madison" matches both "James Madison" and "Madison".
    /// </summary>
    private static List<List<string>> Variants(string answer)
    {
        var keepParens = answer.Replace("(", " ").Replace(")", " ");
        var dropParens = System.Text.RegularExpressions.Regex.Replace(answer, @"\([^)]*\)", " ");

        var seen = new HashSet<string>(StringComparer.Ordinal);
        var result = new List<List<string>>();
        foreach (var form in new[] { keepParens, dropParens })
        {
            var words = Normalize(form);
            if (words.Count == 0) continue;
            if (seen.Add(string.Join(' ', words))) result.Add(words);
        }
        return result;
    }

    private static int Levenshtein(string a, string b)
    {
        int m = a.Length, n = b.Length;
        if (m == 0) return n;
        if (n == 0) return m;

        var prev = new int[n + 1];
        var curr = new int[n + 1];
        for (var j = 0; j <= n; j++) prev[j] = j;

        for (var i = 1; i <= m; i++)
        {
            curr[0] = i;
            for (var j = 1; j <= n; j++)
            {
                var cost = a[i - 1] == b[j - 1] ? 0 : 1;
                curr[j] = Math.Min(Math.Min(prev[j] + 1, curr[j - 1] + 1), prev[j - 1] + cost);
            }
            (prev, curr) = (curr, prev);
        }
        return prev[n];
    }
}
