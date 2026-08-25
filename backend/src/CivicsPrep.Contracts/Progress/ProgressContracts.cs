using CivicsPrep.Contracts.Common;

namespace CivicsPrep.Contracts.Progress;

public sealed record ProgressSummaryDto(
    TestVersionDto Version,
    int Total,
    int LearnedCount,
    int FavoriteCount,
    double LearnedRatio,
    IReadOnlyList<int> LearnedNumbers,
    IReadOnlyList<int> FavoriteNumbers,
    TestHistoryEntryDto? LastResult);

public sealed record SetQuestionProgressRequest(bool? IsLearned, bool? IsFavorite);

public sealed record TestHistoryEntryDto(
    Guid SessionId,
    TestVersionDto Version,
    DateTimeOffset TakenAt,
    int Total,
    int CorrectCount,
    int PassMark,
    bool Passed,
    double Score);
