using CivicsPrep.Domain.Enums;

namespace CivicsPrep.Domain.Entities;

/// <summary>
/// A dated plan that spreads all of a test's questions across the days until the exam, with
/// periodic review days.
/// </summary>
public class StudyPlan
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string UserId { get; set; } = string.Empty;

    public TestVersion Version { get; set; }

    public DateOnly TestDate { get; set; }
    public bool SeniorOnly { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    public List<StudyPlanDay> Days { get; set; } = [];

    public int TotalDays => Days.Count;
    public int CompletedCount => Days.Count(d => d.IsComplete);
    public double Progress => TotalDays == 0 ? 0 : (double)CompletedCount / TotalDays;
}

/// <summary>A single day's assignment in a <see cref="StudyPlan"/>.</summary>
public class StudyPlanDay
{
    public int Id { get; set; }

    public Guid StudyPlanId { get; set; }
    public StudyPlan? StudyPlan { get; set; }

    public int DayNumber { get; set; }
    public DateOnly Date { get; set; }

    /// <summary>Review days revisit previously assigned questions rather than new ones.</summary>
    public bool IsReviewDay { get; set; }

    public bool IsComplete { get; set; }

    public List<StudyPlanDayQuestion> Questions { get; set; } = [];
}

public class StudyPlanDayQuestion
{
    public int Id { get; set; }

    public int StudyPlanDayId { get; set; }
    public StudyPlanDay? StudyPlanDay { get; set; }

    public int QuestionNumber { get; set; }
    public int Ordinal { get; set; }
}
