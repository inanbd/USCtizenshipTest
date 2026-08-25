using CivicsPrep.Domain.Enums;

namespace CivicsPrep.Domain.Entities;

/// <summary>The source of questions a mock test was drawn from.</summary>
public enum TestSource
{
    All = 0,
    Senior = 1,
    Starred = 2,
}

/// <summary>
/// A mock test. The server owns grading, so the session records the questions asked, what the
/// user answered, and the outcome.
/// </summary>
public class TestSession
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string UserId { get; set; } = string.Empty;

    public TestVersion Version { get; set; }
    public TestSource Source { get; set; }

    public DateTimeOffset StartedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? CompletedAt { get; set; }

    public List<TestSessionQuestion> Questions { get; set; } = [];

    public bool IsComplete => CompletedAt is not null;

    public int Total => Questions.Count;

    public int AnsweredCount => Questions.Count(q => q.AnsweredAt is not null);

    public int CorrectCount => Questions.Count(q => q.IsCorrect);

    /// <summary>How many correct answers this session needs to pass (60%, scaled to length).</summary>
    public int PassMark => Version.PassMarkFor(Total);

    public bool Passed => Total > 0 && CorrectCount >= PassMark;

    public double Score => Total == 0 ? 0 : (double)CorrectCount / Total;
}

/// <summary>One question inside a <see cref="TestSession"/>, with the user's answer.</summary>
public class TestSessionQuestion
{
    public int Id { get; set; }

    public Guid TestSessionId { get; set; }
    public TestSession? TestSession { get; set; }

    /// <summary>Position in the test, 0-based.</summary>
    public int Ordinal { get; set; }

    public int QuestionNumber { get; set; }

    /// <summary>Snapshot of the prompt, so history survives question edits.</summary>
    public string Prompt { get; set; } = string.Empty;

    /// <summary>Snapshot of what counted as correct when the test was taken.</summary>
    public string AcceptedAnswers { get; set; } = string.Empty;

    public string? UserAnswer { get; set; }
    public bool IsCorrect { get; set; }

    /// <summary>True when the user overrode the automatic grade.</summary>
    public bool WasOverridden { get; set; }

    public DateTimeOffset? AnsweredAt { get; set; }
}
