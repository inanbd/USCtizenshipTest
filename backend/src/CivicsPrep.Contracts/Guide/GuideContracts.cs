namespace CivicsPrep.Contracts.Guide;

/// <summary>
/// The naturalization process guide: what the steps are, how long each one usually takes, how to
/// apply and what it costs. Static reference content shipped with the server, so the app and the
/// website say the same thing.
/// </summary>
public sealed record NaturalizationGuideDto(
    string ReviewedOn,
    string Disclaimer,
    GuideTimelineDto Timeline,
    IReadOnlyList<GuideStepDto> Steps,
    IReadOnlyList<string> AfterOath,
    GuideApplyingDto Applying,
    GuideCostsDto Costs,
    GuideTestsDto Tests,
    IReadOnlyList<GuideLinkDto> Sources);

/// <summary>How long the whole thing takes, end to end.</summary>
public sealed record GuideTimelineDto(
    int MedianMonths,
    int TypicalLowMonths,
    int TypicalHighMonths,
    string Summary,
    string Note);

public sealed record GuideStepDto(
    string Key,
    string Title,
    string Timing,
    string TimingDetail,
    string Summary,
    IReadOnlyList<string> Details);

public sealed record GuideApplyingDto(
    IReadOnlyList<GuideApplyMethodDto> Methods,
    IReadOnlyList<string> Checklist);

public sealed record GuideApplyMethodDto(
    string Name,
    string Fee,
    string Summary,
    IReadOnlyList<string> Points);

public sealed record GuideCostsDto(
    IReadOnlyList<GuideCostItemDto> Items,
    IReadOnlyList<string> Notes,
    GuideProposedChangeDto? ProposedChange);

public sealed record GuideCostItemDto(string Label, string Amount, string When, string? Note);

/// <summary>A fee change that has been proposed but is not in effect. Flagged, never presented as current.</summary>
public sealed record GuideProposedChangeDto(
    string Status,
    string Summary,
    string Impact,
    string? Url);

public sealed record GuideTestsDto(
    GuideEnglishTestDto English,
    GuideCivicsTestDto Civics,
    IReadOnlyList<GuideExemptionDto> Exemptions,
    string Retake);

public sealed record GuideEnglishTestDto(string Summary, IReadOnlyList<string> Parts);

public sealed record GuideCivicsTestDto(
    string Summary,
    IReadOnlyList<GuideCivicsVariantDto> Variants,
    string Note);

/// <summary>Which civics set an applicant gets, keyed to the filing date.</summary>
public sealed record GuideCivicsVariantDto(string Label, string Detail, string Version);

public sealed record GuideExemptionDto(string Label, string Detail);

public sealed record GuideLinkDto(string Label, string Url);
