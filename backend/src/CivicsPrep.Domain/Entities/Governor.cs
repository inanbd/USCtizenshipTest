namespace CivicsPrep.Domain.Entities;

/// <summary>
/// The sitting governor of a state, as served to clients for the "Who is the
/// governor of your state now?" question.
/// <para>
/// This is deliberately a table rather than bundled client data: governors
/// change with elections, and serving them from the API means a correction
/// ships without an app release. <see cref="AsOf"/> travels with the answer so
/// a client can tell the user how fresh it is.
/// </para>
/// </summary>
public class Governor
{
    public int Id { get; set; }

    /// <summary>Two-letter USPS code. D.C. has no governor and no row here.</summary>
    public string StateCode { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    /// <summary>When this person took office, where known.</summary>
    public DateOnly? Since { get; set; }

    /// <summary>When this record was last confirmed.</summary>
    public DateOnly AsOf { get; set; }

    /// <summary>Where the value came from, for auditing a wrong answer.</summary>
    public string? Source { get; set; }
}
