namespace CivicsPrep.Contracts.Auth;

public sealed record RegisterRequest(string Email, string Password, string? DisplayName);

public sealed record LoginRequest(string Email, string Password);

public sealed record RefreshRequest(string RefreshToken);

public sealed record AuthResponse(
    string AccessToken,
    string RefreshToken,
    DateTimeOffset ExpiresAt,
    UserDto User);

public sealed record UserDto(string Id, string Email, string? DisplayName);
