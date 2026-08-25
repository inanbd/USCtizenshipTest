using CivicsPrep.Contracts.Auth;

namespace CivicsPrep.Application.Common.Interfaces;

/// <summary>
/// Registration and sign-in. Infrastructure implements this over ASP.NET Identity and JWT, so
/// the application layer stays free of both.
/// </summary>
public interface IIdentityService
{
    Task<AuthResponse> RegisterAsync(
        string email, string password, string? displayName, CancellationToken ct = default);

    Task<AuthResponse> LoginAsync(string email, string password, CancellationToken ct = default);

    Task<AuthResponse> RefreshAsync(string refreshToken, CancellationToken ct = default);

    Task LogoutAsync(string refreshToken, CancellationToken ct = default);

    Task<UserDto> GetCurrentUserAsync(string userId, CancellationToken ct = default);
}
