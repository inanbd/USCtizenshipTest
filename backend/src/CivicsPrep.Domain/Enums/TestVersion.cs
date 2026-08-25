namespace CivicsPrep.Domain.Enums;

/// <summary>Which official USCIS civics test a question belongs to.</summary>
public enum TestVersion
{
    /// <summary>The 2008 test - 100 questions. Taken by most current applicants.</summary>
    V2008 = 1,

    /// <summary>The redesigned 2020 test - 128 questions.</summary>
    V2020 = 2,
}

public static class TestVersionExtensions
{
    /// <summary>Number of questions asked in the real interview.</summary>
    public static int AskedCount(this TestVersion version) => version switch
    {
        TestVersion.V2008 => 10,
        TestVersion.V2020 => 20,
        _ => throw new ArgumentOutOfRangeException(nameof(version)),
    };

    /// <summary>Number of correct answers needed to pass the real interview.</summary>
    public static int PassCount(this TestVersion version) => version switch
    {
        TestVersion.V2008 => 6,
        TestVersion.V2020 => 12,
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
        _ => version.ToString(),
    };
}
