namespace CivicsPrep.Contracts.Common;

/// <summary>Shape of the error body the API returns (RFC 7807 style).</summary>
public sealed record ApiProblemDto(
    string Title,
    int Status,
    string? Detail,
    IReadOnlyDictionary<string, string[]>? Errors);
