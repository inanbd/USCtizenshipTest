namespace CivicsPrep.Infrastructure.Identity;

/// <summary>Token settings, bound from the "Jwt" configuration section.</summary>
public class JwtOptions
{
    public const string SectionName = "Jwt";

    public string Issuer { get; set; } = "CivicsPrep";
    public string Audience { get; set; } = "CivicsPrep";

    /// <summary>Signing key. Must be supplied via configuration or a secret store in production.</summary>
    public string SigningKey { get; set; } = string.Empty;

    public int AccessTokenMinutes { get; set; } = 60;
    public int RefreshTokenDays { get; set; } = 30;
}
