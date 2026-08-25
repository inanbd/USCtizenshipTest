using CivicsPrep.Domain.Enums;

namespace CivicsPrep.Domain.Entities;

/// <summary>
/// Per-user settings: which test they are studying, where they live, and their answers to the
/// time-sensitive federal questions.
/// </summary>
public class UserProfile
{
    public int Id { get; set; }

    public string UserId { get; set; } = string.Empty;

    public TestVersion TestVersion { get; set; } = TestVersion.V2008;

    /// <summary>Two-letter state code, or null when the user has not set it yet.</summary>
    public string? StateCode { get; set; }

    public string? Governor { get; set; }
    public string? SenatorOne { get; set; }
    public string? SenatorTwo { get; set; }
    public string? Representative { get; set; }

    // Current officeholders. Null falls back to the server defaults.
    public string? President { get; set; }
    public string? VicePresident { get; set; }
    public string? Speaker { get; set; }
    public string? ChiefJustice { get; set; }
    public string? PresidentParty { get; set; }

    public DateTimeOffset? StateInfoUpdatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;

    public IEnumerable<string> Senators
    {
        get
        {
            if (!string.IsNullOrWhiteSpace(SenatorOne)) yield return SenatorOne.Trim();
            if (!string.IsNullOrWhiteSpace(SenatorTwo)) yield return SenatorTwo.Trim();
        }
    }
}
