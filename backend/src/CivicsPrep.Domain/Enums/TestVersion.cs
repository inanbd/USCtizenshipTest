namespace CivicsPrep.Domain.Enums;

/// <summary>Which official USCIS civics test a question belongs to.</summary>
public enum TestVersion
{
    /// <summary>The 2008 test - 100 questions. Taken by most current applicants.</summary>
    V2008 = 1,

    /// <summary>
    /// The redesigned 2020 test - 128 questions. Adopted in December 2020 and
    /// rescinded in 2021, so nobody sits it today; kept for reference.
    /// </summary>
    V2020 = 2,

    /// <summary>
    /// The 2025 test - 128 questions, M-1778 (09/25). Taken by anyone who filed
    /// Form N-400 on or after 20 October 2025, so this is the current exam.
    /// </summary>
    V2025 = 3,
}

public static class TestVersionExtensions
{
    /// <summary>Number of questions asked in the real interview.</summary>
    public static int AskedCount(this TestVersion version) => version switch
    {
        TestVersion.V2008 => 10,
        TestVersion.V2020 => 20,
        TestVersion.V2025 => 20,
        _ => throw new ArgumentOutOfRangeException(nameof(version)),
    };

    /// <summary>Number of correct answers needed to pass the real interview.</summary>
    public static int PassCount(this TestVersion version) => version switch
    {
        TestVersion.V2008 => 6,
        TestVersion.V2020 => 12,
        TestVersion.V2025 => 12,
        _ => throw new ArgumentOutOfRangeException(nameof(version)),
    };

    /// <summary>USCIS passes both versions at 60% (6 of 10, 12 of 20).</summary>
    public const double PassRatio = 0.6;

    /// <summary>
    /// How many correct answers a practice test of <paramref name="total"/> questions needs.
    /// Mock tests can be shortened, so the official <see cref="PassCount"/> only applies at the
    /// full <see cref="AskedCount"/>; shorter sessions are held to the same 60%.
    /// </summary>
    public static int PassMarkFor(this TestVersion version, int total)
    {
        if (total <= 0) return 0;
        if (total == version.AskedCount()) return version.PassCount();
        return (int)Math.Ceiling(total * PassRatio);
    }

    public static string ShortLabel(this TestVersion version) => version switch
    {
        TestVersion.V2008 => "2008 · 100Q",
        TestVersion.V2020 => "2020 · 128Q",
        TestVersion.V2025 => "2025 · 128Q",
        _ => version.ToString(),
    };

    /// <summary>Which filers sit this test, so a client can explain the choice.</summary>
    public static string Applicability(this TestVersion version) => version switch
    {
        TestVersion.V2008 => "If you filed Form N-400 before 20 Oct 2025",
        TestVersion.V2020 => "Withdrawn in 2021 — nobody sits this today",
        TestVersion.V2025 => "If you filed Form N-400 on or after 20 Oct 2025",
        _ => string.Empty,
    };

    /// <summary>The test currently administered at interviews.</summary>
    public static TestVersion Current => TestVersion.V2025;

    public static bool IsCurrent(this TestVersion version) => version == Current;
}
