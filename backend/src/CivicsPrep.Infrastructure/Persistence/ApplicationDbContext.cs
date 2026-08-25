using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Domain.Entities;
using CivicsPrep.Infrastructure.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;

namespace CivicsPrep.Infrastructure.Persistence;

/// <summary>
/// The EF Core context. It carries both Identity's tables and the app's own, so a user and their
/// progress live in one database and one transaction.
/// </summary>
public class ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
    : IdentityDbContext<ApplicationUser>(options), IApplicationDbContext
{
    public DbSet<Question> Questions => Set<Question>();
    public DbSet<QuestionAnswer> QuestionAnswers => Set<QuestionAnswer>();
    public DbSet<UsState> States => Set<UsState>();
    public DbSet<UserProfile> UserProfiles => Set<UserProfile>();
    public DbSet<UserQuestionProgress> UserQuestionProgress => Set<UserQuestionProgress>();
    public DbSet<TestSession> TestSessions => Set<TestSession>();
    public DbSet<TestSessionQuestion> TestSessionQuestions => Set<TestSessionQuestion>();
    public DbSet<StudyPlan> StudyPlans => Set<StudyPlan>();
    public DbSet<StudyPlanDay> StudyPlanDays => Set<StudyPlanDay>();
    public DbSet<StudyPlanDayQuestion> StudyPlanDayQuestions => Set<StudyPlanDayQuestion>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);
        builder.ApplyConfigurationsFromAssembly(typeof(ApplicationDbContext).Assembly);
    }

    protected override void ConfigureConventions(ModelConfigurationBuilder configurationBuilder)
    {
        base.ConfigureConventions(configurationBuilder);

        // SQL Server orders DateTimeOffset natively; SQLite (used by the integration tests)
        // cannot, so store those values in a sortable binary form there. Timestamps stay
        // DateTimeOffset everywhere in the model.
        if (Database.ProviderName?.Contains("Sqlite", StringComparison.OrdinalIgnoreCase) == true)
        {
            configurationBuilder.Properties<DateTimeOffset>()
                .HaveConversion<DateTimeOffsetToBinaryConverter>();
            configurationBuilder.Properties<DateTimeOffset?>()
                .HaveConversion<DateTimeOffsetToBinaryConverter>();
        }
    }
}
