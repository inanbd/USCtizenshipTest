using System.Net;
using System.Net.Http.Json;
using CivicsPrep.Contracts.Auth;

namespace CivicsPrep.Api.Tests;

public class AuthEndpointTests(CivicsPrepApiFactory factory) : IClassFixture<CivicsPrepApiFactory>
{
    private ApiClient NewClient() => new(factory.CreateClient());

    [Fact]
    public async Task Register_CreatesAnAccountAndReturnsTokens()
    {
        var client = NewClient();
        var auth = await client.RegisterAndSignInAsync();

        Assert.False(string.IsNullOrWhiteSpace(auth.AccessToken));
        Assert.False(string.IsNullOrWhiteSpace(auth.RefreshToken));
        Assert.True(auth.ExpiresAt > DateTimeOffset.UtcNow);
        Assert.Equal("Test User", auth.User.DisplayName);
    }

    [Fact]
    public async Task Register_RejectsADuplicateEmail()
    {
        var email = $"dupe-{Guid.NewGuid():N}@example.com";
        var client = NewClient();
        await client.RegisterAndSignInAsync(email);

        var second = await NewClient().PostAsync(
            "/api/auth/register", new RegisterRequest(email, "Password123", null));

        Assert.Equal(HttpStatusCode.Conflict, second.StatusCode);
    }

    [Theory]
    [InlineData("not-an-email", "Password123")]
    [InlineData("valid@example.com", "short")]
    [InlineData("valid@example.com", "nodigitshere")]
    public async Task Register_RejectsInvalidInput(string email, string password)
    {
        var response = await NewClient().PostAsync(
            "/api/auth/register", new RegisterRequest(email, password, null));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Login_SucceedsWithCorrectCredentials()
    {
        var email = $"login-{Guid.NewGuid():N}@example.com";
        await NewClient().RegisterAndSignInAsync(email);

        var client = NewClient();
        var response = await client.PostAsync(
            "/api/auth/login", new LoginRequest(email, "Password123"));

        response.EnsureSuccessStatusCode();
        var auth = await response.Content.ReadFromJsonAsync<AuthResponse>(ApiClient.Json);
        Assert.Equal(email, auth!.User.Email);
    }

    [Fact]
    public async Task Login_RejectsAWrongPassword()
    {
        var email = $"wrongpw-{Guid.NewGuid():N}@example.com";
        await NewClient().RegisterAndSignInAsync(email);

        var response = await NewClient().PostAsync(
            "/api/auth/login", new LoginRequest(email, "WrongPassword1"));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Login_RejectsAnUnknownEmail()
    {
        var response = await NewClient().PostAsync(
            "/api/auth/login", new LoginRequest("nobody@example.com", "Password123"));

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Me_ReturnsTheSignedInUser()
    {
        var client = NewClient();
        var auth = await client.RegisterAndSignInAsync();

        var me = await client.GetAsync<UserDto>("/api/auth/me");
        Assert.Equal(auth.User.Id, me.Id);
    }

    [Fact]
    public async Task Me_RequiresAuthentication()
    {
        var response = await NewClient().Http.GetAsync("/api/auth/me");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Refresh_IssuesNewTokensAndRetiresTheOldOne()
    {
        var client = NewClient();
        var auth = await client.RegisterAndSignInAsync();

        var refreshed = await client.PostForAsync<AuthResponse, RefreshRequest>(
            "/api/auth/refresh", new RefreshRequest(auth.RefreshToken));

        Assert.NotEqual(auth.RefreshToken, refreshed.RefreshToken);

        // The used token must not work a second time.
        var replay = await client.PostAsync(
            "/api/auth/refresh", new RefreshRequest(auth.RefreshToken));
        Assert.Equal(HttpStatusCode.Unauthorized, replay.StatusCode);
    }

    [Fact]
    public async Task Logout_RevokesTheRefreshToken()
    {
        var client = NewClient();
        var auth = await client.RegisterAndSignInAsync();

        var logout = await client.PostAsync(
            "/api/auth/logout", new RefreshRequest(auth.RefreshToken));
        Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);

        var afterLogout = await client.PostAsync(
            "/api/auth/refresh", new RefreshRequest(auth.RefreshToken));
        Assert.Equal(HttpStatusCode.Unauthorized, afterLogout.StatusCode);
    }
}
