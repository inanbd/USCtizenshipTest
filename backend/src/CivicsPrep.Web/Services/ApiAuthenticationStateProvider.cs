using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using CivicsPrep.Contracts.Auth;
using Microsoft.AspNetCore.Components.Authorization;

namespace CivicsPrep.Web.Services;

/// <summary>
/// Holds the signed-in user for the whole app. Tokens live in local storage so a refresh keeps
/// the session, and the access token is attached to every API call by <see cref="AuthorizedHandler"/>.
/// </summary>
public class ApiAuthenticationStateProvider(IBrowserStorage storage)
    : AuthenticationStateProvider
{
    public const string AccessTokenKey = "civicsprep.accessToken";
    public const string RefreshTokenKey = "civicsprep.refreshToken";

    private static readonly AuthenticationState Anonymous =
        new(new ClaimsPrincipal(new ClaimsIdentity()));

    public override async Task<AuthenticationState> GetAuthenticationStateAsync()
    {
        var token = await storage.GetAsync(AccessTokenKey);
        if (string.IsNullOrWhiteSpace(token) || IsExpired(token)) return Anonymous;

        var identity = new ClaimsIdentity(ParseClaims(token), "jwt");
        return new AuthenticationState(new ClaimsPrincipal(identity));
    }

    public async Task SignInAsync(AuthResponse auth)
    {
        await storage.SetAsync(AccessTokenKey, auth.AccessToken);
        await storage.SetAsync(RefreshTokenKey, auth.RefreshToken);
        NotifyAuthenticationStateChanged(GetAuthenticationStateAsync());
    }

    public async Task SignOutAsync()
    {
        await storage.RemoveAsync(AccessTokenKey);
        await storage.RemoveAsync(RefreshTokenKey);
        NotifyAuthenticationStateChanged(Task.FromResult(Anonymous));
    }

    private static bool IsExpired(string token)
    {
        try
        {
            var jwt = new JwtSecurityTokenHandler().ReadJwtToken(token);
            return jwt.ValidTo < DateTime.UtcNow.AddSeconds(30);
        }
        catch
        {
            return true;
        }
    }

    private static IEnumerable<Claim> ParseClaims(string token)
    {
        try
        {
            return new JwtSecurityTokenHandler().ReadJwtToken(token).Claims;
        }
        catch
        {
            return [];
        }
    }
}
