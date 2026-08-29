using CivicsPrep.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CivicsPrep.Infrastructure.Persistence.Configurations;

public class GovernorConfiguration : IEntityTypeConfiguration<Governor>
{
    public void Configure(EntityTypeBuilder<Governor> builder)
    {
        builder.ToTable("Governors");
        builder.HasKey(g => g.Id);
        builder.HasIndex(g => g.StateCode).IsUnique();

        builder.Property(g => g.StateCode).HasMaxLength(2).IsRequired();
        builder.Property(g => g.Name).HasMaxLength(120).IsRequired();
        builder.Property(g => g.Source).HasMaxLength(200);
    }
}
