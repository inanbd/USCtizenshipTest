using CivicsPrep.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CivicsPrep.Infrastructure.Persistence.Configurations;

public class TestSessionConfiguration : IEntityTypeConfiguration<TestSession>
{
    public void Configure(EntityTypeBuilder<TestSession> builder)
    {
        builder.ToTable("TestSessions");
        builder.HasKey(s => s.Id);
        builder.HasIndex(s => new { s.UserId, s.CompletedAt });

        builder.Property(s => s.UserId).HasMaxLength(450).IsRequired();
        builder.Property(s => s.Version).HasConversion<int>().IsRequired();
        builder.Property(s => s.Source).HasConversion<int>().IsRequired();

        builder.HasMany(s => s.Questions)
            .WithOne(q => q.TestSession!)
            .HasForeignKey(q => q.TestSessionId)
            .OnDelete(DeleteBehavior.Cascade);

        // Computed from the loaded questions, never stored.
        builder.Ignore(s => s.IsComplete);
        builder.Ignore(s => s.Total);
        builder.Ignore(s => s.AnsweredCount);
        builder.Ignore(s => s.CorrectCount);
        builder.Ignore(s => s.PassMark);
        builder.Ignore(s => s.Passed);
        builder.Ignore(s => s.Score);
    }
}

public class TestSessionQuestionConfiguration : IEntityTypeConfiguration<TestSessionQuestion>
{
    public void Configure(EntityTypeBuilder<TestSessionQuestion> builder)
    {
        builder.ToTable("TestSessionQuestions");
        builder.HasKey(q => q.Id);
        builder.HasIndex(q => new { q.TestSessionId, q.Ordinal }).IsUnique();

        builder.Property(q => q.Prompt).HasMaxLength(500).IsRequired();
        builder.Property(q => q.AcceptedAnswers).HasMaxLength(4000);
        builder.Property(q => q.UserAnswer).HasMaxLength(500);
    }
}
