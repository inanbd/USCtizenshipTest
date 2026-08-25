using CivicsPrep.Contracts.Common;

namespace CivicsPrep.Contracts.Questions;

/// <summary>
/// A civics question as served to clients, with dynamic answers already resolved for the
/// signed-in user where possible.
/// </summary>
public sealed record QuestionDto(
    int Number,
    TestVersionDto Version,
    QuestionCategoryDto Category,
    string CategoryLabel,
    string Section,
    string Prompt,
    IReadOnlyList<string> Answers,
    AnswerKindDto Kind,
    bool Senior,
    int RequiredCount,
    string? Note,
    bool IsStateDependent,
    bool IsTimeSensitive,
    // True when this needs state info the user has not supplied yet.
    bool NeedsUserData,
    bool IsLearned,
    bool IsFavorite);

public sealed record QuestionListDto(
    TestVersionDto Version,
    int Total,
    int AskedCount,
    int PassCount,
    IReadOnlyList<QuestionDto> Questions);

public sealed record SectionDto(string Name, QuestionCategoryDto Category, int QuestionCount);
