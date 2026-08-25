using CivicsPrep.Domain.Enums;

namespace CivicsPrep.Domain.Entities;

/// <summary>Tracks whether a user has marked a question known and/or starred it.</summary>
public class UserQuestionProgress
{
    public int Id { get; set; }

    public string UserId { get; set; } = string.Empty;

    public TestVersion Version { get; set; }

    /// <summary>Official question number within <see cref="Version"/>.</summary>
    public int QuestionNumber { get; set; }

    public bool IsLearned { get; set; }
    public bool IsFavorite { get; set; }

    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
}
