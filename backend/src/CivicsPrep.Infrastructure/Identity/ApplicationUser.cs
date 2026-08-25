using Microsoft.AspNetCore.Identity;

namespace CivicsPrep.Infrastructure.Identity;

/// <summary>The application's user, extending ASP.NET Identity with a display name.</summary>
public class ApplicationUser : IdentityUser
{
    public string? DisplayName { get; set; }

    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
}
