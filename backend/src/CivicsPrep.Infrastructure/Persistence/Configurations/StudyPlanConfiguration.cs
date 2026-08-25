using CivicsPrep.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CivicsPrep.Infrastructure.Persistence.Configurations;

public class StudyPlanConfiguration : IEntityTypeConfiguration<StudyPlan>
{
    public void Configure(EntityTypeBuilder<StudyPlan> builder)
    {
        builder.ToTable("StudyPlans");
        builder.HasKey(p => p.Id);
        builder.HasIndex(p => p.UserId);

        builder.Property(p => p.UserId).HasMaxLength(450).IsRequired();
        builder.Property(p => p.Version).HasConversion<int>().IsRequired();

        builder.HasMany(p => p.Days)
            .WithOne(d => d.StudyPlan!)
            .HasForeignKey(d => d.StudyPlanId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Ignore(p => p.TotalDays);
        builder.Ignore(p => p.CompletedCount);
        builder.Ignore(p => p.Progress);
    }
}

public class StudyPlanDayConfiguration : IEntityTypeConfiguration<StudyPlanDay>
{
    public void Configure(EntityTypeBuilder<StudyPlanDay> builder)
    {
        builder.ToTable("StudyPlanDays");
        builder.HasKey(d => d.Id);
        builder.HasIndex(d => new { d.StudyPlanId, d.DayNumber }).IsUnique();

        builder.HasMany(d => d.Questions)
            .WithOne(q => q.StudyPlanDay!)
            .HasForeignKey(q => q.StudyPlanDayId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public class StudyPlanDayQuestionConfiguration : IEntityTypeConfiguration<StudyPlanDayQuestion>
{
    public void Configure(EntityTypeBuilder<StudyPlanDayQuestion> builder)
    {
        builder.ToTable("StudyPlanDayQuestions");
        builder.HasKey(q => q.Id);
        builder.HasIndex(q => new { q.StudyPlanDayId, q.Ordinal });
    }
}
