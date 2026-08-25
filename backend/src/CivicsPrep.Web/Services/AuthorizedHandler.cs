using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using CivicsPrep.Contracts.Auth;
using Microsoft.Extensions.DependencyInjection;

namespace CivicsPrep.Web.Services;

/// <summary>
/// Attaches the access token to every API call and, when the API says the token has expired,
/// silently refreshes it once and retries - so a long study session never drops the user out.
/// </summary>
public class AuthorizedHandler(IBrowserStorage storage, IServiceProvider services)
    : DelegatingHandler
{
    private static readonly SemaphoreSlim RefreshLock = new(1, 1);

    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        await AttachTokenAsync(request);
        var response = await base.SendAsync(request, cancellationToken);

        if (response.StatusCode != HttpStatusCode.Unauthorized) return response;

        if (!await TryRefreshAsync(cancellationToken)) return response;

        // Retry once with the new token.
        response.Dispose();
        var retry = await CloneAsync(request);
        await AttachTokenAsync(retry);
        return await base.SendAsync(retry, cancellationToken);
    }

    private async Task AttachTokenAsync(HttpRequestMessage request)
    {
        var token = await storage.GetAsync(ApiAuthenticationStateProvider.AccessTokenKey);

        request.Headers.Authorization = string.IsNullOrWhiteSpace(token)
            ? null
            : new AuthenticationHeaderValue("Bearer", token);
    }

    private async Task<bool> TryRefreshAsync(CancellationToken ct)
    {
        await RefreshLock.WaitAsync(ct);
        try
        {
            var refreshToken = await storage.GetAsync(
                ApiAuthenticationStateProvider.RefreshTokenKey, ct);
            if (string.IsNullOrWhiteSpace(refreshToken)) return false;

            // A bare client, so this request does not recurse through this handler.
            var factory = (IHttpClientFactory)services.GetService(typeof(IHttpClientFactory))!;
            using var bare = factory.CreateClient("CivicsPrepApi.Bare");

            var response = await bare.PostAsJsonAsync(
                "api/auth/refresh", new RefreshRequest(refreshToken), ct);
            if (!response.IsSuccessStatusCode) return false;

            var auth = await response.Content.ReadFromJsonAsync<AuthResponse>(ct);
            if (auth is null) return false;

            await storage.SetAsync(
                ApiAuthenticationStateProvider.AccessTokenKey, auth.AccessToken, ct);
            await storage.SetAsync(
                ApiAuthenticationStateProvider.RefreshTokenKey, auth.RefreshToken, ct);
            return true;
        }
        catch
        {
            return false;
        }
        finally
        {
            RefreshLock.Release();
        }
    }

    private static async Task<HttpRequestMessage> CloneAsync(HttpRequestMessage request)
    {
        var clone = new HttpRequestMessage(request.Method, request.RequestUri);

        if (request.Content is not null)
        {
            var bytes = await request.Content.ReadAsByteArrayAsync();
            clone.Content = new ByteArrayContent(bytes);
            foreach (var header in request.Content.Headers)
            {
                clone.Content.Headers.TryAddWithoutValidation(header.Key, header.Value);
            }
        }

        foreach (var header in request.Headers)
        {
            clone.Headers.TryAddWithoutValidation(header.Key, header.Value);
        }

        return clone;
    }
}
