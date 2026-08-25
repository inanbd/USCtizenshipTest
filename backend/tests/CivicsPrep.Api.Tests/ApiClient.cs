using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using CivicsPrep.Contracts.Auth;

namespace CivicsPrep.Api.Tests;

/// <summary>Small helper that keeps the tests readable: sign up, then call the API as that user.</summary>
public class ApiClient(HttpClient http)
{
    public static readonly JsonSerializerOptions Json = CreateOptions();

    private static JsonSerializerOptions CreateOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        options.Converters.Add(new JsonStringEnumConverter());
        return options;
    }

    public HttpClient Http { get; } = http;

    /// <summary>Registers a fresh user and authenticates this client as them.</summary>
    public async Task<AuthResponse> RegisterAndSignInAsync(string? email = null)
    {
        email ??= $"user-{Guid.NewGuid():N}@example.com";
        var response = await Http.PostAsJsonAsync(
            "/api/auth/register", new RegisterRequest(email, "Password123", "Test User"), Json);

        response.EnsureSuccessStatusCode();
        var auth = (await response.Content.ReadFromJsonAsync<AuthResponse>(Json))!;
        SignIn(auth.AccessToken);
        return auth;
    }

    public void SignIn(string accessToken) =>
        Http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

    public void SignOut() => Http.DefaultRequestHeaders.Authorization = null;

    public async Task<T> GetAsync<T>(string url)
    {
        var response = await Http.GetAsync(url);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<T>(Json))!;
    }

    public Task<HttpResponseMessage> PostAsync<TBody>(string url, TBody body) =>
        Http.PostAsJsonAsync(url, body, Json);

    public Task<HttpResponseMessage> PutAsync<TBody>(string url, TBody body) =>
        Http.PutAsJsonAsync(url, body, Json);

    public async Task<T> PostForAsync<T, TBody>(string url, TBody body)
    {
        var response = await PostAsync(url, body);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<T>(Json))!;
    }

    public async Task<T> PutForAsync<T, TBody>(string url, TBody body)
    {
        var response = await PutAsync(url, body);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<T>(Json))!;
    }
}
