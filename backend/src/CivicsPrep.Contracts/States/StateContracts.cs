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

/// <summary>Who holds a state's governorship, from the maintained table on the server.</summary>
public sealed record GovernorDto(string Name, DateOnly? Since, DateOnly AsOf, string? Source);

/// <summary>
/// Everything needed to answer the state-specific civics questions for one state: the bundled
/// capital, the governor from the server's maintained table, and - when a Congress.gov key is
/// configured - the state's current senators and House members. The House list is deliberately
/// complete: only the applicant knows their congressional district, so they pick from it.
/// </summary>
public sealed record StateAnswersDto(
    string StateCode,
    string StateName,
    string Capital,
    bool IsDistrictOfColumbia,
    GovernorDto? Governor,
    IReadOnlyList<CongressMemberDto> Senators,
    IReadOnlyList<CongressMemberDto> Representatives,
    bool CongressAvailable,
    string? CongressNotice,
    DateTimeOffset RetrievedAt);
