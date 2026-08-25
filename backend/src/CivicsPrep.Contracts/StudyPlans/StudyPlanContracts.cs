using CivicsPrep.Contracts.Common;

namespace CivicsPrep.Contracts.StudyPlans;

public sealed record CreateStudyPlanRequest(
    DateOnly TestDate,
    TestVersionDto? Version,
    bool SeniorOnly = false);

public sealed record StudyPlanDayDto(
    int DayNumber,
    DateOnly Date,
    bool IsReviewDay,
    bool IsComplete,
    IReadOnlyList<int> QuestionNumbers);

public sealed record StudyPlanDto(
    Guid Id,
    TestVersionDto Version,
    DateOnly TestDate,
    bool SeniorOnly,
    DateTimeOffset CreatedAt,
    int TotalDays,
    int CompletedCount,
    double Progress,
    IReadOnlyList<StudyPlanDayDto> Days);

public sealed record SetDayCompleteRequest(bool IsComplete);
