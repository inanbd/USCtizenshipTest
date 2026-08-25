using CivicsPrep.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Common.Interfaces;

/// <summary>
/// The persistence port the application layer depends on. Infrastructure supplies the EF Core
/// implementation, which keeps the handlers free of a hard dependency on the database.
/// </summary>
public interface IApplicationDbContext
{
    DbSet<Question> Questions { get; }
    DbSet<QuestionAnswer> QuestionAnswers { get; }
    DbSet<UsState> States { get; }
    DbSet<UserProfile> UserProfiles { get; }
    DbSet<UserQuestionProgress> UserQuestionProgress { get; }
    DbSet<TestSession> TestSessions { get; }
    DbSet<TestSessionQuestion> TestSessionQuestions { get; }
    DbSet<StudyPlan> StudyPlans { get; }
    DbSet<StudyPlanDay> StudyPlanDays { get; }
    DbSet<StudyPlanDayQuestion> StudyPlanDayQuestions { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
