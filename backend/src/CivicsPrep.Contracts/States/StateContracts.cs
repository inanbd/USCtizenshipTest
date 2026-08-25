namespace CivicsPrep.Contracts.States;

public sealed record StateDto(string Code, string Name, string Capital, bool IsDistrictOfColumbia);

/// <summary>The user's saved state-specific answers.</summary>
public sealed record StateInfoDto(
    string? StateCode,
    string? StateName,
    string? Capital,
    string? Governor,
    IReadOnlyList<string> Senators,
    string? Representative,
    DateTimeOffset? UpdatedAt);

public sealed record UpdateStateInfoRequest(
    string StateCode,
    string? Governor,
    string? SenatorOne,
    string? SenatorTwo,
    string? Representative);

public sealed record OfficialsDto(
    string President,
    string VicePresident,
    string Speaker,
    string ChiefJustice,
    string PresidentParty);

public sealed record UpdateOfficialsRequest(
    string? President,
    string? VicePresident,
    string? Speaker,
    string? ChiefJustice,
    string? PresidentParty);

/// <summary>A member of Congress returned by the live Congress.gov lookup.</summary>
public sealed record CongressMemberDto(string Name, string Chamber, string? District, string? Party);
