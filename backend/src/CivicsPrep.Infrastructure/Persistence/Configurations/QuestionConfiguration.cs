using CivicsPrep.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CivicsPrep.Infrastructure.Persistence.Configurations;

public class QuestionConfiguration : IEntityTypeConfiguration<Question>
{
    public void Configure(EntityTypeBuilder<Question> builder)
    {
        builder.ToTable("Questions");
        builder.HasKey(q => q.Id);

        // A question is identified by its official number within a version.
        builder.HasIndex(q => new { q.Version, q.Number }).IsUnique();

        builder.Property(q => q.Version).HasConversion<int>().IsRequired();
        builder.Property(q => q.Category).HasConversion<int>().IsRequired();
        builder.Property(q => q.Kind).HasConversion<int>().IsRequired();
        builder.Property(q => q.Section).HasMaxLength(200).IsRequired();
        builder.Property(q => q.Prompt).HasMaxLength(500).IsRequired();
        builder.Property(q => q.Note).HasMaxLength(500);
        builder.Property(q => q.RequiredCount).HasDefaultValue(1);

        builder.HasMany(q => q.Answers)
            .WithOne(a => a.Question!)
            .HasForeignKey(a => a.QuestionId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}

public class QuestionAnswerConfiguration : IEntityTypeConfiguration<QuestionAnswer>
{
    public void Configure(EntityTypeBuilder<QuestionAnswer> builder)
    {
        builder.ToTable("QuestionAnswers");
        builder.HasKey(a => a.Id);
        builder.Property(a => a.Text).HasMaxLength(500).IsRequired();
        builder.HasIndex(a => new { a.QuestionId, a.Ordinal });
    }
}

public class UsStateConfiguration : IEntityTypeConfiguration<UsState>
{
    public void Configure(EntityTypeBuilder<UsState> builder)
    {
        builder.ToTable("States");
        builder.HasKey(s => s.Id);
        builder.HasIndex(s => s.Code).IsUnique();
        builder.Property(s => s.Code).HasMaxLength(2).IsRequired();
        builder.Property(s => s.Name).HasMaxLength(80).IsRequired();
        builder.Property(s => s.Capital).HasMaxLength(80).IsRequired();
        builder.Ignore(s => s.IsDistrictOfColumbia);
    }
}
