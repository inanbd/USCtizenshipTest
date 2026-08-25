using CivicsPrep.Contracts.Common;

namespace CivicsPrep.Contracts.Tests;

public sealed record StartTestRequest(
    TestVersionDto? Version,
    TestSourceDto Source = TestSourceDto.All,
    int? QuestionCount = null);

/// <summary>A question as presented during a mock test - deliberately without the answers.</summary>
public sealed record TestQuestionDto(
    int Ordinal,
    int Number,
    string Prompt,
    int RequiredCount,
    string? Note,
    // True when the server cannot auto-grade this, so the user self-grades.
    bool SelfGraded);

public sealed record TestSessionDto(
    Guid Id,
    TestVersionDto Version,
    TestSourceDto Source,
    DateTimeOffset StartedAt,
    DateTimeOffset? CompletedAt,
    int Total,
    int AnsweredCount,
    int CorrectCount,
    int PassMark,
    bool Passed,
    double Score,
    IReadOnlyList<TestQuestionDto> Questions);

public sealed record SubmitAnswerRequest(int Ordinal, string? Answer);

/// <summary>Feedback for one submitted answer, including what would have been accepted.</summary>
public sealed record AnswerFeedbackDto(
    int Ordinal,
    bool Correct,
    bool SelfGraded,
    IReadOnlyList<string> AcceptedAnswers,
    IReadOnlyList<string> MatchedAnswers,
    string? Note,
    int CorrectSoFar,
    int PassMark,
    bool IsFinalQuestion);

public sealed record OverrideAnswerRequest(int Ordinal, bool Correct);

public sealed record TestResultAnswerDto(
    int Ordinal,
    int Number,
    string Prompt,
    string? UserAnswer,
    IReadOnlyList<string> AcceptedAnswers,
    bool Correct,
    bool WasOverridden);

public sealed record TestResultDto(
    Guid SessionId,
    TestVersionDto Version,
    DateTimeOffset TakenAt,
    int Total,
    int CorrectCount,
    int PassMark,
    bool Passed,
    double Score,
    IReadOnlyList<TestResultAnswerDto> Answers);
