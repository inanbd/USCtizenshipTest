using CivicsPrep.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CivicsPrep.Infrastructure.Persistence.Configurations;

public class UserProfileConfiguration : IEntityTypeConfiguration<UserProfile>
{
    public void Configure(EntityTypeBuilder<UserProfile> builder)
    {
        builder.ToTable("UserProfiles");
        builder.HasKey(p => p.Id);
        builder.HasIndex(p => p.UserId).IsUnique();

        builder.Property(p => p.UserId).HasMaxLength(450).IsRequired();
        builder.Property(p => p.TestVersion).HasConversion<int>().IsRequired();
        builder.Property(p => p.StateCode).HasMaxLength(2);
        builder.Property(p => p.Governor).HasMaxLength(120);
        builder.Property(p => p.SenatorOne).HasMaxLength(120);
        builder.Property(p => p.SenatorTwo).HasMaxLength(120);
        builder.Property(p => p.Representative).HasMaxLength(120);
        builder.Property(p => p.President).HasMaxLength(120);
        builder.Property(p => p.VicePresident).HasMaxLength(120);
        builder.Property(p => p.Speaker).HasMaxLength(120);
        builder.Property(p => p.ChiefJustice).HasMaxLength(120);
        builder.Property(p => p.PresidentParty).HasMaxLength(120);

        builder.Ignore(p => p.Senators);
    }
}

public class UserQuestionProgressConfiguration : IEntityTypeConfiguration<UserQuestionProgress>
{
    public void Configure(EntityTypeBuilder<UserQuestionProgress> builder)
    {
        builder.ToTable("UserQuestionProgress");
        builder.HasKey(p => p.Id);

        // One row per user, version and question.
        builder.HasIndex(p => new { p.UserId, p.Version, p.QuestionNumber }).IsUnique();

        builder.Property(p => p.UserId).HasMaxLength(450).IsRequired();
        builder.Property(p => p.Version).HasConversion<int>().IsRequired();
    }
}

public class RefreshTokenConfiguration : IEntityTypeConfiguration<RefreshToken>
{
    public void Configure(EntityTypeBuilder<RefreshToken> builder)
    {
        builder.ToTable("RefreshTokens");
        builder.HasKey(t => t.Id);
        builder.HasIndex(t => t.TokenHash).IsUnique();
        builder.HasIndex(t => t.UserId);

        builder.Property(t => t.UserId).HasMaxLength(450).IsRequired();
        builder.Property(t => t.TokenHash).HasMaxLength(200).IsRequired();
        builder.Ignore(t => t.IsActive);
    }
}
