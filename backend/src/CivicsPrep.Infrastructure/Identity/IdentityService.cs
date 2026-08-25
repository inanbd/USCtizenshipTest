using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.Auth;
using CivicsPrep.Domain.Entities;
using CivicsPrep.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace CivicsPrep.Infrastructure.Identity;

/// <summary>
/// Registration and sign-in over ASP.NET Identity, issuing a short-lived JWT plus a rotating
/// refresh token. Only the hash of a refresh token is stored, so a database leak cannot be
/// replayed against the API.
/// </summary>
public class IdentityService(
    UserManager<ApplicationUser> userManager,
    ApplicationDbContext db,
    IOptions<JwtOptions> jwtOptions,
    IClock clock) : IIdentityService
{
    private readonly JwtOptions _jwt = jwtOptions.Value;

    public async Task<AuthResponse> RegisterAsync(
        string email, string password, string? displayName, CancellationToken ct = default)
    {
        var existing = await userManager.FindByEmailAsync(email);
        if (existing is not null)
        {
            throw new ConflictException("An account with that email already exists.");
        }

        var user = new ApplicationUser
        {
            UserName = email,
            Email = email,
            DisplayName = displayName,
            CreatedAt = clock.UtcNow,
        };

        var result = await userManager.CreateAsync(user, password);
        if (!result.Succeeded)
        {
            throw new Application.Common.Exceptions.ValidationException(
                new Dictionary<string, string[]>
                {
                    ["password"] = [.. result.Errors.Select(e => e.Description)],
                });
        }

        // Every user gets a profile so their settings have somewhere to live.
        db.UserProfiles.Add(new UserProfile { UserId = user.Id, UpdatedAt = clock.UtcNow });
        await db.SaveChangesAsync(ct);

        return await IssueAsync(user, ct);
    }

    public async Task<AuthResponse> LoginAsync(
        string email, string password, CancellationToken ct = default)
    {
        var user = await userManager.FindByEmailAsync(email);
        if (user is null || !await userManager.CheckPasswordAsync(user, password))
        {
            // Deliberately identical for unknown email and wrong password.
            throw new UnauthorizedException("Email or password is incorrect.");
        }

        return await IssueAsync(user, ct);
    }

    public async Task<AuthResponse> RefreshAsync(string refreshToken, CancellationToken ct = default)
    {
        var hash = Hash(refreshToken);
        var stored = await db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == hash, ct)
            ?? throw new UnauthorizedException("That refresh token is not valid.");

        if (!stored.IsActive)
        {
            throw new UnauthorizedException("That refresh token has expired or been revoked.");
        }

        var user = await userManager.FindByIdAsync(stored.UserId)
            ?? throw new UnauthorizedException("That refresh token is not valid.");

        // Rotate: the old token dies with this use.
        stored.RevokedAt = clock.UtcNow;
        await db.SaveChangesAsync(ct);

        return await IssueAsync(user, ct);
    }

    public async Task LogoutAsync(string refreshToken, CancellationToken ct = default)
    {
        var hash = Hash(refreshToken);
        var stored = await db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == hash, ct);
        if (stored is null || !stored.IsActive) return;

        stored.RevokedAt = clock.UtcNow;
        await db.SaveChangesAsync(ct);
    }

    public async Task<UserDto> GetCurrentUserAsync(string userId, CancellationToken ct = default)
    {
        var user = await userManager.FindByIdAsync(userId)
            ?? throw new NotFoundException("User was not found.");

        return new UserDto(user.Id, user.Email ?? string.Empty, user.DisplayName);
    }

    private async Task<AuthResponse> IssueAsync(ApplicationUser user, CancellationToken ct)
    {
        var expiresAt = clock.UtcNow.AddMinutes(_jwt.AccessTokenMinutes);
        var accessToken = CreateAccessToken(user, expiresAt);

        var refreshToken = CreateRefreshToken();
        db.RefreshTokens.Add(new RefreshToken
        {
            UserId = user.Id,
            TokenHash = Hash(refreshToken),
            CreatedAt = clock.UtcNow,
            ExpiresAt = clock.UtcNow.AddDays(_jwt.RefreshTokenDays),
        });
        await db.SaveChangesAsync(ct);

        return new AuthResponse(
            accessToken,
            refreshToken,
            expiresAt,
            new UserDto(user.Id, user.Email ?? string.Empty, user.DisplayName));
    }

    private string CreateAccessToken(ApplicationUser user, DateTimeOffset expiresAt)
    {
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty),
            new(ClaimTypes.NameIdentifier, user.Id),
        };

        if (!string.IsNullOrWhiteSpace(user.DisplayName))
        {
            claims.Add(new Claim("display_name", user.DisplayName));
        }

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwt.SigningKey));
        var token = new JwtSecurityToken(
            issuer: _jwt.Issuer,
            audience: _jwt.Audience,
            claims: claims,
            notBefore: clock.UtcNow.UtcDateTime,
            expires: expiresAt.UtcDateTime,
            signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private static string CreateRefreshToken() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));

    private static string Hash(string value) =>
        Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
}
