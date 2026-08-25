namespace CivicsPrep.Domain.Entities;

/// <summary>
/// A U.S. state (or the District of Columbia) with its capital. Capitals are stable facts and
/// answer the "capital of your state" question offline; the officeholder names live on
/// <see cref="UserProfile"/> because they change and are per-applicant.
/// </summary>
public class UsState
{
    public int Id { get; set; }

    /// <summary>Two-letter USPS code, e.g. "CA". "DC" for the District of Columbia.</summary>
    public string Code { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;
    public string Capital { get; set; } = string.Empty;

    public bool IsDistrictOfColumbia => Code == "DC";
}
