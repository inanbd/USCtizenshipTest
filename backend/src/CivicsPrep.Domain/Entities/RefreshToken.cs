namespace CivicsPrep.Domain.Entities;

/// <summary>A refresh token issued to one device, so the app can stay signed in.</summary>
public class RefreshToken
{
    public int Id { get; set; }

    public string UserId { get; set; } = string.Empty;

    /// <summary>Hash of the token; the raw value is only ever given to the client.</summary>
    public string TokenHash { get; set; } = string.Empty;

    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? RevokedAt { get; set; }

    public bool IsActive => RevokedAt is null && DateTimeOffset.UtcNow < ExpiresAt;
}
